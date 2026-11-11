///|
#derive(Eq, @debug.Debug)
pub(all) enum ReportFormat {
  ReportText
  ReportJson
}

///|
pub fn ReportFormat::label(self : ReportFormat) -> String {
  match self {
    ReportText => "text"
    ReportJson => "json"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WavReport {
  ok : Bool
  title : String
  encoding : String
  channels : Int32
  sample_rate : Int32
  bits_per_sample : Int32
  duration_seconds : Double
  frame_count : Int32
  chunk_count : Int32
  peak : Double
  rms : Double
  quality : String
  error_code : String
}

///|
pub fn WavReport::empty() -> WavReport {
  {
    ok: false,
    title: "MoonWavKit report",
    encoding: "",
    channels: 0,
    sample_rate: 0,
    bits_per_sample: 0,
    duration_seconds: 0.0,
    frame_count: 0,
    chunk_count: 0,
    peak: 0.0,
    rms: 0.0,
    quality: "empty",
    error_code: "",
  }
}

///|
pub fn WavReport::failure(error_code : String) -> WavReport {
  {
    ok: false,
    title: "MoonWavKit report",
    encoding: "",
    channels: 0,
    sample_rate: 0,
    bits_per_sample: 0,
    duration_seconds: 0.0,
    frame_count: 0,
    chunk_count: 0,
    peak: 0.0,
    rms: 0.0,
    quality: "failed",
    error_code,
  }
}

///|
pub fn build_report(bytes : Array[Int32]) -> WavReport {
  let parsed = parse_wav(bytes)
  if !parsed.ok {
    WavReport::failure(parsed.error.code())
  } else {
    let decoded = decode_pcm(bytes, parsed.wav)
    if !decoded.ok {
      WavReport::failure(decoded.error.code())
    } else {
      let stats = analyze_audio(decoded.float_buffer)
      {
        ok: true,
        title: "MoonWavKit report",
        encoding: parsed.wav.format.encoding.label(),
        channels: parsed.wav.format.channels,
        sample_rate: parsed.wav.format.sample_rate,
        bits_per_sample: parsed.wav.format.bits_per_sample,
        duration_seconds: stats.duration_seconds,
        frame_count: stats.frame_count,
        chunk_count: parsed.wav.chunks.length(),
        peak: stats.peak,
        rms: stats.rms,
        quality: stats_quality_label(stats),
        error_code: "",
      }
    }
  }
}

///|
pub fn WavReport::to_text(self : WavReport) -> String {
  if !self.ok {
    "MoonWavKit report\nstatus: FAIL\nerror: \{self.error_code}"
  } else {
    "MoonWavKit report\nstatus: PASS\nencoding: \{self.encoding}\nchannels: \{self.channels}\nsample_rate: \{self.sample_rate}\nbits_per_sample: \{self.bits_per_sample}\nframes: \{self.frame_count}\nduration_seconds: \{self.duration_seconds}\npeak: \{self.peak}\nrms: \{self.rms}\nquality: \{self.quality}"
  }
}

///|
pub fn WavReport::to_json(self : WavReport) -> String {
  if !self.ok {
    "{ \"ok\": false, \"error\": \"\{self.error_code}\" }"
  } else {
    "{ \"ok\": true, \"encoding\": \"\{self.encoding}\", \"channels\": \{self.channels}, \"sample_rate\": \{self.sample_rate}, \"bits_per_sample\": \{self.bits_per_sample}, \"frames\": \{self.frame_count}, \"quality\": \"\{self.quality}\" }"
  }
}

///|
pub fn WavReport::render(self : WavReport, format : ReportFormat) -> String {
  match format {
    ReportText => self.to_text()
    ReportJson => self.to_json()
  }
}

///|
pub fn wavinfo_fixture_report(format~ : ReportFormat = ReportText) -> String {
  build_report(fixture_pcm16_mono()).render(format)
}
