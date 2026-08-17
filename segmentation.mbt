///|
pub(all) enum AudioRegionKind {
  RegionSilence
  RegionQuiet
  RegionSignal
  RegionLoud
  RegionClipping
} derive(Eq, @debug.Debug)

///|
pub fn AudioRegionKind::label(self : AudioRegionKind) -> String {
  match self {
    RegionSilence => "silence"
    RegionQuiet => "quiet"
    RegionSignal => "signal"
    RegionLoud => "loud"
    RegionClipping => "clipping"
  }
}

///|
pub fn AudioRegionKind::is_problem(self : AudioRegionKind) -> Bool {
  match self {
    RegionClipping => true
    _ => false
  }
}

///|
pub(all) struct AudioRegion {
  kind : AudioRegionKind
  start_frame : Int
  frame_count : Int
  channels : Int
  sample_rate : Int
  peak : Double
  rms : Double
} derive(Eq, @debug.Debug)

///|
pub fn AudioRegion::empty(kind : AudioRegionKind) -> AudioRegion {
  {
    kind,
    start_frame: 0,
    frame_count: 0,
    channels: 0,
    sample_rate: 0,
    peak: 0.0,
    rms: 0.0,
  }
}

///|
pub fn AudioRegion::end_frame(self : AudioRegion) -> Int {
  self.start_frame + self.frame_count
}

///|
pub fn AudioRegion::duration_seconds(self : AudioRegion) -> Double {
  if self.sample_rate <= 0 {
    0.0
  } else {
    self.frame_count.to_double() / self.sample_rate.to_double()
  }
}

///|
pub fn AudioRegion::is_valid(self : AudioRegion) -> Bool {
  self.start_frame >= 0 &&
  self.frame_count >= 0 &&
  self.channels > 0 &&
  self.sample_rate > 0
}

///|
pub fn AudioRegion::contains_frame(self : AudioRegion, frame : Int) -> Bool {
  frame >= self.start_frame && frame < self.end_frame()
}

///|
pub(all) struct AudioSegmentOptions {
  silence_threshold : Double
  quiet_threshold : Double
  loud_threshold : Double
  clipping_threshold : Double
  min_region_frames : Int
} derive(Eq, @debug.Debug)

///|
pub fn AudioSegmentOptions::default() -> AudioSegmentOptions {
  {
    silence_threshold: 0.0001,
    quiet_threshold: 0.02,
    loud_threshold: 0.8,
    clipping_threshold: 0.999,
    min_region_frames: 1,
  }
}

///|
pub fn AudioSegmentOptions::game_asset() -> AudioSegmentOptions {
  {
    silence_threshold: 0.001,
    quiet_threshold: 0.03,
    loud_threshold: 0.85,
    clipping_threshold: 0.995,
    min_region_frames: 2,
  }
}

///|
pub fn AudioSegmentOptions::with_min_region_frames(
  self : AudioSegmentOptions,
  min_region_frames : Int,
) -> AudioSegmentOptions {
  {
    silence_threshold: self.silence_threshold,
    quiet_threshold: self.quiet_threshold,
    loud_threshold: self.loud_threshold,
    clipping_threshold: self.clipping_threshold,
    min_region_frames,
  }
}

///|
pub(all) struct AudioSegmentation {
  ok : Bool
  regions : Array[AudioRegion]
  source_frames : Int
  channels : Int
  sample_rate : Int
} derive(Eq, @debug.Debug)

///|
pub fn AudioSegmentation::empty() -> AudioSegmentation {
  { ok: false, regions: [], source_frames: 0, channels: 0, sample_rate: 0 }
}

///|
pub fn AudioSegmentation::region_count(self : AudioSegmentation) -> Int {
  self.regions.length()
}

///|
pub fn AudioSegmentation::problem_count(self : AudioSegmentation) -> Int {
  for region in self.regions; count = 0 {
    if region.kind.is_problem() {
      continue count + 1
    } else {
      continue count
    }
  } nobreak {
    count
  }
}

