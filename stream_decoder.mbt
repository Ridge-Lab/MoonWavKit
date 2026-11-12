///|
pub(all) suberror WavStreamError {
  InvalidStream(WavErrorKind, Int64, String)
}

///|
priv enum WavStreamPhase {
  Riff
  Chunk
  Format
  Skip
  Audio
  Pad
  End
  Finished
  Failed(WavStreamError)
}

///|
/// Forward-only RIFF/WAVE audio decoder. Chunk metadata is skipped. Feed
/// arbitrary byte fragments, then call finish to validate the full container.
/// Each owned output block contains at most 2,048 frames and 64 KiB of source PCM.
pub struct WavStreamDecoder {
  priv mut phase : WavStreamPhase
  priv mut position : Int64
  priv mut stop : Int64
  priv mut riff_end : Int64
  priv mut chunk_end : Int64
  priv mut pad : Bool
  priv mut format : WaveFormat?
  priv mut saw_data : Bool
  priv mut busy : Bool
  priv clamp : Bool
  priv buffer : Array[Int32]
  priv mut block_bytes : Int32
}

///|
pub fn WavStreamDecoder::new(clamp~ : Bool = true) -> WavStreamDecoder {
  {
    phase: Riff,
    position: 0L,
    stop: 12L,
    riff_end: 0L,
    chunk_end: 0L,
    pad: false,
    format: None,
    saw_data: false,
    busy: false,
    clamp,
    buffer: [],
    block_bytes: 0,
  }
}

///|
fn WavStreamDecoder::next_chunk(
  self : WavStreamDecoder,
) -> Unit raise WavStreamError {
  let remaining = self.riff_end - self.position
  if remaining == 0L {
    self.phase = End
  } else if remaining < 8L {
    raise InvalidStream(
      ErrorChunkOutOfBounds,
      self.position,
      "truncated chunk header inside RIFF",
    )
  } else {
    self.phase = Chunk
    self.stop = self.position + 8L
  }
}

///|
fn WavStreamDecoder::end_chunk(
  self : WavStreamDecoder,
) -> Unit raise WavStreamError {
  if self.pad {
    self.phase = Pad
    self.stop = self.position + 1L
  } else {
    self.next_chunk()
  }
}

///|
fn WavStreamDecoder::begin_chunk(
  self : WavStreamDecoder,
  header : ByteReader,
) -> Unit raise WavStreamError {
  let id = header.fourcc_at(0)
  let size = header.u32_le_at(4).reinterpret_as_uint().to_int64()
  let start = self.position - 8L
  self.chunk_end = self.position + size
  if self.chunk_end > self.riff_end {
    raise InvalidStream(
      ErrorChunkOutOfBounds,
      start,
      "chunk extends beyond RIFF",
    )
  }
  self.pad = size % 2L == 1L
  if self.pad && self.chunk_end == self.riff_end {
    if id != "data" {
      raise InvalidStream(ErrorChunkOutOfBounds, start, "missing RIFF pad")
    }
    // Python wave omits padding on an odd-length final data chunk.
    self.pad = false
  }
  self.stop = self.chunk_end
  match id {
    "fmt " => {
      guard self.format is None && size >= 16L else {
        raise InvalidStream(
          ErrorInvalidFormat,
          start,
          "short or repeated fmt chunk",
        )
      }
      self.phase = Format
      self.stop = self.position + (if size >= 18L { 18L } else { 16L })
    }
    "data" => {
      guard self.format is Some(format) else {
        raise InvalidStream(ErrorMissingFormat, start, "fmt must precede data")
      }
      guard !self.saw_data else {
        raise InvalidStream(ErrorInvalidFormat, start, "repeated data chunk")
      }
      guard size % format.block_align.to_int64() == 0L else {
        raise InvalidStream(ErrorTruncatedData, start, "partial PCM frame")
      }
      self.saw_data = true
      self.phase = Audio
      self.block_bytes = (65536 / format.block_align).min(2048) *
        format.block_align
    }
    _ => self.phase = Skip
  }
  if size == 0L {
    self.end_chunk()
  }
}

///|
fn WavStreamDecoder::emit_audio(
  self : WavStreamDecoder,
  on_block : (FloatBuffer) -> Unit,
) -> Unit {
  let format = self.format.unwrap()
  let reader = ByteReader::new(self.buffer)
  let width = format.bytes_per_sample()
  let samples = Array::makei(self.buffer.length() / width, i => {
    let offset = i * width
    if format.is_float() {
      let value = decode_ieee_float32_bits(reader.u32_le_at(offset))
      if self.clamp {
        clamp_unit(value)
      } else {
        value
      }
    } else {
      normalize_pcm_sample(
        read_pcm_sample(reader, offset, format.bits_per_sample),
        format.bits_per_sample,
      )
    }
  })
  self.buffer.clear()
  on_block(FloatBuffer::new(format.channels, format.sample_rate, samples))
}

