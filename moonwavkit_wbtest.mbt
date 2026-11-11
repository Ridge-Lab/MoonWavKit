///|
test "byte reader reads little endian integers and fourcc values" {
  let reader = ByteReader::new([82, 73, 70, 70, 1, 2, 3, 4, 255, 127, 0, 128])
  assert_eq(reader.length(), 12)
  assert_eq(reader.fourcc_at(0), "RIFF")
  assert_eq(reader.u16_le_at(4), 513)
  assert_eq(reader.u24_le_at(4), 197121)
  assert_eq(reader.u32_le_at(4), 67305985)
  assert_eq(reader.i16_le_at(8), 32767)
  assert_eq(reader.i16_le_at(10), -32768)
}

///|
test "chunk bounds include padded odd byte" {
  let chunk = WaveChunk::new("JUNK", 12, 20, 5)
  assert_eq(chunk.padded_size, 6)
  assert_eq(chunk.end_offset(), 26)
  assert_true(chunk.contains(20))
  assert_true(chunk.contains(24))
  assert_false(chunk.contains(25))
  assert_false(chunk.is_known())
}

///|
test "format validation catches inconsistent block align" {
  let valid = WaveFormat::new(1, 2, 44100, 176400, 4, 16)
  assert_true(valid.is_valid())
  assert_true(valid.is_supported())
  let bad_align = WaveFormat::new(1, 2, 44100, 176400, 2, 16)
  assert_false(bad_align.is_valid())
}

///|
test "decode options reject unsupported raw float output" {
  assert_true(DecodeOptions::new().is_valid())
  assert_true(DecodeOptions::new(target_channels=2).is_valid())
  assert_false(DecodeOptions::new(normalize=false).is_valid())
  assert_false(DecodeOptions::new(target_channels=-1).is_valid())
}

///|
test "silence region detection returns sample spans" {
  let buffer = FloatBuffer::new(1, 8000, [0.0, 0.0, 0.01, 0.0, 0.0, 0.0])
  let regions = detect_silence_regions(buffer, 2)
  assert_eq(regions.length(), 2)
  assert_eq(regions[0].offset, 0)
  assert_eq(regions[0].size, 2)
  assert_eq(regions[1].offset, 3)
  assert_eq(regions[1].size, 3)
}

///|
test "invalid float buffer returns empty analysis" {
  let stats = analyze_audio(FloatBuffer::empty())
  assert_eq(stats.sample_count, 0)
  assert_eq(stats_quality_label(stats), "empty")
  assert_eq(summarize_waveform(FloatBuffer::empty(), 8).bucket_count, 0)
}

///|
test "empty data chunk has zero frames" {
  let body = concat_arrays(fmt_chunk(1, 1, 8000, 16), data_chunk([]))
  let result = parse_and_decode(
    concat_arrays(riff_prefix(4 + body.length()), body),
  )
  assert_true(result.ok)
  assert_eq(result.float_buffer.frame_count(), 0)
}

///|
test "read ranges reject signed wraparound" {
  let reader = ByteReader::at([0], 2147483647)
  assert_false(reader.can_read(1))
  assert_false(reader.slice_can_read(1, 2147483647))
}

///|
test "LIST lengths cannot move the metadata cursor backwards" {
  let fmt = fmt_chunk(1, 1, 8000, 16)
  let list = [
    76, 73, 83, 84, 12, 0, 0, 0, 73, 78, 70, 79, 73, 78, 65, 77, 248, 255, 255, 255,
  ]
  let body = concat3(fmt, list, data_chunk([0, 0]))
  let result = parse_wav(concat_arrays(riff_prefix(4 + body.length()), body))
  assert_false(result.ok)
  assert_eq(result.error.code(), "chunk-out-of-bounds")
  assert_eq(result.error.offset, 48)
}

///|
test "RIFF size delimits the file within a larger byte array" {
  let fmt = fmt_chunk(1, 1, 8000, 16)
  let prefix = concat_arrays(riff_prefix(4 + fmt.length()), fmt)
  let result = parse_wav(concat_arrays(prefix, data_chunk([0, 0])))
  assert_false(result.ok)
  assert_eq(result.error.code(), "missing-data")
}

///|
test "float WAV preserves finite bit patterns and silences nonfinite samples" {
  let words : Array[Int32] = [
    0x80000000, 0x00000001, 0x80000001, 0x3fc00000, 0xbf000000, 0x7f800000, 0xff800000,
    0x7fc00001,
  ]
  let payload = Array::makei(words.length() * 4, i => {
    (words[i / 4] >> (i % 4 * 8)) & 255
  })
  let body = concat_arrays(fmt_chunk(3, 1, 48000, 32), data_chunk(payload))
  let bytes = concat_arrays(riff_prefix(4 + body.length()), body)
  let raw = parse_and_decode(bytes, options=DecodeOptions::new(clamp=false))
  assert_true(raw.ok)
  let samples = raw.float_buffer.samples
  assert_eq(samples[0].reinterpret_as_uint64(), 0x8000000000000000UL)
  // The smallest binary32 subnormal is exactly 2^-149 in binary64.
  assert_eq(samples[1].reinterpret_as_uint64(), 0x36a0000000000000UL)
  assert_eq(samples[2].reinterpret_as_uint64(), 0xb6a0000000000000UL)
  assert_eq(samples[3], 1.5)
  assert_eq(samples[4], -0.5)
  for i in 5..<8 {
    assert_eq(samples[i], 0.0)
    assert_eq(raw.pcm.samples[i], 0)
  }
  let limited = parse_and_decode(bytes, options=DecodeOptions::new(clamp=true))
  assert_true(limited.ok)
  assert_eq(limited.float_buffer.samples[3], 1.0)
}
