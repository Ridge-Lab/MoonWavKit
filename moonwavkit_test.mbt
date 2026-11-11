///|
fn close(actual : Double, expected : Double, tolerance : Double) -> Bool {
  let diff = if actual >= expected {
    actual - expected
  } else {
    expected - actual
  }
  diff <= tolerance
}

///|
test "parse riff header fmt and data chunks" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_pcm16_mono())
  assert_true(parsed.ok)
  assert_eq(parsed.wav.header.riff_id, "RIFF")
  assert_eq(parsed.wav.header.wave_id, "WAVE")
  assert_true(parsed.wav.format.encoding == @moonwavkit.EncodingPcm)
  // 0.1.3 clients can also call the derived methods directly.
  assert_true(parsed.wav.format.encoding.equal(@moonwavkit.EncodingPcm))
  assert_false(parsed.wav.format.encoding.not_equal(@moonwavkit.EncodingPcm))
  assert_eq(parsed.wav.format.encoding.to_repr().to_string(), "EncodingPcm")
  assert_eq(parsed.wav.format.channels, 1)
  assert_eq(parsed.wav.format.sample_rate, 8000)
  assert_eq(parsed.wav.format.bits_per_sample, 16)
  assert_true(parsed.wav.has_chunk("fmt "))
  assert_true(parsed.wav.has_chunk("data"))
  assert_eq(parsed.wav.chunks.length(), 2)
}

///|
test "parse list info and cue points" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_with_info_and_cue())
  assert_true(parsed.ok)
  assert_true(parsed.wav.has_chunk("LIST"))
  assert_true(parsed.wav.has_chunk("cue "))
  assert_eq(parsed.wav.info_tags.length(), 1)
  assert_eq(parsed.wav.info_tags[0].key, "INAM")
  assert_eq(parsed.wav.info_tags[0].value, "tone")
  assert_eq(parsed.wav.cue_points.length(), 1)
  assert_eq(parsed.wav.cue_points[0].id, 7)
  assert_eq(parsed.wav.cue_points[0].sample_offset, 2)
}

///|
test "decode pcm16 to integer and float buffers" {
  let bytes = @moonwavkit.fixture_pcm16_mono()
  let parsed = @moonwavkit.parse_wav(bytes)
  let decoded = @moonwavkit.decode_pcm(bytes, parsed.wav)
  assert_true(decoded.ok)
  assert_eq(decoded.pcm.samples.length(), 4)
  assert_eq(decoded.pcm.samples[0], 0)
  assert_eq(decoded.pcm.samples[1], 32767)
  assert_eq(decoded.pcm.samples[2], -32768)
  assert_eq(decoded.float_buffer.channels, 1)
  assert_eq(decoded.float_buffer.sample_rate, 8000)
  assert_true(close(decoded.float_buffer.samples[1], 0.9999, 0.001))
  assert_eq(decoded.float_buffer.samples[2], -1.0)
}

///|
test "decode pcm8 stereo and split channels" {
  let bytes = @moonwavkit.fixture_pcm8_stereo()
  let parsed = @moonwavkit.parse_wav(bytes)
  let decoded = @moonwavkit.decode_pcm(bytes, parsed.wav)
  assert_true(decoded.ok)
  assert_eq(decoded.float_buffer.channels, 2)
  assert_eq(decoded.float_buffer.frame_count(), 4)
  let left = @moonwavkit.split_channel(decoded.float_buffer, 0)
  let right = @moonwavkit.split_channel(decoded.float_buffer, 1)
  assert_eq(left.length(), 4)
  assert_eq(right.length(), 4)
  assert_eq(left[0], 0.0)
  assert_true(close(left[1], 0.9921875, 0.0001))
  assert_true(close(right[1], -1.0, 0.0001))
}

///|
test "decode pcm24 and float32 fixtures" {
  let pcm24 = @moonwavkit.parse_and_decode(@moonwavkit.fixture_pcm24_mono())
  assert_true(pcm24.ok)
  assert_eq(pcm24.pcm.bits_per_sample, 24)
  assert_eq(pcm24.pcm.samples[1], 8388607)
  assert_eq(pcm24.pcm.samples[2], -8388608)
  let float32 = @moonwavkit.parse_and_decode(@moonwavkit.fixture_float32_mono())
  assert_true(float32.ok)
  assert_eq(float32.pcm.bits_per_sample, 32)
  assert_eq(float32.float_buffer.samples[0], 0.0)
  assert_eq(float32.float_buffer.samples[1], 1.0)
  assert_eq(float32.float_buffer.samples[2], -1.0)
}

