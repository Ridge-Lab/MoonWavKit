///|
fn near(actual : Double, expected : Double, tolerance : Double) -> Bool {
  let diff = if actual > expected {
    actual - expected
  } else {
    expected - actual
  }
  diff <= tolerance
}

///|
test "make silence and channel stats describe empty signal" {
  let buffer = @moonwavkit.make_silence(2, 48000, 16)
  assert_true(buffer.is_valid())
  assert_eq(buffer.channels, 2)
  assert_eq(buffer.frame_count(), 16)
  let stats = @moonwavkit.channel_stats(buffer)
  assert_eq(stats.length(), 2)
  assert_eq(stats[0].channel, 0)
  assert_eq(stats[0].peak, 0.0)
  assert_eq(stats[0].silent_samples, 16)
  assert_eq(stats[1].silent_samples, 16)
}

///|
test "gain and clamp preserve shape while limiting range" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-0.75, 0.0, 0.5, 1.25])
  let boosted = @moonwavkit.apply_gain(buffer, 2.0)
  assert_eq(boosted.samples[0], -1.5)
  assert_eq(boosted.samples[2], 1.0)
  let clamped = @moonwavkit.clamp_buffer(boosted)
  assert_eq(clamped.samples[0], -1.0)
  assert_eq(clamped.samples[1], 0.0)
  assert_eq(clamped.samples[2], 1.0)
  assert_eq(clamped.samples[3], 1.0)
}

///|
test "normalize peak reaches requested target" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-0.5, 0.25, 0.0, 0.5])
  let normalized = @moonwavkit.normalize_peak(buffer, target_peak=0.8)
  assert_true(normalized.ok)
  assert_true(near(normalized.gain, 1.6, 0.0001))
  assert_true(near(normalized.before_peak, 0.5, 0.0001))
  assert_true(near(normalized.after_peak, 0.8, 0.0001))
  assert_true(near(normalized.buffer.samples[0], -0.8, 0.0001))
}

///|
test "normalize rejects invalid target peak" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [0.1])
  let too_high = @moonwavkit.normalize_peak(buffer, target_peak=1.5)
  assert_false(too_high.ok)
  assert_true(too_high.error.kind == @moonwavkit.ErrorInvalidArgument)
}

///|
test "trim silence removes quiet edges and keeps requested padding" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [
    0.0, 0.0, 0.2, -0.2, 0.0, 0.0,
  ])
  let trimmed = @moonwavkit.trim_silence(buffer, threshold=0.01, keep_frames=1)
  assert_true(trimmed.ok)
  assert_eq(trimmed.start_frame, 1)
  assert_eq(trimmed.end_frame, 5)
  assert_eq(trimmed.buffer.frame_count(), 4)
  assert_eq(trimmed.removed_start_frames, 1)
  assert_eq(trimmed.removed_end_frames, 1)
}

///|
test "trim silence returns empty buffer for all silence" {
  let buffer = @moonwavkit.make_silence(1, 8000, 5)
  let trimmed = @moonwavkit.trim_silence(buffer)
  assert_true(trimmed.ok)
  assert_eq(trimmed.buffer.frame_count(), 0)
  assert_eq(trimmed.start_frame, 0)
  assert_eq(trimmed.end_frame, 0)
}

///|
test "reverse audio reverses frames but preserves channel order" {
  let buffer = @moonwavkit.FloatBuffer::new(2, 8000, [
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0,
  ])
  let reversed = @moonwavkit.reverse_audio(buffer)
  assert_eq(reversed.channels, 2)
  assert_eq(reversed.samples[0], 5.0)
  assert_eq(reversed.samples[1], 6.0)
  assert_eq(reversed.samples[2], 3.0)
  assert_eq(reversed.samples[3], 4.0)
  assert_eq(reversed.samples[4], 1.0)
  assert_eq(reversed.samples[5], 2.0)
}

