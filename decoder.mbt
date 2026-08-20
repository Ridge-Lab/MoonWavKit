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
fn normalize_pcm_sample(sample : Int, bits : Int) -> Double {
  match bits {
    8 => (sample.to_double() - 128.0) / 128.0
    16 => sample.to_double() / 32768.0
    24 => sample.to_double() / 8388608.0
    32 => sample.to_double() / 2147483648.0
    _ => 0.0
  }
}

///|
fn read_pcm_sample(reader : ByteReader, offset : Int, bits : Int) -> Int {
  match bits {
    8 => reader.byte_at(offset)
    16 => reader.i16_le_at(offset)
    24 => reader.i24_le_at(offset)
    32 => reader.i32_le_at(offset)
    _ => 0
  }
}

///|
fn pow2(exp : Int) -> Double {
  if exp == 0 {
    1.0
  } else if exp > 0 {
    for _ in 0..<exp; value = 1.0 {
      continue value * 2.0
    } nobreak {
      value
    }
  } else {
    for _ in 0..<-exp; value = 1.0 {
      continue value / 2.0
    } nobreak {
      value
    }
  }
}

///|
fn decode_ieee_float32_bits(bits : Int) -> Double {
  let sign = if (bits & 0x80000000) != 0 { -1.0 } else { 1.0 }
  let exponent = (bits >> 23) & 0xff
  let fraction = bits & 0x7fffff
  if exponent == 0 && fraction == 0 {
    0.0 * sign
  } else if exponent == 255 {
    0.0
  } else if exponent == 0 {
    sign * (fraction.to_double() / 8388608.0) * pow2(-126)
  } else {
    sign * (1.0 + fraction.to_double() / 8388608.0) * pow2(exponent - 127)
  }
}

///|
fn read_float32_sample(reader : ByteReader, offset : Int) -> Double {
  decode_ieee_float32_bits(reader.u32_le_at(offset))
}

///|
fn decode_to_float_buffer(
  bytes : Array[Int],
  wav : ParsedWav,
  options : DecodeOptions,
) -> FloatBuffer {
  let reader = ByteReader::new(bytes)
  let bytes_per_sample = wav.format.bytes_per_sample()
  let sample_count = wav.data_size / bytes_per_sample
  let samples = Array::makei(sample_count, i => {
    let offset = wav.data_offset + i * bytes_per_sample
    let value = if wav.format.is_float() {
      read_float32_sample(reader, offset)
    } else {
      normalize_pcm_sample(
        read_pcm_sample(reader, offset, wav.format.bits_per_sample),
        wav.format.bits_per_sample,
      )
    }
    if options.clamp {
      clamp_unit(value)
    } else {
      value
    }
  })
  FloatBuffer::new(wav.format.channels, wav.format.sample_rate, samples)
}

///|
fn decode_to_pcm_buffer(bytes : Array[Int], wav : ParsedWav) -> PcmBuffer {
  let reader = ByteReader::new(bytes)
  let bytes_per_sample = wav.format.bytes_per_sample()
  let sample_count = wav.data_size / bytes_per_sample
  let samples = Array::makei(sample_count, i => {
    let offset = wav.data_offset + i * bytes_per_sample
    if wav.format.is_float() {
      (read_float32_sample(reader, offset) * 2147483647.0).round().to_int()
    } else {
      read_pcm_sample(reader, offset, wav.format.bits_per_sample)
    }
  })
  PcmBuffer::new(
    wav.format.channels,
    wav.format.sample_rate,
    wav.format.bits_per_sample,
    samples,
  )
}

///|
pub fn decode_pcm(
  bytes : Array[Int],
  wav : ParsedWav,
  options? : DecodeOptions = DecodeOptions::new(),
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
    DecodeResult::success(
      decode_to_pcm_buffer(bytes, wav),
      decode_to_float_buffer(bytes, wav, options),
    )
  }
}

///|
pub fn parse_and_decode(
  bytes : Array[Int],
  options? : DecodeOptions = DecodeOptions::new(),
) -> DecodeResult {
  let parsed = parse_wav(bytes)
  if !parsed.ok {
    DecodeResult::failure(parsed.error)
  } else {
    decode_pcm(bytes, parsed.wav, options~)
  }
}

///|
pub fn split_channel(buffer : FloatBuffer, channel : Int) -> Array[Double] {
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
