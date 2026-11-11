///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a <= b {
    a
  } else {
    b
  }
}

///|
pub fn analyze_audio(buffer : FloatBuffer) -> AudioStats {
  if !buffer.is_valid() || buffer.samples.length() == 0 {
    AudioStats::empty()
  } else {
    let total = buffer.samples.length()
    let peak = for sample in buffer.samples; value = 0.0 {
      continue max_double(value, abs_double(sample))
    } nobreak {
      value
    }
    let sum = for sample in buffer.samples; value = 0.0 {
      continue value + sample
    } nobreak {
      value
    }
    let sum_sq = for sample in buffer.samples; value = 0.0 {
      continue value + sample * sample
    } nobreak {
      value
    }
    let silent = for sample in buffer.samples; count = 0 {
      if abs_double(sample) <= 0.0001 {
        continue count + 1
      } else {
        continue count
      }
    } nobreak {
      count
    }
    let clipped = for sample in buffer.samples; count = 0 {
      if abs_double(sample) >= 0.999 {
        continue count + 1
      } else {
        continue count
      }
    } nobreak {
      count
    }
    {
      duration_seconds: buffer.duration_seconds(),
      frame_count: buffer.frame_count(),
      sample_count: total,
      peak,
      rms: (sum_sq / total.to_double()).sqrt(),
      silent_samples: silent,
      clipped_samples: clipped,
      dc_offset: sum / total.to_double(),
    }
  }
}

///|
pub fn summarize_waveform(
  buffer : FloatBuffer,
  buckets : Int32,
) -> WaveformSummary {
  if !buffer.is_valid() || buckets <= 0 || buffer.samples.length() == 0 {
    WaveformSummary::empty()
  } else {
    let source_samples = buffer.samples.length()
    let safe_buckets = if buckets > source_samples {
      source_samples
    } else {
      buckets
    }
    let bucket_values = Array::makei(safe_buckets, bucket_index => {
      let start = bucket_index * source_samples / safe_buckets
      let end = (bucket_index + 1) * source_samples / safe_buckets
      let real_end = if end <= start { start + 1 } else { end }
      let min_value = for i in start..<real_end; value = buffer.samples[start] {
        continue min_double(value, buffer.samples[i])
      } nobreak {
        value
      }
      let max_value = for i in start..<real_end; value = buffer.samples[start] {
        continue max_double(value, buffer.samples[i])
      } nobreak {
        value
      }
      let abs_sum = for i in start..<real_end; value = 0.0 {
        continue value + abs_double(buffer.samples[i])
      } nobreak {
        value
      }
      {
        index: bucket_index,
        min: min_value,
        max: max_value,
        average_abs: abs_sum / (real_end - start).to_double(),
      }
    })
    { buckets: bucket_values, bucket_count: safe_buckets, source_samples, }
  }
}

///|
pub fn detect_silence_regions(
  buffer : FloatBuffer,
  min_run : Int32,
  threshold~ : Double = 0.0001,
) -> Array[WaveChunk] {
  if !buffer.is_valid() || min_run <= 0 {
    []
  } else {
    let regions : Array[WaveChunk] = []
    let mut start = -1
    for i in 0..<buffer.samples.length() {
      let silent = abs_double(buffer.samples[i]) <= threshold
      if silent && start < 0 {
        start = i
      } else if !silent && start >= 0 {
        let len = i - start
        if len >= min_run {
          regions.push(WaveChunk::new("silence", start, start, len))
        }
        start = -1
      }
    }
    if start >= 0 {
      let len = buffer.samples.length() - start
      if len >= min_run {
        regions.push(WaveChunk::new("silence", start, start, len))
      }
    }
    regions
  }
}

///|
pub fn stats_quality_label(stats : AudioStats) -> String {
  if stats.sample_count == 0 {
    "empty"
  } else if stats.has_clipping() {
    "clipped"
  } else if stats.peak < 0.02 {
    "very-quiet"
  } else if stats.silence_ratio() > 0.95 {
    "mostly-silent"
  } else {
    "ok"
  }
}
