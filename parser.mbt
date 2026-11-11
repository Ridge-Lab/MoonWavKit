///|
fn parse_header(reader : ByteReader) -> WavParseResult {
  if !reader.slice_can_read(0, 12) {
    WavParseResult::failure(
      WavError::new(ErrorTooShort, "WAV data is shorter than RIFF header"),
    )
  } else if !reader.matches_ascii(0, 82, 73, 70, 70) {
    WavParseResult::failure(
      WavError::new(ErrorNotRiff, "expected RIFF signature"),
    )
  } else if !reader.matches_ascii(8, 87, 65, 86, 69) {
    WavParseResult::failure(
      WavError::new(ErrorNotWave, "expected WAVE signature", offset=8),
    )
  } else {
    let header = {
      riff_id: "RIFF",
      file_size_minus_8: reader.u32_le_at(4),
      wave_id: "WAVE",
    }
    WavParseResult::success({
      header,
      format: WaveFormat::empty(),
      chunks: [],
      info_tags: [],
      cue_points: [],
      fact_sample_count: 0,
      data_offset: 0,
      data_size: 0,
      source_length: reader.length(),
    })
  }
}

///|
fn parse_format(reader : ByteReader, chunk : WaveChunk) -> WaveFormat {
  if chunk.size < 16 || !reader.slice_can_read(chunk.data_offset, 16) {
    WaveFormat::empty()
  } else {
    let extra_size = if chunk.size >= 18 &&
      reader.slice_can_read(chunk.data_offset + 16, 2) {
      reader.u16_le_at(chunk.data_offset + 16)
    } else {
      0
    }
    WaveFormat::new(
      reader.u16_le_at(chunk.data_offset),
      reader.u16_le_at(chunk.data_offset + 2),
      reader.u32_le_at(chunk.data_offset + 4),
      reader.u32_le_at(chunk.data_offset + 8),
      reader.u16_le_at(chunk.data_offset + 12),
      reader.u16_le_at(chunk.data_offset + 14),
      extra_size~,
    )
  }
}

///|
fn ascii_value_at(reader : ByteReader, offset : Int32, size : Int32) -> String {
  if size <= 0 || !reader.slice_can_read(offset, size) {
    ""
  } else {
    let text = StringBuilder()
    for i in 0..<size {
      let byte = reader.byte_at(offset + i)
      if byte >= 32 && byte <= 126 {
        text.write_char(byte.to_uint16().unsafe_to_char())
      }
    }
    text.to_string()
  }
}

///|
fn parse_info_tags(
  reader : ByteReader,
  chunk : WaveChunk,
) -> Result[Array[InfoTag], WavError] {
  let tags = []
  if chunk.size < 4 || reader.fourcc_at(chunk.data_offset) != "INFO" {
    return Ok(tags)
  }
  let end = chunk.data_offset + chunk.size
  for offset = chunk.data_offset + 4; offset < end; {
    if end - offset < 8 {
      return Err(
        WavError::new(
          ErrorChunkOutOfBounds,
          "truncated INFO tag header",
          offset~,
        ),
      )
    }
    let size = reader.u32_le_at(offset + 4)
    let start = offset + 8
    let room = end - start
    if size < 0 || size > room || (size % 2 == 1 && size == room) {
      return Err(
        WavError::new(
          ErrorChunkOutOfBounds,
          "INFO tag exceeds LIST chunk",
          offset~,
        ),
      )
    }
    tags.push(
      InfoTag::new(
        reader.fourcc_at(offset),
        ascii_value_at(reader, start, size),
      ),
    )
    continue start + size + size % 2
  }
  Ok(tags)
}

///|
fn parse_cue_points(reader : ByteReader, chunk : WaveChunk) -> Array[CuePoint] {
  let points : Array[CuePoint] = []
  if chunk.size < 4 || !reader.slice_can_read(chunk.data_offset, chunk.size) {
    points
  } else {
    let count = reader.u32_le_at(chunk.data_offset)
    let max_count = (chunk.size - 4) / 24
    let safe_count = if count < max_count { count } else { max_count }
    for i in 0..<safe_count {
      let base = chunk.data_offset + 4 + i * 24
      points.push(
        CuePoint::new(
          reader.u32_le_at(base),
          reader.u32_le_at(base + 4),
          reader.u32_le_at(base + 20),
        ),
      )
    }
    points
  }
}