///|
pub fn AudioSegmentation::frames_for_kind(
  self : AudioSegmentation,
  kind : AudioRegionKind,
) -> Int {
  for region in self.regions; frames = 0 {
    if region.kind == kind {
      continue frames + region.frame_count
    } else {
      continue frames
    }
  } nobreak {
    frames
  }
}

///|
pub fn AudioSegmentation::coverage_ratio(
  self : AudioSegmentation,
  kind : AudioRegionKind,
) -> Double {
  if self.source_frames <= 0 {
    0.0
  } else {
    self.frames_for_kind(kind).to_double() / self.source_frames.to_double()
  }
}

///|
pub fn AudioSegmentation::longest_region(
  self : AudioSegmentation,
) -> AudioRegion {
  if self.regions.length() == 0 {
    AudioRegion::empty(RegionSilence)
  } else {
    let mut best = self.regions[0]
    for region in self.regions {
      if region.frame_count > best.frame_count {
        best = region
      }
    }
    best
  }
}

///|
pub fn AudioSegmentation::longest_region_of_kind(
  self : AudioSegmentation,
  kind : AudioRegionKind,
) -> AudioRegion {
  let mut found = false
  let mut best = AudioRegion::empty(kind)
  for region in self.regions {
    if region.kind == kind && (!found || region.frame_count > best.frame_count) {
      best = region
      found = true
    }
  }
  best
}

///|
pub fn segment_audio(
  buffer : FloatBuffer,
  options? : AudioSegmentOptions = AudioSegmentOptions::default(),
) -> AudioSegmentation {
  if !buffer.is_valid() || buffer.frame_count() == 0 {
    AudioSegmentation::empty()
  } else {
    let safe_options = normalize_segment_options(options)
    let regions : Array[AudioRegion] = []
    let frames = buffer.frame_count()
    let mut start_frame = 0
    let mut current_kind = classify_audio_frame(buffer, 0, safe_options)
    for frame in 1..<frames {
      let kind = classify_audio_frame(buffer, frame, safe_options)
      if kind != current_kind {
        push_region_if_long_enough(
          regions,
          buffer,
          current_kind,
          start_frame,
          frame,
          safe_options.min_region_frames,
        )
        current_kind = kind
        start_frame = frame
      }
    }
    push_region_if_long_enough(
      regions,
      buffer,
      current_kind,
      start_frame,
      frames,
      safe_options.min_region_frames,
    )
    {
      ok: true,
      regions,
      source_frames: frames,
      channels: buffer.channels,
      sample_rate: buffer.sample_rate,
    }
  }
}

///|
pub fn silence_regions(
  buffer : FloatBuffer,
  min_region_frames? : Int = 1,
  threshold? : Double = 0.0001,
) -> Array[AudioRegion] {
  let report = segment_audio(buffer, options={
    silence_threshold: threshold,
    quiet_threshold: threshold * 2.0,
    loud_threshold: 0.8,
    clipping_threshold: 0.999,
    min_region_frames,
  })
  filter_regions_by_kind(report.regions, RegionSilence)
}

///|
pub fn clipping_regions(
  buffer : FloatBuffer,
  min_region_frames? : Int = 1,
  threshold? : Double = 0.999,
) -> Array[AudioRegion] {
  let report = segment_audio(buffer, options={
    silence_threshold: 0.0001,
    quiet_threshold: 0.02,
    loud_threshold: threshold * 0.8,
    clipping_threshold: threshold,
    min_region_frames,
  })
  filter_regions_by_kind(report.regions, RegionClipping)
}

///|
pub fn audio_segmentation_to_text(report : AudioSegmentation) -> String {
  if !report.ok {
    "MoonWavKit segmentation: empty"
  } else {
    let header = "MoonWavKit segmentation\nframes: \{report.source_frames}\nregions: \{report.region_count()}\nproblems: \{report.problem_count()}"
    for region in report.regions; text = header {
      continue "\{text}\n- \{region.kind.label()} frames=\{region.start_frame}..\{region.end_frame()} peak=\{region.peak} rms=\{region.rms}"
    } nobreak {
      text
    }
  }
}

