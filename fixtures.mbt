///|
fn riff_prefix(total_minus_8 : Int) -> Array[Int] {
  [
    82,
    73,
    70,
    70,
    total_minus_8 & 0xff,
    (total_minus_8 >> 8) & 0xff,
    (total_minus_8 >> 16) & 0xff,
    (total_minus_8 >> 24) & 0xff,
    87,
    65,
    86,
    69,
  ]
}

///|
fn fmt_chunk(
  audio_format : Int,
  channels : Int,
  sample_rate : Int,
  bits : Int,
) -> Array[Int] {
  let block_align = channels * bits / 8
  let byte_rate = sample_rate * block_align
  [
    102,
    109,
    116,
    32,
    16,
    0,
    0,
    0,
    audio_format & 0xff,
    (audio_format >> 8) & 0xff,
    channels & 0xff,
    (channels >> 8) & 0xff,
    sample_rate & 0xff,
    (sample_rate >> 8) & 0xff,
    (sample_rate >> 16) & 0xff,
    (sample_rate >> 24) & 0xff,
    byte_rate & 0xff,
    (byte_rate >> 8) & 0xff,
    (byte_rate >> 16) & 0xff,
    (byte_rate >> 24) & 0xff,
    block_align & 0xff,
    (block_align >> 8) & 0xff,
    bits & 0xff,
    (bits >> 8) & 0xff,
  ]
}

///|
fn data_chunk(data : Array[Int]) -> Array[Int] {
  let size = data.length()
  let out = [
    100,
    97,
    116,
    97,
    size & 0xff,
    (size >> 8) & 0xff,
    (size >> 16) & 0xff,
    (size >> 24) & 0xff,
  ]
  for byte in data {
    out.push(byte)
  }
  if size % 2 != 0 {
    out.push(0)
  }
  out
}

///|
fn concat_arrays(a : Array[Int], b : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for value in a {
    out.push(value)
  }
  for value in b {
    out.push(value)
  }
  out
}

///|
fn concat3(a : Array[Int], b : Array[Int], c : Array[Int]) -> Array[Int] {
  concat_arrays(concat_arrays(a, b), c)
}

///|
pub fn fixture_pcm16_mono() -> Array[Int] {
  let payload = [0, 0, 255, 127, 0, 128, 0, 64]
  let body = concat_arrays(fmt_chunk(1, 1, 8000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_pcm8_stereo() -> Array[Int] {
  let payload = [128, 128, 255, 0, 192, 64, 128, 128]
  let body = concat_arrays(fmt_chunk(1, 2, 11025, 8), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_pcm24_mono() -> Array[Int] {
  let payload = [0, 0, 0, 255, 255, 127, 0, 0, 128]
  let body = concat_arrays(fmt_chunk(1, 1, 48000, 24), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_float32_mono() -> Array[Int] {
  let payload = [0, 0, 0, 0, 0, 0, 128, 63, 0, 0, 128, 191]
  let body = concat_arrays(fmt_chunk(3, 1, 44100, 32), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_with_info_and_cue() -> Array[Int] {
  let info_payload = [
    73, 78, 70, 79, 73, 78, 65, 77, 5, 0, 0, 0, 116, 111, 110, 101, 0, 0,
  ]
  let list = [
    76,
    73,
    83,
    84,
    info_payload.length() & 0xff,
    (info_payload.length() >> 8) & 0xff,
    0,
    0,
  ]
  for byte in info_payload {
    list.push(byte)
  }
  let cue_payload = [
    1, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 100, 97, 116, 97, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 0, 0, 0,
  ]
  let cue = [
    99,
    117,
    101,
    32,
    cue_payload.length() & 0xff,
    (cue_payload.length() >> 8) & 0xff,
    0,
    0,
  ]
  for byte in cue_payload {
    cue.push(byte)
  }
  let payload = [0, 0, 0, 0]
  let body = concat3(fmt_chunk(1, 1, 8000, 16), list, cue)
  let all_body = concat_arrays(body, data_chunk(payload))
  concat_arrays(riff_prefix(4 + all_body.length()), all_body)
}

///|
pub fn fixture_not_riff() -> Array[Int] {
  [78, 79, 80, 69, 0, 0, 0, 0, 87, 65, 86, 69]
}

///|
pub fn fixture_missing_data() -> Array[Int] {
  let body = fmt_chunk(1, 1, 8000, 16)
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_unsupported_alaw() -> Array[Int] {
  let payload = [0, 1, 2, 3]
  let body = concat_arrays(fmt_chunk(6, 1, 8000, 8), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}

///|
pub fn fixture_truncated_data() -> Array[Int] {
  let payload = [0, 0, 1]
  let body = concat_arrays(fmt_chunk(1, 1, 8000, 16), data_chunk(payload))
  concat_arrays(riff_prefix(4 + body.length()), body)
}
