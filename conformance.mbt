///|
#derive(Eq, @debug.Debug)
pub(all) struct SupportEntry {
  encoding : String
  bits_per_sample : Int32
  can_parse : Bool
  can_decode : Bool
  can_encode : Bool
  notes : String
}

///|
pub fn SupportEntry::new(
  encoding : String,
  bits_per_sample : Int32,
  can_parse : Bool,
  can_decode : Bool,
  can_encode : Bool,
  notes : String,
) -> SupportEntry {
  { encoding, bits_per_sample, can_parse, can_decode, can_encode, notes, }
}

///|
pub fn SupportEntry::status(self : SupportEntry) -> String {
  if self.can_parse && self.can_decode {
    "supported"
  } else if self.can_parse {
    "metadata-only"
  } else {
    "unsupported"
  }
}

///|
pub fn supported_format_matrix() -> Array[SupportEntry] {
  [
    SupportEntry::new("PCM unsigned", 8, true, true, true, "common 8-bit WAV"),
    SupportEntry::new(
      "PCM signed", 16, true, true, true, "most common uncompressed WAV",
    ),
    SupportEntry::new(
      "PCM signed", 24, true, true, true, "studio/intermediate assets",
    ),
    SupportEntry::new(
      "PCM signed", 32, true, true, true, "integer high dynamic range",
    ),
    SupportEntry::new(
      "IEEE Float", 32, true, true, false, "decode supported; encoder v1 writes PCM",
    ),
    SupportEntry::new(
      "A-law", 8, true, false, false, "recognized but intentionally not decoded",
    ),
    SupportEntry::new(
      "mu-law", 8, true, false, false, "recognized but intentionally not decoded",
    ),
    SupportEntry::new(
      "Extensible", 0, true, false, false, "planned after base PCM scope",
    ),
  ]
}

///|
pub fn support_matrix_to_text() -> String {
  for entry in supported_format_matrix(); text = "MoonWavKit support matrix" {
    continue "\{text}\n\{entry.encoding} \{entry.bits_per_sample}-bit: \{entry.status()} - \{entry.notes}"
  } nobreak {
    text
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum FixtureExpectation {
  FixtureShouldPass
  FixtureShouldFailValidation
  FixtureShouldFailDecode
}

///|
pub fn FixtureExpectation::label(self : FixtureExpectation) -> String {
  match self {
    FixtureShouldPass => "pass"
    FixtureShouldFailValidation => "validation-fail"
    FixtureShouldFailDecode => "decode-fail"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct FixtureCase {
  name : String
  bytes : Array[Int32]
  expectation : FixtureExpectation
  expected_error : String
}

///|
pub fn FixtureCase::new(
  name : String,
  bytes : Array[Int32],
  expectation : FixtureExpectation,
  expected_error~ : String = "",
) -> FixtureCase {
  { name, bytes, expectation, expected_error, }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct FixtureCaseResult {
  name : String
  passed : Bool
  expectation : String
  actual_error : String
  frames : Int32
  channels : Int32
  sample_rate : Int32
}

///|
pub fn FixtureCaseResult::new(
  name : String,
  passed : Bool,
  expectation : String,
  actual_error : String,
  frames : Int32,
  channels : Int32,
  sample_rate : Int32,
) -> FixtureCaseResult {
  { name, passed, expectation, actual_error, frames, channels, sample_rate, }
}

///|
pub fn fixture_catalog() -> Array[FixtureCase] {
  [
    FixtureCase::new("pcm16-mono", fixture_pcm16_mono(), FixtureShouldPass),
    FixtureCase::new("pcm8-stereo", fixture_pcm8_stereo(), FixtureShouldPass),
    FixtureCase::new("pcm24-mono", fixture_pcm24_mono(), FixtureShouldPass),
    FixtureCase::new("pcm32-mono", fixture_pcm32_mono(), FixtureShouldPass),
    FixtureCase::new("float32-mono", fixture_float32_mono(), FixtureShouldPass),
    FixtureCase::new("info-cue", fixture_with_info_and_cue(), FixtureShouldPass),
    FixtureCase::new(
      "unknown-chunk",
      fixture_with_unknown_chunk(),
      FixtureShouldPass,
    ),
    FixtureCase::new(
      "not-riff",
      fixture_not_riff(),
      FixtureShouldFailValidation,
      expected_error="not-riff",
    ),
    FixtureCase::new(
      "missing-data",
      fixture_missing_data(),
      FixtureShouldFailValidation,
      expected_error="missing-data",
    ),
    FixtureCase::new(
      "unsupported-alaw",
      fixture_unsupported_alaw(),
      FixtureShouldFailValidation,
      expected_error="unsupported-format",
    ),
    FixtureCase::new(
      "truncated-data",
      fixture_truncated_data(),
      FixtureShouldFailValidation,
      expected_error="truncated-data",
    ),
  ]
}

///|
pub fn run_fixture_case(case : FixtureCase) -> FixtureCaseResult {
  let validation = validate_wav(case.bytes)
  if validation.is_error() {
    let actual = validation.code()
    let passed = case.expectation == FixtureShouldFailValidation &&
      (case.expected_error.length() == 0 || case.expected_error == actual)
    FixtureCaseResult::new(
      case.name,
      passed,
      case.expectation.label(),
      actual,
      0,
      0,
      0,
    )
  } else {
    let decoded = parse_and_decode(case.bytes)
    if !decoded.ok {
      let actual = decoded.error.code()
      let passed = case.expectation == FixtureShouldFailDecode &&
        (case.expected_error.length() == 0 || case.expected_error == actual)
      FixtureCaseResult::new(
        case.name,
        passed,
        case.expectation.label(),
        actual,
        0,
        0,
        0,
      )
    } else {
      FixtureCaseResult::new(
        case.name,
        case.expectation == FixtureShouldPass,
        case.expectation.label(),
        "",
        decoded.float_buffer.frame_count(),
        decoded.float_buffer.channels,
        decoded.float_buffer.sample_rate,
      )
    }
  }
}

///|
pub fn run_fixture_catalog() -> Array[FixtureCaseResult] {
  let cases = fixture_catalog()
  Array::makei(cases.length(), i => run_fixture_case(cases[i]))
}

///|
pub fn fixture_catalog_passed() -> Bool {
  for result in run_fixture_catalog() {
    if !result.passed {
      break false
    }
  } nobreak {
    true
  }
}

///|
pub fn fixture_catalog_report() -> String {
  for result in run_fixture_catalog(); text = "MoonWavKit fixture catalog" {
    let status = if result.passed { "PASS" } else { "FAIL" }
    continue "\{text}\n\{status} \{result.name} expectation=\{result.expectation} error=\{result.actual_error} frames=\{result.frames}"
  } nobreak {
    text
  }
}
