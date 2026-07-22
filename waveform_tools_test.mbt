///|
fn approx(actual : Double, expected : Double, tolerance : Double) -> Bool {
  let diff = if actual >= expected {
    actual - expected
  } else {
    expected - actual
  }
  diff <= tolerance
}

///|
test "frame and second slices select stable sample ranges" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 10, [0.0, 0.1, 0.2, 0.3, 0.4])
  let frame_slice = @moonwavkit.frame_slice(buffer, 1, 3)
  assert_eq(frame_slice.frame_count(), 3)
  assert_eq(frame_slice.samples[0], 0.1)
  assert_eq(frame_slice.samples[2], 0.3)
  let second_slice = @moonwavkit.slice_seconds(buffer, 0.1, 0.2)
  assert_eq(second_slice.frame_count(), 2)
  assert_eq(second_slice.samples[0], 0.1)
  assert_eq(second_slice.samples[1], 0.2)
}

///|
test "append and pad buffers preserve format" {
  let a = @moonwavkit.FloatBuffer::new(1, 8000, [0.1, 0.2])
  let b = @moonwavkit.FloatBuffer::new(1, 8000, [0.3])
  let appended = @moonwavkit.append_buffers(a, b)
  assert_true(appended.ok)
  assert_eq(appended.buffer.frame_count(), 3)
  assert_eq(appended.buffer.samples[2], 0.3)
  let padded = @moonwavkit.pad_buffer(
    appended.buffer,
    left_frames=1,
    right_frames=2,
  )
  assert_eq(padded.frame_count(), 6)
  assert_eq(padded.samples[0], 0.0)
  assert_eq(padded.samples[1], 0.1)
  assert_eq(padded.samples[5], 0.0)
}

///|
test "mix buffers clamps combined signal" {
  let a = @moonwavkit.FloatBuffer::new(1, 8000, [0.8, -0.8, 0.2])
  let b = @moonwavkit.FloatBuffer::new(1, 8000, [0.5, -0.5, 0.2])
  let mixed = @moonwavkit.mix_buffers(a, b)
  assert_true(mixed.ok)
  assert_eq(mixed.buffer.samples[0], 1.0)
  assert_eq(mixed.buffer.samples[1], -1.0)
  assert_eq(mixed.buffer.samples[2], 0.4)
}

///|
test "loop region repeats selected frames" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.5, 1.0, 0.25])
  let looped = @moonwavkit.loop_region(buffer, 1, 2, 3)
  assert_true(looped.ok)
  assert_eq(looped.repeats, 3)
  assert_eq(looped.source_range.start_frame, 1)
  assert_eq(looped.buffer.frame_count(), 6)
  assert_eq(looped.buffer.samples[0], 0.5)
  assert_eq(looped.buffer.samples[1], 1.0)
  assert_eq(looped.buffer.samples[4], 0.5)
  assert_eq(looped.buffer.samples[5], 1.0)
}

///|
test "waveform points compute min max and rms per bucket" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-1.0, 1.0, 0.5, -0.5])
  let points = @moonwavkit.waveform_points(buffer, 2)
  assert_eq(points.length(), 2)
  assert_eq(points[0].start_frame, 0)
  assert_eq(points[0].end_frame, 2)
  assert_eq(points[0].min, -1.0)
  assert_eq(points[0].max, 1.0)
  assert_true(approx(points[0].rms, 1.0, 0.0001))
  assert_eq(points[1].min, -0.5)
  assert_eq(points[1].max, 0.5)
}

///|
test "histogram bins all samples" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-1.0, -0.5, 0.0, 0.5, 1.0])
  let hist = @moonwavkit.amplitude_histogram(buffer, 4)
  assert_true(hist.is_valid())
  assert_eq(hist.sample_count, 5)
  assert_eq(hist.bin_count, 4)
  let total = for bin in hist.bins; count = 0 {
    continue count + bin.count
  } nobreak {
    count
  }
  assert_eq(total, 5)
}

///|
test "text waveform smoke output is readable" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.5, -1.0, 1.0])
  let text = @moonwavkit.render_waveform_text(buffer, points=2, width=4)
  assert_true(text.contains("MoonWavKit waveform"))
  assert_true(text.contains("#"))
}
