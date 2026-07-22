///|
pub(all) enum PcmEncoding {
  PcmU8
  PcmS16
  PcmS24
  PcmS32
} derive(Eq, @debug.Debug)

///|
pub fn PcmEncoding::bits_per_sample(self : PcmEncoding) -> Int {
  match self {
    PcmU8 => 8
    PcmS16 => 16
    PcmS24 => 24
    PcmS32 => 32
  }
}

///|
pub fn PcmEncoding::label(self : PcmEncoding) -> String {
  match self {
    PcmU8 => "pcm-u8"
    PcmS16 => "pcm-s16"
    PcmS24 => "pcm-s24"
    PcmS32 => "pcm-s32"
  }
}

///|
pub(all) struct SampleRegion {
  start : Int
  length : Int
  threshold : Double
} derive(Eq, @debug.Debug)

///|
pub fn SampleRegion::new(
  start : Int,
  length : Int,
  threshold? : Double = 0.0,
) -> SampleRegion {
  { start, length, threshold }
}

///|
pub fn SampleRegion::end_exclusive(self : SampleRegion) -> Int {
  self.start + self.length
}

///|
pub fn SampleRegion::is_valid(self : SampleRegion) -> Bool {
  self.start >= 0 && self.length >= 0
}

///|
pub(all) struct ChannelStats {
  channel : Int
  peak : Double
  rms : Double
  average : Double
  silent_samples : Int
  clipped_samples : Int
} derive(Eq, @debug.Debug)

///|
pub fn ChannelStats::empty(channel : Int) -> ChannelStats {
  {
    channel,
    peak: 0.0,
    rms: 0.0,
    average: 0.0,
    silent_samples: 0,
    clipped_samples: 0,
  }
}

///|
pub(all) struct NormalizeReport {
  ok : Bool
  gain : Double
  target_peak : Double
  before_peak : Double
  after_peak : Double
  buffer : FloatBuffer
  error : WavError
} derive(Eq, @debug.Debug)

///|
pub fn NormalizeReport::failure(error : WavError) -> NormalizeReport {
  {
    ok: false,
    gain: 0.0,
    target_peak: 0.0,
    before_peak: 0.0,
    after_peak: 0.0,
    buffer: FloatBuffer::empty(),
    error,
  }
}

///|
pub fn NormalizeReport::success(
  gain : Double,
  target_peak : Double,
  before_peak : Double,
  buffer : FloatBuffer,
) -> NormalizeReport {
  let stats = analyze_audio(buffer)
  {
    ok: true,
    gain,
    target_peak,
    before_peak,
    after_peak: stats.peak,
    buffer,
    error: WavError::none(),
  }
}

///|
pub(all) struct TrimResult {
  ok : Bool
  start_frame : Int
  end_frame : Int
  removed_start_frames : Int
  removed_end_frames : Int
  buffer : FloatBuffer
  error : WavError
} derive(Eq, @debug.Debug)

///|
pub fn TrimResult::failure(error : WavError) -> TrimResult {
  {
    ok: false,
    start_frame: 0,
    end_frame: 0,
    removed_start_frames: 0,
    removed_end_frames: 0,
    buffer: FloatBuffer::empty(),
    error,
  }
}

///|
pub fn TrimResult::success(
  start_frame : Int,
  end_frame : Int,
  source_frames : Int,
  buffer : FloatBuffer,
) -> TrimResult {
  {
    ok: true,
    start_frame,
    end_frame,
    removed_start_frames: start_frame,
    removed_end_frames: source_frames - end_frame,
    buffer,
    error: WavError::none(),
  }
}

///|
pub(all) struct ResampleResult {
  ok : Bool
  source_sample_rate : Int
  target_sample_rate : Int
  source_frames : Int
  target_frames : Int
  buffer : FloatBuffer
  error : WavError
} derive(Eq, @debug.Debug)

///|
pub fn ResampleResult::failure(error : WavError) -> ResampleResult {
  {
    ok: false,
    source_sample_rate: 0,
    target_sample_rate: 0,
    source_frames: 0,
    target_frames: 0,
    buffer: FloatBuffer::empty(),
    error,
  }
}

