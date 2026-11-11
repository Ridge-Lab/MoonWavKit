///|
pub fn fixture_pcm32_mono() -> Array[Int32] {
  let payload = [0, 0, 0, 0, 255, 255, 255, 127, 0, 0, 0, 128]
  let body = concat_arrays(fmt_chunk(1, 1, 44100, 32), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_with_unknown_chunk() -> Array[Int32] {
  let junk_payload = [1, 2, 3]
  let junk = [
    74,
    85,
    78,
    75,
    junk_payload.length() & 0xff,
    (junk_payload.length() >> 8) & 0xff,
    0,
    0,
  ]
  for byte in junk_payload {
    junk.push(byte)
  }
  if junk_payload.length() % 2 != 0 {
    junk.push(0)
  }
  let payload = [0, 0, 1, 0]
  let body = concat3(fmt_chunk(1, 1, 8000, 16), junk, data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_low_sample_rate() -> Array[Int32] {
  let payload = [0, 0, 1, 0]
  let body = concat_arrays(fmt_chunk(1, 1, 4000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_riff_size_mismatch() -> Array[Int32] {
  let payload = [0, 0, 1, 0]
  let body = concat_arrays(fmt_chunk(1, 1, 8000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(999), body)
}

///|
pub fn fixture_stereo_phase_test() -> Array[Int32] {
  let payload = [0, 0, 0, 0, 0, 64, 0, 192, 0, 0, 0, 0]
  let body = concat_arrays(fmt_chunk(1, 2, 8000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_tiny_silence() -> Array[Int32] {
  let payload = [0, 0, 0, 0, 0, 0, 0, 0]
  let body = concat_arrays(fmt_chunk(1, 1, 8000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_quality_clipped() -> Array[Int32] {
  let payload = [255, 127, 0, 128, 255, 127, 0, 128]
  let body = concat_arrays(fmt_chunk(1, 1, 8000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}