///|
test "linear resampling changes frame count and preserves endpoints" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 4, [0.0, 1.0, 0.0, -1.0])
  let resampled = @moonwavkit.resample_linear(buffer, 8)
  assert_true(resampled.ok)
  assert_eq(resampled.source_sample_rate, 4)
  assert_eq(resampled.target_sample_rate, 8)
  assert_eq(resampled.target_frames, 8)
  assert_eq(resampled.buffer.samples[0], 0.0)
  assert_eq(resampled.buffer.samples[7], -1.0)
}

///|
test "resampling rejects invalid target rate" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [0.0])
  let resampled = @moonwavkit.resample_linear(buffer, 0)
  assert_false(resampled.ok)
  assert_true(resampled.error.kind == @moonwavkit.ErrorInvalidArgument)
}

///|
test "zero crossing and crest factor expose signal features" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-1.0, 1.0, -1.0, 1.0])
  assert_eq(@moonwavkit.zero_crossing_count(buffer), 3)
  assert_eq(@moonwavkit.zero_crossing_rate(buffer), 1.0)
  assert_true(near(@moonwavkit.crest_factor(buffer), 1.0, 0.0001))
}

///|
test "region scanners report silence and clipping spans" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [
    0.0, 0.0, 0.2, 1.0, 1.0, 0.0, 0.0, 0.0,
  ])
  let silence = @moonwavkit.detect_silence_sample_regions(buffer, 2)
  let clips = @moonwavkit.find_clipping_regions(buffer, min_run=2)
  assert_eq(silence.length(), 2)
  assert_eq(silence[0].start, 0)
  assert_eq(silence[0].length, 2)
  assert_eq(silence[1].start, 5)
  assert_eq(silence[1].length, 3)
  assert_eq(clips.length(), 1)
  assert_eq(clips[0].start, 3)
  assert_eq(clips[0].length, 2)
}

///|
test "encode float buffer to pcm bytes" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-1.0, 0.0, 1.0])
  let u8 = @moonwavkit.encode_float_to_pcm_bytes(buffer, @moonwavkit.PcmU8)
  let s16 = @moonwavkit.encode_float_to_pcm_bytes(buffer, @moonwavkit.PcmS16)
  let s24 = @moonwavkit.encode_float_to_pcm_bytes(buffer, @moonwavkit.PcmS24)
  assert_true(u8.ok)
  assert_true(s16.ok)
  assert_true(s24.ok)
  assert_eq(u8.bytes.length(), 3)
  assert_eq(u8.bytes[0], 1)
  assert_eq(u8.bytes[1], 128)
  assert_eq(u8.bytes[2], 255)
  assert_eq(s16.bytes.length(), 6)
  assert_eq(s24.bytes.length(), 9)
}

///|
test "build wav from float round trips through parser and decoder" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [-1.0, 0.0, 1.0])
  let wav = @moonwavkit.build_wav_from_float(
    buffer,
    encoding=@moonwavkit.PcmS16,
  )
  assert_true(wav.ok)
  let parsed = @moonwavkit.parse_wav(wav.bytes)
  assert_true(parsed.ok)
  assert_eq(parsed.wav.format.bits_per_sample, 16)
  assert_eq(parsed.wav.data_size, 6)
  let decoded = @moonwavkit.decode_pcm(wav.bytes, parsed.wav)
  assert_true(decoded.ok)
  assert_eq(decoded.float_buffer.frame_count(), 3)
  assert_true(near(decoded.float_buffer.samples[0], -0.9999, 0.001))
  assert_eq(decoded.float_buffer.samples[1], 0.0)
}

///|
test "audio fingerprint is deterministic for same buffer" {
  let buffer = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.25, -0.25, 0.5])
  let a = @moonwavkit.audio_fingerprint(buffer)
  let b = @moonwavkit.audio_fingerprint(buffer)
  assert_eq(a.frame_count, 4)
  assert_eq(a.sample_rate, 8000)
  assert_eq(a.channels, 1)
  assert_eq(a.peak_milli, 500)
  assert_eq(a.checksum, b.checksum)
}
