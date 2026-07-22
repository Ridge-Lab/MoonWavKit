///|
test "info catalog extracts common list info tags" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_with_info_and_cue())
  assert_true(parsed.ok)
  let catalog = @moonwavkit.collect_info_catalog(parsed.wav)
  assert_true(catalog.has_metadata())
  assert_eq(catalog.title, "tone")
  assert_eq(catalog.display_title(), "tone")
  assert_true(@moonwavkit.has_info_tag(parsed.wav, "INAM"))
  match @moonwavkit.info_tag_value(parsed.wav, "INAM") {
    Some(value) => assert_eq(value, "tone")
    None => assert_true(false)
  }
}

///|
test "cue timeline converts cue samples to seconds" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_with_info_and_cue())
  let timeline = @moonwavkit.collect_cue_timeline(parsed.wav)
  let offsets = @moonwavkit.cue_sample_offsets(parsed.wav)
  let times = @moonwavkit.cue_times_seconds(parsed.wav)
  assert_false(timeline.is_empty())
  assert_eq(timeline.count, 1)
  assert_eq(timeline.first_sample, 2)
  assert_eq(timeline.last_sample, 2)
  assert_eq(offsets.length(), 1)
  assert_eq(offsets[0], 2)
  assert_eq(times.length(), 1)
  assert_eq(times[0], 0.00025)
}

///|
test "format summary and description are stable" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_pcm16_mono())
  let summary = @moonwavkit.summarize_format(parsed.wav)
  assert_eq(summary.encoding, "pcm")
  assert_eq(summary.channels, 1)
  assert_eq(summary.sample_rate, 8000)
  assert_eq(summary.bits_per_sample, 16)
  assert_eq(summary.frame_count, 4)
  let text = @moonwavkit.describe_wav(parsed.wav)
  assert_true(text.contains("MoonWavKit description"))
  assert_true(text.contains("encoding: pcm"))
}

///|
test "chunk table and cue text render readable output" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_with_info_and_cue())
  let chunks = @moonwavkit.chunk_table_to_text(parsed.wav)
  let cues = @moonwavkit.cue_timeline_to_text(
    @moonwavkit.collect_cue_timeline(parsed.wav),
  )
  assert_true(chunks.contains("fmt "))
  assert_true(chunks.contains("data"))
  assert_true(cues.contains("cue timeline"))
  assert_true(cues.contains("sample=2"))
}

///|
test "parse and describe reports errors" {
  let text = @moonwavkit.parse_and_describe(@moonwavkit.fixture_not_riff())
  assert_true(text.contains("error: not-riff"))
}

///|
test "pcm32 fixture decodes signed 32 bit samples" {
  let decoded = @moonwavkit.parse_and_decode(@moonwavkit.fixture_pcm32_mono())
  assert_true(decoded.ok)
  assert_eq(decoded.pcm.bits_per_sample, 32)
  assert_eq(decoded.pcm.samples.length(), 3)
  assert_eq(decoded.pcm.samples[0], 0)
  assert_eq(decoded.pcm.samples[1], 2147483647)
  assert_eq(decoded.pcm.samples[2], -2147483648)
}

///|
test "unknown chunk is preserved and reported as info" {
  let parsed = @moonwavkit.parse_wav(@moonwavkit.fixture_with_unknown_chunk())
  assert_true(parsed.ok)
  assert_true(parsed.wav.has_chunk("JUNK"))
  let report = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_with_unknown_chunk(),
  )
  assert_true(report.ok)
  assert_true(report.info_count >= 1)
  let text = @moonwavkit.validation_report_to_text(report)
  assert_true(text.contains("unknown-chunk"))
}

///|
test "extra fixtures cover validation warnings" {
  let low = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_low_sample_rate(),
  )
  let mismatch = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_riff_size_mismatch(),
  )
  assert_true(low.ok)
  assert_true(low.warning_count >= 1)
  assert_true(mismatch.ok)
  assert_true(mismatch.warning_count >= 1)
}

///|
test "phase fixture can be downmixed and fingerprinted" {
  let decoded = @moonwavkit.parse_and_decode(
    @moonwavkit.fixture_stereo_phase_test(),
  )
  assert_true(decoded.ok)
  assert_eq(decoded.float_buffer.channels, 2)
  let mono = @moonwavkit.downmix_to_mono(decoded.float_buffer)
  assert_eq(mono.channels, 1)
  assert_eq(mono.frame_count(), 3)
  let fingerprint = @moonwavkit.audio_fingerprint(mono)
  assert_eq(fingerprint.frame_count, 3)
  assert_eq(fingerprint.channels, 1)
}

///|
test "quality fixtures feed quality profile" {
  let silence = @moonwavkit.parse_and_decode(@moonwavkit.fixture_tiny_silence())
  let clipped = @moonwavkit.parse_and_decode(
    @moonwavkit.fixture_quality_clipped(),
  )
  let silence_profile = @moonwavkit.inspect_audio_quality(silence.float_buffer)
  let clipped_profile = @moonwavkit.inspect_audio_quality(clipped.float_buffer)
  assert_true(silence_profile.score < 100)
  assert_false(clipped_profile.ok)
  assert_eq(
    @moonwavkit.recommended_quality_action(clipped_profile),
    "reduce-gain-or-normalize",
  )
}
