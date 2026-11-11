///|
fn clamp_unit(value : Double) -> Double {
  if value > 1.0 {
    1.0
  } else if value < -1.0 {
    -1.0
  } else {
    value
  }
}

///|
fn normalize_pcm_sample(sample : Int32, bits : Int32) -> Double {
  match bits {
    8 => (sample.to_double() - 128.0) / 128.0
    16 => sample.to_double() / 32768.0
    24 => sample.to_double() / 8388608.0
    32 => sample.to_double() / 2147483648.0
    _ => 0.0
  }
}

///|
fn read_pcm_sample(reader : ByteReader, offset : Int32, bits : Int32) -> Int32 {
  match bits {
    8 => reader.byte_at(offset)
    16 => reader.i16_le_at(offset)
    24 => reader.i24_le_at(offset)
    32 => reader.i32_le_at(offset)
    _ => 0
  }
}

///|
fn decode_ieee_float32_bits(bits : Int32) -> Double {
  // Preserve the decoder's silence policy for NaN and infinity. Widening
  // the reinterpreted Float retains all finite binary32 values and signed zero.
  if (bits & 0x7f800000) == 0x7f800000 {
    0.0
  } else {
    Float::reinterpret_from_int(bits).to_double()
  }
}

///|
fn decode_samples(
  bytes : Array[Int32],
  wav : ParsedWav,
  options : DecodeOptions,
) -> DecodeResult {
  let reader = ByteReader::new(bytes)
  let width = wav.format.bytes_per_sample()
  let count = wav.data_size / width
  let pcm = Array::make(count, 0)
  let floats = Array::make(count, 0.0)
  let is_float = wav.format.is_float()
  for i in 0..<count {
    let offset = wav.data_offset + i * width
    if is_float {
      let value = decode_ieee_float32_bits(reader.u32_le_at(offset))
      pcm[i] = (value * 2147483647.0).round().to_int()
      floats[i] = if options.clamp { clamp_unit(value) } else { value }
    } else {
      let sample = read_pcm_sample(reader, offset, wav.format.bits_per_sample)
      pcm[i] = sample
      floats[i] = normalize_pcm_sample(sample, wav.format.bits_per_sample)
    }
  }
  DecodeResult::success(
    PcmBuffer::new(
      wav.format.channels,
      wav.format.sample_rate,
      wav.format.bits_per_sample,
      pcm,
    ),
    FloatBuffer::new(wav.format.channels, wav.format.sample_rate, floats),
  )
}

///|
pub fn decode_pcm(
  bytes : Array[Int32],
  wav : ParsedWav,
  options~ : DecodeOptions = DecodeOptions::new(),
) -> DecodeResult {
  if !options.is_valid() {
    DecodeResult::failure(
      WavError::new(ErrorInvalidArgument, "invalid decode options"),
    )
  } else if !wav.is_complete() {
    DecodeResult::failure(
      WavError::new(ErrorInvalidFormat, "parsed wav is incomplete"),
    )
  } else if options.target_channels != 0 &&
    options.target_channels != wav.format.channels {
    DecodeResult::failure(
      WavError::new(
        ErrorInvalidArgument,
        "decode does not perform channel conversion; use zero or source channels",
      ),
    )
  } else if wav.data_offset < 0 ||
    wav.data_size < 0 ||
    wav.data_offset > bytes.length() ||
    wav.data_size > bytes.length() - wav.data_offset {
    DecodeResult::failure(
      WavError::new(
        ErrorTruncatedData,
        "data chunk extends beyond the provided byte array",
        offset=wav.data_offset,
      ),
    )
  } else if !wav.format.is_supported() {
    DecodeResult::failure(
      WavError::new(ErrorUnsupportedFormat, "unsupported WAV sample format"),
    )
  } else if wav.data_size % wav.format.block_align != 0 {
    DecodeResult::failure(
      WavError::new(ErrorTruncatedData, "data chunk has partial frame"),
    )
  } else {
    decode_samples(bytes, wav, options)
  }
}

///|
pub fn parse_and_decode(
  bytes : Array[Int32],
  options~ : DecodeOptions = DecodeOptions::new(),
) -> DecodeResult {
  let parsed = parse_wav(bytes)
  if !parsed.ok {
    DecodeResult::failure(parsed.error)
  } else {
    decode_pcm(bytes, parsed.wav, options~)
  }
}

///|
pub fn split_channel(buffer : FloatBuffer, channel : Int32) -> Array[Double] {
  if !buffer.is_valid() || channel < 0 || channel >= buffer.channels {
    []
  } else {
    Array::makei(buffer.frame_count(), frame => {
      buffer.samples[frame * buffer.channels + channel]
    })
  }
}

///|
pub fn downmix_to_mono(buffer : FloatBuffer) -> FloatBuffer {
  if !buffer.is_valid() {
    FloatBuffer::empty()
  } else if buffer.channels == 1 {
    buffer
  } else {
    let samples = Array::makei(buffer.frame_count(), frame => {
      let sum = for channel in 0..<buffer.channels; acc = 0.0 {
        continue acc + buffer.samples[frame * buffer.channels + channel]
      } nobreak {
        acc
      }
      sum / buffer.channels.to_double()
    })
    FloatBuffer::new(1, buffer.sample_rate, samples)
  }
}
