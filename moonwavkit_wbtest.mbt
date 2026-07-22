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
test "decode options validate target channel request" {
  assert_true(DecodeOptions::new().is_valid())
  assert_true(DecodeOptions::new(target_channels=2).is_valid())
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
