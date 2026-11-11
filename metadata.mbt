///|
#derive(Eq, @debug.Debug)
pub(all) struct InfoCatalog {
  title : String
  artist : String
  comment : String
  software : String
  raw_tags : Array[InfoTag]
}

///|
pub fn InfoCatalog::empty() -> InfoCatalog {
  { title: "", artist: "", comment: "", software: "", raw_tags: [], }
}

///|
pub fn InfoCatalog::has_metadata(self : InfoCatalog) -> Bool {
  self.raw_tags.length() > 0
}

///|
pub fn InfoCatalog::display_title(self : InfoCatalog) -> String {
  if self.title.length() > 0 {
    self.title
  } else {
    "untitled"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CueTimeline {
  count : Int32
  first_sample : Int32
  last_sample : Int32
  sample_rate : Int32
  duration_seconds : Double
  cue_points : Array[CuePoint]
}

///|
pub fn CueTimeline::empty() -> CueTimeline {
  {
    count: 0,
    first_sample: 0,
    last_sample: 0,
    sample_rate: 0,
    duration_seconds: 0.0,
    cue_points: [],
  }
}

///|
pub fn CueTimeline::is_empty(self : CueTimeline) -> Bool {
  self.count == 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct FormatSummary {
  encoding : String
  channels : Int32
  sample_rate : Int32
  bits_per_sample : Int32
  frame_count : Int32
  duration_seconds : Double
  byte_rate : Int32
  data_bytes : Int32
}

///|
pub fn FormatSummary::empty() -> FormatSummary {
  {
    encoding: "",
    channels: 0,
    sample_rate: 0,
    bits_per_sample: 0,
    frame_count: 0,
    duration_seconds: 0.0,
    byte_rate: 0,
    data_bytes: 0,
  }
}

///|
pub fn info_tag_value(wav : ParsedWav, key : String) -> String? {
  for tag in wav.info_tags {
    if tag.key == key {
      break Some(tag.value)
    }
  } nobreak {
    None
  }
}

///|
pub fn has_info_tag(wav : ParsedWav, key : String) -> Bool {
  info_tag_value(wav, key) is Some(_)
}

///|
fn tag_or_empty(wav : ParsedWav, key : String) -> String {
  match info_tag_value(wav, key) {
    Some(value) => value
    None => ""
  }
}

///|
pub fn collect_info_catalog(wav : ParsedWav) -> InfoCatalog {
  {
    title: tag_or_empty(wav, "INAM"),
    artist: tag_or_empty(wav, "IART"),
    comment: tag_or_empty(wav, "ICMT"),
    software: tag_or_empty(wav, "ISFT"),
    raw_tags: wav.info_tags,
  }
}

///|
pub fn cue_sample_offsets(wav : ParsedWav) -> Array[Int32] {
  Array::makei(wav.cue_points.length(), i => wav.cue_points[i].sample_offset)
}

///|
pub fn cue_times_seconds(wav : ParsedWav) -> Array[Double] {
  if wav.format.sample_rate <= 0 {
    []
  } else {
    Array::makei(wav.cue_points.length(), i => {
      wav.cue_points[i].sample_offset.to_double() /
      wav.format.sample_rate.to_double()
    })
  }
}

///|
pub fn collect_cue_timeline(wav : ParsedWav) -> CueTimeline {
  if wav.cue_points.length() == 0 || wav.format.sample_rate <= 0 {
    CueTimeline::empty()
  } else {
    let first = for
      point in wav.cue_points
      value = wav.cue_points[0].sample_offset {
      if point.sample_offset < value {
        continue point.sample_offset
      } else {
        continue value
      }
    } nobreak {
      value
    }
    let last = for
      point in wav.cue_points
      value = wav.cue_points[0].sample_offset {
      if point.sample_offset > value {
        continue point.sample_offset
      } else {
        continue value
      }
    } nobreak {
      value
    }
    {
      count: wav.cue_points.length(),
      first_sample: first,
      last_sample: last,
      sample_rate: wav.format.sample_rate,
      duration_seconds: (last - first).to_double() /
      wav.format.sample_rate.to_double(),
      cue_points: wav.cue_points,
    }
  }
}

///|
pub fn summarize_format(wav : ParsedWav) -> FormatSummary {
  let info = wav.info()
  {
    encoding: wav.format.encoding.label(),
    channels: wav.format.channels,
    sample_rate: wav.format.sample_rate,
    bits_per_sample: wav.format.bits_per_sample,
    frame_count: info.frame_count,
    duration_seconds: info.duration_seconds,
    byte_rate: wav.format.byte_rate,
    data_bytes: wav.data_size,
  }
}

///|
pub fn chunk_table_to_text(wav : ParsedWav) -> String {
  if wav.chunks.length() == 0 {
    "chunks: empty"
  } else {
    for chunk in wav.chunks; text = "chunks" {
      continue "\{text}\n\{chunk.id} offset=\{chunk.offset} size=\{chunk.size}"
    } nobreak {
      text
    }
  }
}

///|
pub fn cue_timeline_to_text(timeline : CueTimeline) -> String {
  if timeline.count == 0 {
    "cue timeline: empty"
  } else {
    let header = "cue timeline\ncount: \{timeline.count}\nfirst: \{timeline.first_sample}\nlast: \{timeline.last_sample}"
    for point in timeline.cue_points; text = header {
      continue "\{text}\ncue#\{point.id} sample=\{point.sample_offset}"
    } nobreak {
      text
    }
  }
}

///|
pub fn describe_wav(wav : ParsedWav) -> String {
  let summary = summarize_format(wav)
  let catalog = collect_info_catalog(wav)
  let title = catalog.display_title()
  "MoonWavKit description\ntitle: \{title}\nencoding: \{summary.encoding}\nchannels: \{summary.channels}\nsample_rate: \{summary.sample_rate}\nbits: \{summary.bits_per_sample}\nframes: \{summary.frame_count}\nduration_seconds: \{summary.duration_seconds}\nchunks: \{wav.chunks.length()}"
}

///|
pub fn parse_and_describe(bytes : Array[Int32]) -> String {
  let parsed = parse_wav(bytes)
  if !parsed.ok {
    "MoonWavKit description\nerror: \{parsed.error.code()}"
  } else {
    describe_wav(parsed.wav)
  }
}
