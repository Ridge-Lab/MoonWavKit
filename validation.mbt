///|
#derive(Eq, @debug.Debug)
pub(all) enum ValidationSeverity {
  SeverityInfo
  SeverityWarning
  SeverityError
}

///|
pub fn ValidationSeverity::label(self : ValidationSeverity) -> String {
  match self {
    SeverityInfo => "info"
    SeverityWarning => "warning"
    SeverityError => "error"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ValidationIssue {
  severity : ValidationSeverity
  code : String
  message : String
  offset : Int32
}

///|
pub fn ValidationIssue::new(
  severity : ValidationSeverity,
  code : String,
  message : String,
  offset~ : Int32 = 0,
) -> ValidationIssue {
  { severity, code, message, offset, }
}

///|
pub fn ValidationIssue::is_error(self : ValidationIssue) -> Bool {
  self.severity == SeverityError
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ChunkSummary {
  id : String
  offset : Int32
  data_offset : Int32
  size : Int32
  known : Bool
}

///|
pub fn ChunkSummary::from_chunk(chunk : WaveChunk) -> ChunkSummary {
  {
    id: chunk.id,
    offset: chunk.offset,
    data_offset: chunk.data_offset,
    size: chunk.size,
    known: chunk.is_known(),
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ValidationReport {
  ok : Bool
  error_count : Int32
  warning_count : Int32
  info_count : Int32
  format : WaveFormat
  info : WaveInfo
  issues : Array[ValidationIssue]
  chunks : Array[ChunkSummary]
}

///|
pub fn ValidationReport::empty() -> ValidationReport {
  {
    ok: false,
    error_count: 0,
    warning_count: 0,
    info_count: 0,
    format: WaveFormat::empty(),
    info: WaveInfo::empty(),
    issues: [],
    chunks: [],
  }
}

///|
pub fn ValidationReport::has_errors(self : ValidationReport) -> Bool {
  self.error_count > 0
}

///|
pub fn ValidationReport::has_warnings(self : ValidationReport) -> Bool {
  self.warning_count > 0
}

///|
fn count_severity(
  issues : Array[ValidationIssue],
  severity : ValidationSeverity,
) -> Int32 {
  for issue in issues; count = 0 {
    if issue.severity == severity {
      continue count + 1
    } else {
      continue count
    }
  } nobreak {
    count
  }
}

///|
fn chunk_summaries(chunks : Array[WaveChunk]) -> Array[ChunkSummary] {
  Array::makei(chunks.length(), i => ChunkSummary::from_chunk(chunks[i]))
}

///|
fn issue_from_error(error : WavError) -> ValidationIssue {
  ValidationIssue::new(
    SeverityError,
    error.code(),
    error.message,
    offset=error.offset,
  )
}

///|
fn add_format_warnings(
  wav : ParsedWav,
  issues : Array[ValidationIssue],
) -> Unit {
  if wav.format.extra_size > 0 {
    issues.push(
      ValidationIssue::new(
        SeverityInfo,
        "fmt-extra",
        "fmt chunk contains extension bytes that are preserved but not interpreted",
      ),
    )
  }
  if wav.header.file_size_minus_8 + 8 != wav.source_length {
    issues.push(
      ValidationIssue::new(
        SeverityWarning,
        "riff-size-mismatch",
        "RIFF declared size does not match the provided byte array length",
      ),
    )
  }
  if wav.format.sample_rate < 8000 {
    issues.push(
      ValidationIssue::new(
        SeverityWarning,
        "low-sample-rate",
        "sample rate is below common speech/audio interchange ranges",
      ),
    )
  }
  if wav.format.channels > 8 {
    issues.push(
      ValidationIssue::new(
        SeverityWarning,
        "many-channels",
        "file uses more than eight channels; downstream tools may need explicit layout handling",
      ),
    )
  }
  if !wav.format.is_supported() {
    issues.push(
      ValidationIssue::new(
        SeverityError,
        "unsupported-format",
        "MoonWavKit v1 supports PCM 8/16/24/32-bit and IEEE Float32 only",
      ),
    )
  }
  if wav.format.block_align != wav.format.expected_block_align() {
    issues.push(
      ValidationIssue::new(
        SeverityError,
        "block-align-mismatch",
        "fmt block_align does not match channels * bytes_per_sample",
      ),
    )
  }
  if wav.format.byte_rate != wav.format.expected_byte_rate() {
    issues.push(
      ValidationIssue::new(
        SeverityError,
        "byte-rate-mismatch",
        "fmt byte_rate does not match sample_rate * block_align",
      ),
    )
  }
  if wav.format.block_align > 0 && wav.data_size % wav.format.block_align != 0 {
    issues.push(
      ValidationIssue::new(
        SeverityError,
        "partial-frame",
        "data chunk ends in a partial audio frame",
        offset=wav.data_offset + wav.data_size,
      ),
    )
  }
}

///|
fn add_chunk_warnings(wav : ParsedWav, issues : Array[ValidationIssue]) -> Unit {
  let mut data_count = 0
  let mut fmt_count = 0
  for chunk in wav.chunks {
    if chunk.id == "data" {
      data_count = data_count + 1
    } else if chunk.id == "fmt " {
      fmt_count = fmt_count + 1
    } else if !chunk.is_known() {
      issues.push(
        ValidationIssue::new(
          SeverityInfo,
          "unknown-chunk",
          "unknown chunk is skipped and preserved in chunk metadata: \{chunk.id}",
          offset=chunk.offset,
        ),
      )
    }
  }
  if fmt_count > 1 {
    issues.push(
      ValidationIssue::new(
        SeverityWarning,
        "multiple-fmt",
        "multiple fmt chunks were found; parser uses the last one seen",
      ),
    )
  }
  if data_count > 1 {
    issues.push(
      ValidationIssue::new(
        SeverityWarning,
        "multiple-data",
        "multiple data chunks were found; parser uses the last one seen",
      ),
    )
  }
  if wav.info_tags.length() > 0 {
    issues.push(
      ValidationIssue::new(
        SeverityInfo,
        "info-tags",
        "LIST/INFO metadata tags were parsed",
      ),
    )
  }
  if wav.cue_points.length() > 0 {
    issues.push(
      ValidationIssue::new(SeverityInfo, "cue-points", "cue points were parsed"),
    )
  }
}

///|
fn validation_report_from_wav(
  wav : ParsedWav,
  issues : Array[ValidationIssue],
) -> ValidationReport {
  add_format_warnings(wav, issues)
  add_chunk_warnings(wav, issues)
  let errors = count_severity(issues, SeverityError)
  let warnings = count_severity(issues, SeverityWarning)
  let infos = count_severity(issues, SeverityInfo)
  {
    ok: errors == 0,
    error_count: errors,
    warning_count: warnings,
    info_count: infos,
    format: wav.format,
    info: wav.info(),
    issues,
    chunks: chunk_summaries(wav.chunks),
  }
}

///|
pub fn validate_wav_detailed(bytes : Array[Int32]) -> ValidationReport {
  let parsed = parse_wav(bytes)
  let issues : Array[ValidationIssue] = []
  if !parsed.ok {
    issues.push(issue_from_error(parsed.error))
    let errors = count_severity(issues, SeverityError)
    {
      ok: false,
      error_count: errors,
      warning_count: 0,
      info_count: 0,
      format: WaveFormat::empty(),
      info: WaveInfo::empty(),
      issues,
      chunks: [],
    }
  } else {
    validation_report_from_wav(parsed.wav, issues)
  }
}

///|
pub fn validation_report_to_text(report : ValidationReport) -> String {
  let header = if report.ok {
    "MoonWavKit validation: PASS"
  } else {
    "MoonWavKit validation: FAIL"
  }
  let summary = "\{header}\nerrors: \{report.error_count}\nwarnings: \{report.warning_count}\ninfo: \{report.info_count}\nchunks: \{report.chunks.length()}"
  if report.issues.length() == 0 {
    summary
  } else {
    for issue in report.issues; text = summary {
      continue "\{text}\n- \{issue.severity.label()} \{issue.code}: \{issue.message}"
    } nobreak {
      text
    }
  }
}