///|
pub fn ResampleResult::success(
  source_sample_rate : Int,
  target_sample_rate : Int,
  source_frames : Int,
  buffer : FloatBuffer,
) -> ResampleResult {
  {
    ok: true,
    source_sample_rate,
    target_sample_rate,
    source_frames,
    target_frames: buffer.frame_count(),
    buffer,
    error: WavError::none(),
  }
}

///|
pub(all) struct ByteEncodeResult {
  ok : Bool
  encoding : PcmEncoding
  bytes : Array[Int]
  error : WavError
} derive(Eq, @debug.Debug)

///|
pub fn ByteEncodeResult::failure(
  encoding : PcmEncoding,
  error : WavError,
) -> ByteEncodeResult {
  { ok: false, encoding, bytes: [], error }
}

///|
pub fn ByteEncodeResult::success(
  encoding : PcmEncoding,
  bytes : Array[Int],
) -> ByteEncodeResult {
  { ok: true, encoding, bytes, error: WavError::none() }
}

///|
pub(all) struct AudioFingerprint {
  frame_count : Int
  sample_rate : Int
  channels : Int
  peak_milli : Int
  rms_milli : Int
  zero_crossings : Int
  checksum : Int
} derive(Eq, @debug.Debug)

///|
pub fn AudioFingerprint::empty() -> AudioFingerprint {
  {
    frame_count: 0,
    sample_rate: 0,
    channels: 0,
    peak_milli: 0,
    rms_milli: 0,
    zero_crossings: 0,
    checksum: 0,
  }
}