///|
fn parse_fact_sample_count(reader : ByteReader, chunk : WaveChunk) -> Int32 {
  if chunk.size >= 4 && reader.slice_can_read(chunk.data_offset, 4) {
    reader.u32_le_at(chunk.data_offset)
  } else {
    0
  }
}

///|
/// Parse a RIFF/WAVE byte array into structural metadata. The parser skips
/// unknown chunks while preserving their id and bounds.
pub fn parse_wav(bytes : Array[Int32]) -> WavParseResult {
  let reader = ByteReader::new(bytes)
  let header_result = parse_header(reader)
  if !header_result.ok {
    header_result
  } else {
    let chunks : Array[WaveChunk] = []
    let info_tags : Array[InfoTag] = []
    let cue_points : Array[CuePoint] = []
    let mut format = WaveFormat::empty()
    let mut data_offset = 0
    let mut data_size = 0
    let mut fact_sample_count = 0
    let declared = header_result.wav.header.file_size_minus_8
    if declared < 4 {
      return WavParseResult::failure(
        WavError::new(ErrorInvalidFormat, "unsupported RIFF extent", offset=4),
      )
    }
    // Tolerate an overstated RIFF size for diagnostics, but never scan a trailing container.
    let end = if declared < reader.length() - 8 {
      declared + 8
    } else {
      reader.length()
    }
    let parse_error = for offset = 12; offset < end; {
      if end - offset < 8 {
        break Some(
          WavError::new(
            ErrorChunkOutOfBounds,
            "truncated chunk header",
            offset~,
          ),
        )
      }
      let id = reader.fourcc_at(offset)
      let size = reader.u32_le_at(offset + 4)
      let start = offset + 8
      let room = end - start
      if size < 0 ||
        size > room ||
        (size % 2 == 1 && size == room && id != "data") {
        break Some(
          WavError::new(
            ErrorChunkOutOfBounds,
            "chunk extends beyond the available byte array",
            offset~,
          ),
        )
      }
      let chunk = WaveChunk::new(id, offset, start, size)
      // Python wave and common PCM encoders omit the pad after an odd final data chunk.
      let chunk = if size == room {
        { ..chunk, padded_size: size, }
      } else {
        chunk
      }
      chunks.push(chunk)
      if id == "fmt " {
        format = parse_format(reader, chunk)
      } else if id == "data" {
        data_offset = chunk.data_offset
        data_size = chunk.size
      } else if id == "fact" {
        fact_sample_count = parse_fact_sample_count(reader, chunk)
      } else if id == "LIST" {
        match parse_info_tags(reader, chunk) {
          Err(error) => break Some(error)
          Ok(tags) =>
            for tag in tags {
              info_tags.push(tag)
            }
        }
      } else if id == "cue " {
        for point in parse_cue_points(reader, chunk) {
          cue_points.push(point)
        }
      }
      continue chunk.end_offset()
    } nobreak {
      None
    }
    match parse_error {
      Some(error) => WavParseResult::failure(error)
      None =>
        if !format.is_valid() {
          WavParseResult::failure(
            WavError::new(ErrorMissingFormat, "missing or invalid fmt chunk"),
          )
        } else if data_offset == 0 {
          WavParseResult::failure(
            WavError::new(ErrorMissingData, "missing data chunk"),
          )
        } else {
          WavParseResult::success({
            header: header_result.wav.header,
            format,
            chunks,
            info_tags,
            cue_points,
            fact_sample_count,
            data_offset,
            data_size,
            source_length: bytes.length(),
          })
        }
    }
  }
}

///|
pub fn validate_wav(bytes : Array[Int32]) -> WavError {
  let parsed = parse_wav(bytes)
  if !parsed.ok {
    parsed.error
  } else if !parsed.wav.format.is_supported() {
    WavError::new(
      ErrorUnsupportedFormat,
      "format is structurally valid but unsupported by v1",
    )
  } else if parsed.wav.data_size % parsed.wav.format.block_align != 0 {
    WavError::new(
      ErrorTruncatedData,
      "data chunk is not aligned to complete sample frames",
    )
  } else {
    WavError::none()
  }
}