///|
test "audio stats and quality label report useful values" {
  let decoded = @moonwavkit.parse_and_decode(@moonwavkit.fixture_pcm16_mono())
  let stats = @moonwavkit.analyze_audio(decoded.float_buffer)
  assert_eq(stats.frame_count, 4)
  assert_eq(stats.sample_count, 4)
  assert_eq(stats.duration_seconds, 0.0005)
  assert_true(stats.peak >= 0.999)
  assert_true(stats.rms > 0.6)
  assert_true(stats.has_clipping())
  assert_eq(@moonwavkit.stats_quality_label(stats), "clipped")
}

///|
test "waveform summary creates stable buckets" {
  let decoded = @moonwavkit.parse_and_decode(@moonwavkit.fixture_pcm16_mono())
  let summary = @moonwavkit.summarize_waveform(decoded.float_buffer, 2)
  assert_true(summary.is_valid())
  assert_eq(summary.bucket_count, 2)
  assert_eq(summary.source_samples, 4)
  assert_eq(summary.buckets[0].index, 0)
  assert_true(summary.buckets[0].max > 0.99)
  assert_true(summary.buckets[1].min <= -1.0)
}

///|
test "downmix stereo fixture to mono" {
  let decoded = @moonwavkit.parse_and_decode(@moonwavkit.fixture_pcm8_stereo())
  let mono = @moonwavkit.downmix_to_mono(decoded.float_buffer)
  assert_eq(mono.channels, 1)
  assert_eq(mono.frame_count(), 4)
  assert_eq(mono.samples[0], 0.0)
  assert_true(close(mono.samples[1], -0.00390625, 0.0001))
}

///|
test "validation rejects malformed and unsupported data" {
  assert_true(
    @moonwavkit.validate_wav(@moonwavkit.fixture_not_riff()).kind ==
    @moonwavkit.ErrorNotRiff,
  )
  assert_true(
    @moonwavkit.validate_wav(@moonwavkit.fixture_missing_data()).kind ==
    @moonwavkit.ErrorMissingData,
  )
  assert_true(
    @moonwavkit.validate_wav(@moonwavkit.fixture_unsupported_alaw()).kind ==
    @moonwavkit.ErrorUnsupportedFormat,
  )
  assert_true(
    @moonwavkit.validate_wav(@moonwavkit.fixture_truncated_data()).kind ==
    @moonwavkit.ErrorTruncatedData,
  )
}

///|
test "report renders text and json smoke output" {
  let report = @moonwavkit.build_report(@moonwavkit.fixture_pcm16_mono())
  assert_true(report.ok)
  assert_eq(report.encoding, "pcm")
  assert_eq(report.channels, 1)
  assert_eq(report.sample_rate, 8000)
  assert_eq(report.quality, "clipped")
  let text = report.render(@moonwavkit.ReportText)
  let json = report.render(@moonwavkit.ReportJson)
  assert_true(text.contains("MoonWavKit report"))
  assert_true(json.contains("\"ok\": true"))
}

///|
test "decode rejects unavailable channel conversion" {
  let bytes = @moonwavkit.fixture_pcm16_mono()
  let parsed = @moonwavkit.parse_wav(bytes)
  assert_true(parsed.ok)
  let decoded = @moonwavkit.decode_pcm(
    bytes,
    parsed.wav,
    options=@moonwavkit.DecodeOptions::new(target_channels=2),
  )
  assert_false(decoded.ok)
  assert_eq(decoded.error.kind, @moonwavkit.ErrorInvalidArgument)
}

///|
test "decode validates provided bytes against parsed data bounds" {
  let bytes = @moonwavkit.fixture_pcm16_mono()
  let parsed = @moonwavkit.parse_wav(bytes)
  assert_true(parsed.ok)
  let decoded = @moonwavkit.decode_pcm([], parsed.wav)
  assert_false(decoded.ok)
  assert_eq(decoded.error.kind, @moonwavkit.ErrorTruncatedData)
}
