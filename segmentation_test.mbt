///|
test "segment audio classifies silence signal loud and clipping" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 10, [
    0.0, 0.0, 0.01, 0.2, 0.3, 0.9, 0.85, 1.0, -1.0,
  ])
  let report = @moonwavkit.segment_audio(buffer)
  assert_true(report.ok)
  assert_eq(report.source_frames, 9)
  assert_true(report.region_count() >= 4)
  assert_eq(report.frames_for_kind(@moonwavkit.RegionSilence), 2)
  assert_eq(report.frames_for_kind(@moonwavkit.RegionClipping), 2)
  assert_true(report.problem_count() >= 1)
}

///|
test "silence and clipping helpers return focused regions" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 10, [
    0.0, 0.0, 0.2, 0.3, 1.0, 1.0, 0.0, 0.0,
  ])
  let silent = @moonwavkit.silence_regions(buffer, min_region_frames=2)
  assert_eq(silent.length(), 2)
  assert_eq(silent[0].start_frame, 0)
  assert_eq(silent[1].start_frame, 6)
  let clipped = @moonwavkit.clipping_regions(buffer, min_region_frames=2)
  assert_eq(clipped.length(), 1)
  assert_eq(clipped[0].start_frame, 4)
  assert_eq(clipped[0].frame_count, 2)
}

///|
test "segmentation reports coverage and longest regions" {
  let buffer = @moonwavkit.FloatBuffer::new(2, 10, [
    0.0, 0.0, 0.0, 0.0, 0.4, -0.4, 0.5, -0.5, 0.6, -0.6,
  ])
  let report = @moonwavkit.segment_audio(buffer)
  assert_true(report.ok)
  let longest = report.longest_region()
  assert_eq(longest.kind, @moonwavkit.RegionSignal)
  assert_eq(longest.frame_count, 3)
  assert_true(report.coverage_ratio(@moonwavkit.RegionSilence) > 0.39)
  assert_true(longest.contains_frame(3))
  assert_true(longest.duration_seconds() > 0.29)
}

///|
test "segmentation text and csv are stable enough for cli reports" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 10, [0.0, 0.2, 1.0])
  let report = @moonwavkit.segment_audio(buffer)
  let text = @moonwavkit.audio_segmentation_to_text(report)
  assert_true(text.contains("MoonWavKit segmentation"))
  assert_true(text.contains("problems"))
  let csv = @moonwavkit.region_summary_csv(report)
  assert_true(csv.contains("kind,start_frame,end_frame"))
  assert_true(csv.contains("clipping"))
}