///|
fn WavStreamDecoder::consume(
  self : WavStreamDecoder,
  input : Bytes,
  on_block : (FloatBuffer) -> Unit,
) -> Unit raise WavStreamError {
  let mut i = 0
  while i < input.length() {
    match self.phase {
      End => return
      Finished | Failed(_) => panic()
      _ => ()
    }
    let mut take = (self.stop - self.position)
      .min((input.length() - i).to_int64())
      .to_int()
    match self.phase {
      Audio => take = take.min(self.block_bytes - self.buffer.length())
      _ => ()
    }
    match self.phase {
      Riff | Chunk | Format | Audio =>
        for k in i..<(i + take) {
          self.buffer.push(input[k].to_int())
        }
      _ => ()
    }
    self.position += take.to_int64()
    i += take
    if self.phase is Audio &&
      (self.buffer.length() == self.block_bytes || self.position == self.stop) {
      self.emit_audio(on_block)
    }
    if self.position != self.stop {
      continue
    }
    let reader = ByteReader::new(self.buffer)
    match self.phase {
      Riff => {
        guard reader.fourcc_at(0) == "RIFF" else {
          raise InvalidStream(ErrorNotRiff, 0L, "expected RIFF signature")
        }
        guard reader.fourcc_at(8) == "WAVE" else {
          raise InvalidStream(ErrorNotWave, 8L, "expected WAVE signature")
        }
        self.riff_end = reader.u32_le_at(4).reinterpret_as_uint().to_int64() +
          8L
        guard self.riff_end >= 12L else {
          raise InvalidStream(ErrorInvalidFormat, 4L, "invalid RIFF extent")
        }
        self.next_chunk()
      }
      Chunk => self.begin_chunk(reader)
      Format => {
        let format = parse_format(
          reader,
          WaveChunk::new("fmt ", 0, 0, self.buffer.length()),
        )
        guard format.is_valid() else {
          raise InvalidStream(
            ErrorInvalidFormat,
            self.position,
            "invalid format or byte rate",
          )
        }
        guard format.is_supported() else {
          raise InvalidStream(
            ErrorUnsupportedFormat,
            self.position,
            "unsupported WAV sample format",
          )
        }
        self.format = Some(format)
        if self.position < self.chunk_end {
          self.phase = Skip
          self.stop = self.chunk_end
        } else {
          self.end_chunk()
        }
      }
      Skip | Audio => self.end_chunk()
      Pad => self.next_chunk()
      _ => panic()
    }
    self.buffer.clear()
  }
}

///|
/// Deliver complete interleaved sample frames. The callback can retain a block.
/// After a stream error discard earlier output if atomic file processing is needed.
pub fn WavStreamDecoder::feed(
  self : WavStreamDecoder,
  input : Bytes,
  on_block : (FloatBuffer) -> Unit,
) -> Unit raise WavStreamError {
  guard !self.busy else {
    raise InvalidStream(
      ErrorInvalidArgument,
      self.position,
      "callback cannot re-enter the decoder",
    )
  }
  match self.phase {
    Failed(e) => raise e
    Finished =>
      raise InvalidStream(
        ErrorInvalidArgument,
        self.position,
        "decoder has finished",
      )
    _ => ()
  }
  self.busy = true
  defer {
    self.busy = false
  }
  self.consume(input, on_block) catch {
    InvalidStream(_, _, _) as e => {
      self.phase = Failed(e)
      raise e
    }
  }
}

///|
/// Validate EOF and return the audio format, including for an empty data chunk.
/// Repeated successful calls return the same format.
pub fn WavStreamDecoder::finish(
  self : WavStreamDecoder,
) -> WaveFormat raise WavStreamError {
  guard !self.busy else {
    raise InvalidStream(
      ErrorInvalidArgument,
      self.position,
      "callback cannot finish the decoder",
    )
  }
  let kind = match self.phase {
    Failed(e) => raise e
    End | Finished =>
      if self.format is Some(format) {
        if self.saw_data {
          self.phase = Finished
          return format
        }
        ErrorMissingData
      } else {
        ErrorMissingFormat
      }
    Riff => ErrorTooShort
    _ => ErrorTruncatedData
  }
  let e = InvalidStream(kind, self.position, "unexpected end of WAV input")
  self.phase = Failed(e)
  raise e
}
