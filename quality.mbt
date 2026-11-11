///|
#derive(Eq, @debug.Debug)
pub(all) enum QualityFindingKind {
  QualityOk
  QualityClipping
  QualityMostlySilent
  QualityVeryQuiet
  QualityDcOffset
  QualityHighCrest
  QualityHighZeroCrossing
}

///|
pub fn QualityFindingKind::label(self : QualityFindingKind) -> String {
  match self {
    QualityOk => "ok"
    QualityClipping => "clipping"
    QualityMostlySilent => "mostly-silent"
    QualityVeryQuiet => "very-quiet"
    QualityDcOffset => "dc-offset"
    QualityHighCrest => "high-crest"
    QualityHighZeroCrossing => "high-zero-crossing"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct QualityFinding {
  kind : QualityFindingKind
  severity : ValidationSeverity
  message : String
  value : Double
}

///|
pub fn QualityFinding::new(
  kind : QualityFindingKind,
  severity : ValidationSeverity,
  message : String,
  value~ : Double = 0.0,
) -> QualityFinding {
  { kind, severity, message, value, }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct QualityProfile {
  ok : Bool
  score : Int32
  stats : AudioStats
  crest_factor : Double
  zero_crossing_rate : Double
  findings : Array[QualityFinding]
}

///|
pub fn QualityProfile::empty() -> QualityProfile {
  {
    ok: false,
    score: 0,
    stats: AudioStats::empty(),
    crest_factor: 0.0,
    zero_crossing_rate: 0.0,
    findings: [],
  }
}

///|
pub fn QualityProfile::has_warnings(self : QualityProfile) -> Bool {
  for finding in self.findings {
    if finding.severity == SeverityWarning || finding.severity == SeverityError {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn quality_penalty(finding : QualityFinding) -> Int32 {
  match finding.kind {
    QualityOk => 0
    QualityClipping => 30
    QualityMostlySilent => 20
    QualityVeryQuiet => 15
    QualityDcOffset => 15
    QualityHighCrest => 10
    QualityHighZeroCrossing => 8
  }
}

///|
fn final_quality_score(findings : Array[QualityFinding]) -> Int32 {
  let penalty = for finding in findings; value = 0 {
    continue value + quality_penalty(finding)
  } nobreak {
    value
  }
  let score = 100 - penalty
  if score < 0 {
    0
  } else {
    score
  }
}

///|
pub fn inspect_audio_quality(buffer : FloatBuffer) -> QualityProfile {
  if !buffer.is_valid() {
    QualityProfile::empty()
  } else {
    let stats = analyze_audio(buffer)
    let crest = crest_factor(buffer)
    let zcr = zero_crossing_rate(buffer)
    let findings : Array[QualityFinding] = []
    if stats.clipped_samples > 0 {
      findings.push(
        QualityFinding::new(
          QualityClipping,
          SeverityError,
          "samples reach or exceed clipping threshold",
          value=stats.clipped_samples.to_double(),
        ),
      )
    }
    if stats.silence_ratio() > 0.95 {
      findings.push(
        QualityFinding::new(
          QualityMostlySilent,
          SeverityWarning,
          "more than 95 percent of samples are near silence",
          value=stats.silence_ratio(),
        ),
      )
    } else if stats.peak < 0.02 {
      findings.push(
        QualityFinding::new(
          QualityVeryQuiet,
          SeverityWarning,
          "peak amplitude is very low",
          value=stats.peak,
        ),
      )
    }
    if abs_double(stats.dc_offset) > 0.05 {
      findings.push(
        QualityFinding::new(
          QualityDcOffset,
          SeverityWarning,
          "average sample value suggests DC offset",
          value=stats.dc_offset,
        ),
      )
    }
    if crest > 8.0 {
      findings.push(
        QualityFinding::new(
          QualityHighCrest,
          SeverityInfo,
          "crest factor is high; signal may have sharp transients",
          value=crest,
        ),
      )
    }
    if zcr > 0.65 {
      findings.push(
        QualityFinding::new(
          QualityHighZeroCrossing,
          SeverityInfo,
          "zero crossing rate is high",
          value=zcr,
        ),
      )
    }
    if findings.length() == 0 {
      findings.push(
        QualityFinding::new(
          QualityOk,
          SeverityInfo,
          "no common quality issue detected",
        ),
      )
    }
    {
      ok: findings[0].kind != QualityClipping,
      score: final_quality_score(findings),
      stats,
      crest_factor: crest,
      zero_crossing_rate: zcr,
      findings,
    }
  }
}

///|
pub fn quality_profile_to_text(profile : QualityProfile) -> String {
  if profile.findings.length() == 0 {
    "MoonWavKit quality: empty"
  } else {
    let header = "MoonWavKit quality\nscore: \{profile.score}\npeak: \{profile.stats.peak}\nrms: \{profile.stats.rms}"
    for finding in profile.findings; text = header {
      continue "\{text}\n- \{finding.severity.label()} \{finding.kind.label()}: \{finding.message}"
    } nobreak {
      text
    }
  }
}

///|
pub fn recommended_quality_action(profile : QualityProfile) -> String {
  if profile.findings.length() == 0 {
    "no-audio"
  } else {
    let first = profile.findings[0]
    match first.kind {
      QualityOk => "ready"
      QualityClipping => "reduce-gain-or-normalize"
      QualityMostlySilent => "trim-or-check-input"
      QualityVeryQuiet => "normalize-peak"
      QualityDcOffset => "remove-dc-offset"
      QualityHighCrest => "inspect-transients"
      QualityHighZeroCrossing => "inspect-noise"
    }
  }
}
