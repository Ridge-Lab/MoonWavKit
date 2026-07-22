///|
test "detailed validation passes normal pcm fixture" {
  let report = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_pcm16_mono(),
  )
  assert_true(report.ok)
  assert_eq(report.error_count, 0)
  assert_eq(report.format.sample_rate, 8000)
  assert_eq(report.info.frame_count, 4)
  assert_eq(report.chunks.length(), 2)
  assert_eq(report.chunks[0].id, "fmt ")
  assert_eq(report.chunks[1].id, "data")
}

///|
test "detailed validation reports parser errors" {
  let report = @moonwavkit.validate_wav_detailed(@moonwavkit.fixture_not_riff())
  assert_false(report.ok)
  assert_eq(report.error_count, 1)
  assert_eq(report.issues.length(), 1)
  assert_eq(report.issues[0].code, "not-riff")
  assert_true(report.issues[0].is_error())
}

///|
test "detailed validation reports unsupported encoding" {
  let report = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_unsupported_alaw(),
  )
  assert_false(report.ok)
  assert_eq(report.error_count, 1)
  assert_eq(report.issues[0].code, "unsupported-format")
}

///|
test "detailed validation reports partial frame" {
  let report = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_truncated_data(),
  )
  assert_false(report.ok)
  assert_eq(report.error_count, 1)
  assert_eq(report.issues[0].code, "partial-frame")
}

///|
test "detailed validation includes metadata info messages" {
  let report = @moonwavkit.validate_wav_detailed(
    @moonwavkit.fixture_with_info_and_cue(),
  )
  assert_true(report.ok)
  assert_true(report.info_count >= 2)
  let text = @moonwavkit.validation_report_to_text(report)
  assert_true(text.contains("MoonWavKit validation: PASS"))
  assert_true(text.contains("info-tags"))
  assert_true(text.contains("cue-points"))
}

///|
test "validation severity labels are stable" {
  assert_eq(@moonwavkit.SeverityInfo.label(), "info")
  assert_eq(@moonwavkit.SeverityWarning.label(), "warning")
  assert_eq(@moonwavkit.SeverityError.label(), "error")
}