///|
fn clamp_range(value : Double, low : Double, high : Double) -> Double {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn rounded_to_int(value : Double) -> Int {
  value.round().to_int()
}

///|
fn sample_frame_has_signal(
  buffer : FloatBuffer,
  frame : Int,
  threshold : Double,
) -> Bool {
  for channel in 0..<buffer.channels {
    let value = buffer.samples[frame * buffer.channels + channel]
    if abs_double(value) > threshold {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn copy_frames(
  buffer : FloatBuffer,
  start_frame : Int,
  end_frame : Int,
) -> Array[Double] {
  let frame_count = if end_frame > start_frame {
    end_frame - start_frame
  } else {
    0
  }
  Array::makei(frame_count * buffer.channels, i => {
    let source = start_frame * buffer.channels + i
    buffer.samples[source]
  })
}

///|
pub fn make_silence(
  channels : Int,
  sample_rate : Int,
  frames : Int,
) -> FloatBuffer {
  if channels <= 0 || sample_rate <= 0 || frames < 0 {
    FloatBuffer::empty()
  } else {
    FloatBuffer::new(
      channels,
      sample_rate,
      Array::makei(channels * frames, _ => 0.0),
    )
  }
}

///|
pub fn apply_gain(buffer : FloatBuffer, gain : Double) -> FloatBuffer {
  if !buffer.is_valid() {
    FloatBuffer::empty()
  } else {
    FloatBuffer::new(
      buffer.channels,
      buffer.sample_rate,
      Array::makei(buffer.samples.length(), i => buffer.samples[i] * gain),
    )
  }
}

///|
pub fn clamp_buffer(buffer : FloatBuffer) -> FloatBuffer {
  if !buffer.is_valid() {
    FloatBuffer::empty()
  } else {
    FloatBuffer::new(
      buffer.channels,
      buffer.sample_rate,
      Array::makei(buffer.samples.length(), i => {
        clamp_range(buffer.samples[i], -1.0, 1.0)
      }),
    )
  }
}

///|
pub fn normalize_peak(
  buffer : FloatBuffer,
  target_peak? : Double = 0.95,
) -> NormalizeReport {
  if !buffer.is_valid() {
    NormalizeReport::failure(
      WavError::new(ErrorInvalidArgument, "invalid float buffer"),
    )
  } else if target_peak <= 0.0 || target_peak > 1.0 {
    NormalizeReport::failure(
      WavError::new(ErrorInvalidArgument, "target peak must be in 0..1"),
    )
  } else {
    let stats = analyze_audio(buffer)
    if stats.peak <= 0.0 {
      NormalizeReport::success(1.0, target_peak, stats.peak, buffer)
    } else {
      let gain = target_peak / stats.peak
      NormalizeReport::success(
        gain,
        target_peak,
        stats.peak,
        clamp_buffer(apply_gain(buffer, gain)),
      )
    }
  }
}

///|
pub fn trim_silence(
  buffer : FloatBuffer,
  threshold? : Double = 0.0001,
  keep_frames? : Int = 0,
) -> TrimResult {
  if !buffer.is_valid() {
    TrimResult::failure(
      WavError::new(ErrorInvalidArgument, "invalid float buffer"),
    )
  } else if threshold < 0.0 || keep_frames < 0 {
    TrimResult::failure(
      WavError::new(ErrorInvalidArgument, "invalid trim options"),
    )
  } else {
    let frames = buffer.frame_count()
    let first_signal = for frame in 0..<frames {
      if sample_frame_has_signal(buffer, frame, threshold) {
        break frame
      }
    } nobreak {
      frames
    }
    if first_signal == frames {
      TrimResult::success(
        0,
        0,
        frames,
        FloatBuffer::new(buffer.channels, buffer.sample_rate, []),
      )
    } else {
      let last_signal = for frame = frames - 1; frame >= 0; {
        if sample_frame_has_signal(buffer, frame, threshold) {
          break frame
        }
        continue frame - 1
      } nobreak {
        first_signal
      }
      let start_frame = if first_signal > keep_frames {
        first_signal - keep_frames
      } else {
        0
      }
      let end_frame = if last_signal + 1 + keep_frames < frames {
        last_signal + 1 + keep_frames
      } else {
        frames
      }
      let samples = copy_frames(buffer, start_frame, end_frame)
      TrimResult::success(
        start_frame,
        end_frame,
        frames,
        FloatBuffer::new(buffer.channels, buffer.sample_rate, samples),
      )
    }
  }
}

///|
pub fn reverse_audio(buffer : FloatBuffer) -> FloatBuffer {
  if !buffer.is_valid() {
    FloatBuffer::empty()
  } else {
    let frames = buffer.frame_count()
    let samples = Array::makei(buffer.samples.length(), i => {
      let target_frame = i / buffer.channels
      let channel = i % buffer.channels
      let source_frame = frames - 1 - target_frame
      buffer.samples[source_frame * buffer.channels + channel]
    })
    FloatBuffer::new(buffer.channels, buffer.sample_rate, samples)
  }
}

///|
fn interpolate_channel(
  buffer : FloatBuffer,
  position : Double,
  channel : Int,
) -> Double {
  let frames = buffer.frame_count()
  if frames == 0 {
    0.0
  } else {
    let left = position.floor().to_int()
    let right = if left + 1 < frames { left + 1 } else { left }
    let weight = position - left.to_double()
    let left_value = buffer.samples[left * buffer.channels + channel]
    let right_value = buffer.samples[right * buffer.channels + channel]
    left_value * (1.0 - weight) + right_value * weight
  }
}

///|
pub fn resample_linear(
  buffer : FloatBuffer,
  target_sample_rate : Int,
) -> ResampleResult {
  if !buffer.is_valid() {
    ResampleResult::failure(
      WavError::new(ErrorInvalidArgument, "invalid float buffer"),
    )
  } else if target_sample_rate <= 0 {
    ResampleResult::failure(
      WavError::new(ErrorInvalidArgument, "target sample rate must be positive"),
    )
  } else if target_sample_rate == buffer.sample_rate {
    ResampleResult::success(
      buffer.sample_rate,
      target_sample_rate,
      buffer.frame_count(),
      buffer,
    )
  } else {
    let source_frames = buffer.frame_count()
    let target_frames = rounded_to_int(
      source_frames.to_double() *
      target_sample_rate.to_double() /
      buffer.sample_rate.to_double(),
    )
    let safe_target_frames = if target_frames < 1 { 1 } else { target_frames }
    let samples = Array::makei(safe_target_frames * buffer.channels, i => {
      let frame = i / buffer.channels
      let channel = i % buffer.channels
      let source_position = if safe_target_frames == 1 {
        0.0
      } else {
        frame.to_double() *
        (source_frames - 1).to_double() /
        (safe_target_frames - 1).to_double()
      }
      interpolate_channel(buffer, source_position, channel)
    })
    ResampleResult::success(
      buffer.sample_rate,
      target_sample_rate,
      source_frames,
      FloatBuffer::new(buffer.channels, target_sample_rate, samples),
    )
  }
}

///|
pub fn channel_stats(
  buffer : FloatBuffer,
  silence_threshold? : Double = 0.0001,
  clip_threshold? : Double = 0.999,
) -> Array[ChannelStats] {
  if !buffer.is_valid() {
    []
  } else {
    Array::makei(buffer.channels, channel => {
      let frames = buffer.frame_count()
      let peak = for frame in 0..<frames; value = 0.0 {
        continue max_double(
            value,
            abs_double(buffer.samples[frame * buffer.channels + channel]),
          )
      } nobreak {
        value
      }
      let sum = for frame in 0..<frames; value = 0.0 {
        continue value + buffer.samples[frame * buffer.channels + channel]
      } nobreak {
        value
      }
      let sum_sq = for frame in 0..<frames; value = 0.0 {
        let sample = buffer.samples[frame * buffer.channels + channel]
        continue value + sample * sample
      } nobreak {
        value
      }
      let silent = for frame in 0..<frames; count = 0 {
        let sample = buffer.samples[frame * buffer.channels + channel]
        if abs_double(sample) <= silence_threshold {
          continue count + 1
        } else {
          continue count
        }
      } nobreak {
        count
      }
      let clipped = for frame in 0..<frames; count = 0 {
        let sample = buffer.samples[frame * buffer.channels + channel]
        if abs_double(sample) >= clip_threshold {
          continue count + 1
        } else {
          continue count
        }
      } nobreak {
        count
      }
      {
        channel,
        peak,
        rms: (sum_sq / frames.to_double()).sqrt(),
        average: sum / frames.to_double(),
        silent_samples: silent,
        clipped_samples: clipped,
      }
    })
  }
}

///|
pub fn zero_crossing_count(buffer : FloatBuffer) -> Int {
  if !buffer.is_valid() || buffer.samples.length() <= buffer.channels {
    0
  } else {
    let mono = if buffer.channels == 1 {
      buffer
    } else {
      downmix_to_mono(buffer)
    }
    for i in 1..<mono.samples.length(); count = 0 {
      let prev = mono.samples[i - 1]
      let current = mono.samples[i]
      if (prev < 0.0 && current >= 0.0) || (prev >= 0.0 && current < 0.0) {
        continue count + 1
      } else {
        continue count
      }
    } nobreak {
      count
    }
  }
}

///|
pub fn zero_crossing_rate(buffer : FloatBuffer) -> Double {
  let frames = buffer.frame_count()
  if frames <= 1 {
    0.0
  } else {
    zero_crossing_count(buffer).to_double() / (frames - 1).to_double()
  }
}

///|
pub fn crest_factor(buffer : FloatBuffer) -> Double {
  let stats = analyze_audio(buffer)
  if stats.rms <= 0.0 {
    0.0
  } else {
    stats.peak / stats.rms
  }
}

///|
fn region_scan(
  samples : Array[Double],
  threshold : Double,
  min_run : Int,
  want_above : Bool,
) -> Array[SampleRegion] {
  let regions : Array[SampleRegion] = []
  let mut start = -1
  for i in 0..<samples.length() {
    let hit = if want_above {
      abs_double(samples[i]) >= threshold
    } else {
      abs_double(samples[i]) <= threshold
    }
    if hit && start < 0 {
      start = i
    } else if !hit && start >= 0 {
      let length = i - start
      if length >= min_run {
        regions.push(SampleRegion::new(start, length, threshold~))
      }
      start = -1
    }
  }
  if start >= 0 {
    let length = samples.length() - start
    if length >= min_run {
      regions.push(SampleRegion::new(start, length, threshold~))
    }
  }
  regions
}

///|
pub fn detect_silence_sample_regions(
  buffer : FloatBuffer,
  min_run : Int,
  threshold? : Double = 0.0001,
) -> Array[SampleRegion] {
  if !buffer.is_valid() || min_run <= 0 || threshold < 0.0 {
    []
  } else {
    region_scan(buffer.samples, threshold, min_run, false)
  }
}

///|
pub fn find_clipping_regions(
  buffer : FloatBuffer,
  min_run? : Int = 1,
  threshold? : Double = 0.999,
) -> Array[SampleRegion] {
  if !buffer.is_valid() || min_run <= 0 || threshold <= 0.0 {
    []
  } else {
    region_scan(buffer.samples, threshold, min_run, true)
  }
}

///|
fn encode_sample_to_int(sample : Double, encoding : PcmEncoding) -> Int {
  let clamped = clamp_range(sample, -1.0, 1.0)
  match encoding {
    PcmU8 => rounded_to_int(clamped * 127.0 + 128.0)
    PcmS16 => rounded_to_int(clamped * 32767.0)
    PcmS24 => rounded_to_int(clamped * 8388607.0)
    PcmS32 => rounded_to_int(clamped * 2147483647.0)
  }
}

///|
fn push_u16_le(out : Array[Int], value : Int) -> Unit {
  out.push(value & 0xff)
  out.push((value >> 8) & 0xff)
}

///|
fn push_u32_le(out : Array[Int], value : Int) -> Unit {
  out.push(value & 0xff)
  out.push((value >> 8) & 0xff)
  out.push((value >> 16) & 0xff)
  out.push((value >> 24) & 0xff)
}

///|
fn push_pcm_sample(
  out : Array[Int],
  sample : Double,
  encoding : PcmEncoding,
) -> Unit {
  let value = encode_sample_to_int(sample, encoding)
  match encoding {
    PcmU8 => out.push(value & 0xff)
    PcmS16 => {
      out.push(value & 0xff)
      out.push((value >> 8) & 0xff)
    }
    PcmS24 => {
      out.push(value & 0xff)
      out.push((value >> 8) & 0xff)
      out.push((value >> 16) & 0xff)
    }
    PcmS32 => {
      out.push(value & 0xff)
      out.push((value >> 8) & 0xff)
      out.push((value >> 16) & 0xff)
      out.push((value >> 24) & 0xff)
    }
  }
}

///|
pub fn encode_float_to_pcm_bytes(
  buffer : FloatBuffer,
  encoding : PcmEncoding,
) -> ByteEncodeResult {
  if !buffer.is_valid() {
    ByteEncodeResult::failure(
      encoding,
      WavError::new(ErrorInvalidArgument, "invalid float buffer"),
    )
  } else {
    let out : Array[Int] = []
    for sample in buffer.samples {
      push_pcm_sample(out, sample, encoding)
    }
    ByteEncodeResult::success(encoding, out)
  }
}

///|
pub fn build_wav_from_float(
  buffer : FloatBuffer,
  encoding? : PcmEncoding = PcmS16,
) -> ByteEncodeResult {
  let encoded = encode_float_to_pcm_bytes(buffer, encoding)
  if !encoded.ok {
    encoded
  } else {
    let bits = encoding.bits_per_sample()
    let block_align = buffer.channels * bits / 8
    let byte_rate = buffer.sample_rate * block_align
    let data_size = encoded.bytes.length()
    let riff_size = 4 + 8 + 16 + 8 + data_size
    let out : Array[Int] = []
    out.push(82)
    out.push(73)
    out.push(70)
    out.push(70)
    push_u32_le(out, riff_size)
    out.push(87)
    out.push(65)
    out.push(86)
    out.push(69)
    out.push(102)
    out.push(109)
    out.push(116)
    out.push(32)
    push_u32_le(out, 16)
    push_u16_le(out, 1)
    push_u16_le(out, buffer.channels)
    push_u32_le(out, buffer.sample_rate)
    push_u32_le(out, byte_rate)
    push_u16_le(out, block_align)
    push_u16_le(out, bits)
    out.push(100)
    out.push(97)
    out.push(116)
    out.push(97)
    push_u32_le(out, data_size)
    for byte in encoded.bytes {
      out.push(byte)
    }
    if data_size % 2 != 0 {
      out.push(0)
    }
    ByteEncodeResult::success(encoding, out)
  }
}

///|
pub fn audio_fingerprint(buffer : FloatBuffer) -> AudioFingerprint {
  if !buffer.is_valid() {
    AudioFingerprint::empty()
  } else {
    let stats = analyze_audio(buffer)
    let checksum = for sample in buffer.samples; value = 17 {
      let milli = rounded_to_int(clamp_range(sample, -1.0, 1.0) * 1000.0)
      continue (value * 31 + milli) & 0x7fffffff
    } nobreak {
      value
    }
    {
      frame_count: buffer.frame_count(),
      sample_rate: buffer.sample_rate,
      channels: buffer.channels,
      peak_milli: rounded_to_int(stats.peak * 1000.0),
      rms_milli: rounded_to_int(stats.rms * 1000.0),
      zero_crossings: zero_crossing_count(buffer),
      checksum,
    }
  }
}
