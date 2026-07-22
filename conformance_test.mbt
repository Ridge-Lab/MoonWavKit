///|
test "support matrix documents supported and recognized formats" {
  let matrix = @moonwavkit.supported_format_matrix()
  assert_true(matrix.length() >= 8)
  assert_eq(matrix[0].status(), "supported")
  assert_eq(matrix[4].status(), "supported")
  assert_eq(matrix[5].status(), "metadata-only")
  let text = @moonwavkit.support_matrix_to_text()
  assert_true(text.contains("MoonWavKit support matrix"))
  assert_true(text.contains("IEEE Float"))
}

///|
test "fixture catalog runs as conformance smoke suite" {
  let cases = @moonwavkit.fixture_catalog()
  let results = @moonwavkit.run_fixture_catalog()
  assert_true(cases.length() >= 10)
  assert_eq(cases.length(), results.length())
  assert_true(@moonwavkit.fixture_catalog_passed())
  let report = @moonwavkit.fixture_catalog_report()
  assert_true(report.contains("MoonWavKit fixture catalog"))
  assert_true(report.contains("PASS pcm16-mono"))
}

///|
test "single fixture case result carries decoded facts" {
  let result = @moonwavkit.run_fixture_case(
    @moonwavkit.FixtureCase::new(
      "pcm16",
      @moonwavkit.fixture_pcm16_mono(),
      @moonwavkit.FixtureShouldPass,
    ),
  )
  assert_true(result.passed)
  assert_eq(result.frames, 4)
  assert_eq(result.channels, 1)
  assert_eq(result.sample_rate, 8000)
}

///|
test "single fixture case can assert expected failure" {
  let result = @moonwavkit.run_fixture_case(
    @moonwavkit.FixtureCase::new(
      "bad",
      @moonwavkit.fixture_not_riff(),
      @moonwavkit.FixtureShouldFailValidation,
      expected_error="not-riff",
    ),
  )
  assert_true(result.passed)
  assert_eq(result.actual_error, "not-riff")
}