///|
pub fn region_summary_csv(report : AudioSegmentation) -> String {
  let header = "kind,start_frame,end_frame,frame_count,peak,rms"
  for region in report.regions; text = header {
    continue "\{text}\n\{region.kind.label()},\{region.start_frame},\{region.end_frame()},\{region.frame_count},\{region.peak},\{region.rms}"
  } nobreak {
    text
  }
}

///|
fn normalize_segment_options(
  options : AudioSegmentOptions,
) -> AudioSegmentOptions {
  let silence = if options.silence_threshold < 0.0 {
    0.0
  } else {
    options.silence_threshold
  }
  let quiet = if options.quiet_threshold <= silence {
    silence + 0.001
  } else {
    options.quiet_threshold
  }
  let loud = if options.loud_threshold <= quiet {
    quiet + 0.1
  } else {
    options.loud_threshold
  }
  let clipping = if options.clipping_threshold <= loud {
    0.999
  } else {
    options.clipping_threshold
  }
  {
    silence_threshold: silence,
    quiet_threshold: quiet,
    loud_threshold: loud,
    clipping_threshold: clipping,
    min_region_frames: if options.min_region_frames <= 0 {
      1
    } else {
      options.min_region_frames
    },
  }
}

///|
fn classify_audio_frame(
  buffer : FloatBuffer,
  frame : Int,
  options : AudioSegmentOptions,
) -> AudioRegionKind {
  let peak = frame_peak(buffer, frame)
  if peak >= options.clipping_threshold {
    RegionClipping
  } else if peak <= options.silence_threshold {
    RegionSilence
  } else if peak <= options.quiet_threshold {
    RegionQuiet
  } else if peak >= options.loud_threshold {
    RegionLoud
  } else {
    RegionSignal
  }
}

///|
fn frame_peak(buffer : FloatBuffer, frame : Int) -> Double {
  for channel in 0..<buffer.channels; peak = 0.0 {
    let sample = buffer.samples[frame * buffer.channels + channel]
    continue max_double(peak, abs_double(sample))
  } nobreak {
    peak
  }
}

///|
fn push_region_if_long_enough(
  regions : Array[AudioRegion],
  buffer : FloatBuffer,
  kind : AudioRegionKind,
  start_frame : Int,
  end_frame : Int,
  min_region_frames : Int,
) -> Unit {
  let frame_count = end_frame - start_frame
  if frame_count >= min_region_frames {
    regions.push(build_audio_region(buffer, kind, start_frame, end_frame))
  }
}

///|
fn build_audio_region(
  buffer : FloatBuffer,
  kind : AudioRegionKind,
  start_frame : Int,
  end_frame : Int,
) -> AudioRegion {
  let sample_start = start_frame * buffer.channels
  let sample_end = end_frame * buffer.channels
  let sample_count = sample_end - sample_start
  if sample_count <= 0 {
    AudioRegion::empty(kind)
  } else {
    let peak = for i in sample_start..<sample_end; value = 0.0 {
      continue max_double(value, abs_double(buffer.samples[i]))
    } nobreak {
      value
    }
    let sum_sq = for i in sample_start..<sample_end; value = 0.0 {
      continue value + buffer.samples[i] * buffer.samples[i]
    } nobreak {
      value
    }
    {
      kind,
      start_frame,
      frame_count: end_frame - start_frame,
      channels: buffer.channels,
      sample_rate: buffer.sample_rate,
      peak,
      rms: (sum_sq / sample_count.to_double()).sqrt(),
    }
  }
}

///|
fn filter_regions_by_kind(
  regions : Array[AudioRegion],
  kind : AudioRegionKind,
) -> Array[AudioRegion] {
  let out : Array[AudioRegion] = []
  for region in regions {
    if region.kind == kind {
      out.push(region)
    }
  }
  out
}
