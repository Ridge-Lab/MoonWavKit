///|
pub(all) struct FrameRange {
  start_frame : Int
  frame_count : Int
} derive(Eq, @debug.Debug)

///|
pub fn FrameRange::new(start_frame : Int, frame_count : Int) -> FrameRange {
  { start_frame, frame_count }
}

///|
pub fn FrameRange::end_frame(self : FrameRange) -> Int {
  self.start_frame + self.frame_count
}

///|
pub fn FrameRange::is_valid(self : FrameRange) -> Bool {
  self.start_frame >= 0 && self.frame_count >= 0
}

///|
pub(all) struct WaveformPoint {
  index : Int
  start_frame : Int
  end_frame : Int
  min : Double
  max : Double
  rms : Double
} derive(Eq, @debug.Debug)

///|
pub fn WaveformPoint::empty(index : Int) -> WaveformPoint {
  { index, start_frame: 0, end_frame: 0, min: 0.0, max: 0.0, rms: 0.0 }
}

///|
pub(all) struct AmplitudeBin {
  index : Int
  lower : Double
  upper : Double
  count : Int
} derive(Eq, @debug.Debug)

///|
pub fn AmplitudeBin::empty(index : Int) -> AmplitudeBin {
  { index, lower: 0.0, upper: 0.0, count: 0 }
}

///|
pub(all) struct AmplitudeHistogram {
  bins : Array[AmplitudeBin]
  sample_count : Int
  bin_count : Int
} derive(Eq, @debug.Debug)

///|
pub fn AmplitudeHistogram::empty() -> AmplitudeHistogram {
  { bins: [], sample_count: 0, bin_count: 0 }
}

///|
pub fn AmplitudeHistogram::is_valid(self : AmplitudeHistogram) -> Bool {
  self.bin_count == self.bins.length() && self.sample_count >= 0
}

///|
pub(all) struct BufferMixResult {
  ok : Bool
  mixed_frames : Int
  buffer : FloatBuffer
  error : WavError
} derive(Eq, @debug.Debug)

///|
pub fn BufferMixResult::failure(error : WavError) -> BufferMixResult {
  { ok: false, mixed_frames: 0, buffer: FloatBuffer::empty(), error }
}

///|
pub fn BufferMixResult::success(buffer : FloatBuffer) -> BufferMixResult {
  {
    ok: true,
    mixed_frames: buffer.frame_count(),
    buffer,
    error: WavError::none(),
  }
}

///|
pub(all) struct LoopResult {
  ok : Bool
  repeats : Int
  source_range : FrameRange
  buffer : FloatBuffer
  error : WavError
} derive(Eq, @debug.Debug)

///|
pub fn LoopResult::failure(error : WavError) -> LoopResult {
  {
    ok: false,
    repeats: 0,
    source_range: FrameRange::new(0, 0),
    buffer: FloatBuffer::empty(),
    error,
  }
}

///|
pub fn LoopResult::success(
  repeats : Int,
  source_range : FrameRange,
  buffer : FloatBuffer,
) -> LoopResult {
  { ok: true, repeats, source_range, buffer, error: WavError::none() }
}

///|
fn compatible_format(a : FloatBuffer, b : FloatBuffer) -> Bool {
  a.is_valid() &&
  b.is_valid() &&
  a.channels == b.channels &&
  a.sample_rate == b.sample_rate
}

///|
fn frame_range_in_buffer(buffer : FloatBuffer, range : FrameRange) -> Bool {
  range.is_valid() && range.end_frame() <= buffer.frame_count()
}

///|
pub fn frame_slice(
  buffer : FloatBuffer,
  start_frame : Int,
  frame_count : Int,
) -> FloatBuffer {
  let range = FrameRange::new(start_frame, frame_count)
  if !buffer.is_valid() || !frame_range_in_buffer(buffer, range) {
    FloatBuffer::empty()
  } else {
    FloatBuffer::new(
      buffer.channels,
      buffer.sample_rate,
      copy_frames(buffer, start_frame, start_frame + frame_count),
    )
  }
}

///|
pub fn slice_seconds(
  buffer : FloatBuffer,
  start_seconds : Double,
  duration_seconds : Double,
) -> FloatBuffer {
  if !buffer.is_valid() || start_seconds < 0.0 || duration_seconds < 0.0 {
    FloatBuffer::empty()
  } else {
    let start_frame = rounded_to_int(
      start_seconds * buffer.sample_rate.to_double(),
    )
    let requested_frames = rounded_to_int(
      duration_seconds * buffer.sample_rate.to_double(),
    )
    let available = buffer.frame_count() - start_frame
    let frames = if requested_frames < available {
      requested_frames
    } else {
      available
    }
    if frames < 0 {
      FloatBuffer::empty()
    } else {
      frame_slice(buffer, start_frame, frames)
    }
  }
}

///|
pub fn append_buffers(a : FloatBuffer, b : FloatBuffer) -> BufferMixResult {
  if !compatible_format(a, b) {
    BufferMixResult::failure(
      WavError::new(
        ErrorInvalidArgument,
        "buffers must share channels and sample rate",
      ),
    )
  } else {
    let samples : Array[Double] = []
    for sample in a.samples {
      samples.push(sample)
    }
    for sample in b.samples {
      samples.push(sample)
    }
    BufferMixResult::success(
      FloatBuffer::new(a.channels, a.sample_rate, samples),
    )
  }
}

