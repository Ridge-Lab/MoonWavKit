///|
test "quality profile accepts ordinary signal" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [
    0.0, 0.2, 0.3, 0.2, 0.0, -0.1, -0.15, -0.1, 0.0,
  ])
  let profile = @moonwavkit.inspect_audio_quality(buffer)
  assert_true(profile.ok)
  assert_eq(profile.findings.length(), 1)
  assert_true(profile.findings[0].kind == @moonwavkit.QualityOk)
  assert_eq(@moonwavkit.recommended_quality_action(profile), "ready")
  assert_true(profile.score >= 90)
}

///|
test "quality profile flags clipping" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 1.0, -1.0, 0.1])
  let profile = @moonwavkit.inspect_audio_quality(buffer)
  assert_false(profile.ok)
  assert_true(profile.has_warnings())
  assert_true(profile.findings[0].kind == @moonwavkit.QualityClipping)
  assert_eq(
    @moonwavkit.recommended_quality_action(profile),
    "reduce-gain-or-normalize",
  )
}

///|
test "quality profile flags very quiet audio" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [
    0.001, 0.002, -0.001, 0.0015, -0.002, 0.001, 0.0, 0.001,
  ])
  let profile = @moonwavkit.inspect_audio_quality(buffer)
  assert_true(profile.score < 100)
  assert_eq(@moonwavkit.recommended_quality_action(profile), "normalize-peak")
}

///|
test "quality profile text includes score and findings" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [1.0, 1.0, 1.0])
  let text = @moonwavkit.quality_profile_to_text(
    @moonwavkit.inspect_audio_quality(buffer),
  )
  assert_true(text.contains("MoonWavKit quality"))
  assert_true(text.contains("score"))
  assert_true(text.contains("clipping"))
}

///|
test "quality labels are stable" {
  assert_eq(@moonwavkit.QualityOk.label(), "ok")
  assert_eq(@moonwavkit.QualityClipping.label(), "clipping")
  assert_eq(@moonwavkit.QualityHighZeroCrossing.label(), "high-zero-crossing")
}