///|
pub fn pad_buffer(
  buffer : FloatBuffer,
  left_frames? : Int = 0,
  right_frames? : Int = 0,
) -> FloatBuffer {
  if !buffer.is_valid() || left_frames < 0 || right_frames < 0 {
    FloatBuffer::empty()
  } else {
    let total = (left_frames + buffer.frame_count() + right_frames) *
      buffer.channels
    let source_start = left_frames * buffer.channels
    let samples = Array::makei(total, i => {
      if i < source_start || i >= source_start + buffer.samples.length() {
        0.0
      } else {
        buffer.samples[i - source_start]
      }
    })
    FloatBuffer::new(buffer.channels, buffer.sample_rate, samples)
  }
}

///|
pub fn mix_buffers(
  a : FloatBuffer,
  b : FloatBuffer,
  gain_a? : Double = 1.0,
  gain_b? : Double = 1.0,
) -> BufferMixResult {
  if !compatible_format(a, b) {
    BufferMixResult::failure(
      WavError::new(
        ErrorInvalidArgument,
        "buffers must share channels and sample rate",
      ),
    )
  } else {
    let sample_count = if a.samples.length() < b.samples.length() {
      a.samples.length()
    } else {
      b.samples.length()
    }
    let samples = Array::makei(sample_count, i => {
      clamp_range(a.samples[i] * gain_a + b.samples[i] * gain_b, -1.0, 1.0)
    })
    BufferMixResult::success(
      FloatBuffer::new(a.channels, a.sample_rate, samples),
    )
  }
}

///|
pub fn loop_region(
  buffer : FloatBuffer,
  start_frame : Int,
  frame_count : Int,
  repeats : Int,
) -> LoopResult {
  let range = FrameRange::new(start_frame, frame_count)
  if !buffer.is_valid() || repeats <= 0 || !frame_range_in_buffer(buffer, range) {
    LoopResult::failure(
      WavError::new(ErrorInvalidArgument, "invalid loop range"),
    )
  } else {
    let slice = frame_slice(buffer, start_frame, frame_count)
    let samples : Array[Double] = []
    for _ in 0..<repeats {
      for sample in slice.samples {
        samples.push(sample)
      }
    }
    LoopResult::success(
      repeats,
      range,
      FloatBuffer::new(buffer.channels, buffer.sample_rate, samples),
    )
  }
}

///|
pub fn waveform_points(
  buffer : FloatBuffer,
  points : Int,
) -> Array[WaveformPoint] {
  if !buffer.is_valid() || points <= 0 || buffer.frame_count() == 0 {
    []
  } else {
    let frames = buffer.frame_count()
    let safe_points = if points > frames { frames } else { points }
    Array::makei(safe_points, point => {
      let start = point * frames / safe_points
      let end = (point + 1) * frames / safe_points
      let real_end = if end <= start { start + 1 } else { end }
      let first = buffer.samples[start * buffer.channels]
      let min_value = for
        i in (start * buffer.channels)..<(real_end * buffer.channels)
        value = first {
        continue min_double(value, buffer.samples[i])
      } nobreak {
        value
      }
      let max_value = for
        i in (start * buffer.channels)..<(real_end * buffer.channels)
        value = first {
        continue max_double(value, buffer.samples[i])
      } nobreak {
        value
      }
      let sum_sq = for
        i in (start * buffer.channels)..<(real_end * buffer.channels)
        value = 0.0 {
        let sample = buffer.samples[i]
        continue value + sample * sample
      } nobreak {
        value
      }
      let count = (real_end - start) * buffer.channels
      {
        index: point,
        start_frame: start,
        end_frame: real_end,
        min: min_value,
        max: max_value,
        rms: (sum_sq / count.to_double()).sqrt(),
      }
    })
  }
}

///|
fn histogram_index(value : Double, bins : Int) -> Int {
  let normalized = (clamp_range(value, -1.0, 1.0) + 1.0) / 2.0
  let raw = (normalized * bins.to_double()).floor().to_int()
  if raw < 0 {
    0
  } else if raw >= bins {
    bins - 1
  } else {
    raw
  }
}

///|
pub fn amplitude_histogram(
  buffer : FloatBuffer,
  bins : Int,
) -> AmplitudeHistogram {
  if !buffer.is_valid() || bins <= 0 {
    AmplitudeHistogram::empty()
  } else {
    let counts = Array::makei(bins, _ => 0)
    for sample in buffer.samples {
      let index = histogram_index(sample, bins)
      counts[index] = counts[index] + 1
    }
    let items = Array::makei(bins, index => {
      let lower = -1.0 + 2.0 * index.to_double() / bins.to_double()
      let upper = -1.0 + 2.0 * (index + 1).to_double() / bins.to_double()
      { index, lower, upper, count: counts[index] }
    })
    { bins: items, sample_count: buffer.samples.length(), bin_count: bins }
  }
}

///|
fn bar_for_peak(value : Double, width : Int) -> String {
  let filled = rounded_to_int(clamp_range(value, 0.0, 1.0) * width.to_double())
  for i in 0..<width; text = "" {
    if i < filled {
      continue text + "#"
    } else {
      continue text + "."
    }
  } nobreak {
    text
  }
}

///|
pub fn render_waveform_text(
  buffer : FloatBuffer,
  points? : Int = 16,
  width? : Int = 12,
) -> String {
  if !buffer.is_valid() || points <= 0 || width <= 0 {
    "MoonWavKit waveform: empty"
  } else {
    let pts = waveform_points(buffer, points)
    for point in pts; text = "MoonWavKit waveform" {
      let peak = max_double(abs_double(point.min), abs_double(point.max))
      continue "\{text}\n\{point.index}: \{bar_for_peak(peak, width)} peak=\{peak}"
    } nobreak {
      text
    }
  }
}
