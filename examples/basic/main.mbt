///|
fn main {
  let bytes = @moonwavkit.fixture_pcm16_mono()
  let parsed = @moonwavkit.parse_wav(bytes)
  if !parsed.ok {
    println("parse failed: \{parsed.error.code()}")
  } else {
    let decoded = @moonwavkit.decode_pcm(bytes, parsed.wav)
    if !decoded.ok {
      println("decode failed: \{decoded.error.code()}")
    } else {
      let stats = @moonwavkit.analyze_audio(decoded.float_buffer)
      let summary = @moonwavkit.summarize_format(parsed.wav)
      println("MoonWavKit basic example")
      println("encoding=\{summary.encoding}")
      println("sample_rate=\{summary.sample_rate}")
      println("channels=\{summary.channels}")
      println("frames=\{summary.frame_count}")
      println("peak=\{stats.peak}")
      println("rms=\{stats.rms}")
      let quality = @moonwavkit.inspect_audio_quality(decoded.float_buffer)
      let fingerprint = @moonwavkit.audio_fingerprint(decoded.float_buffer)
      println("quality_score=\{quality.score}")
      println("fingerprint_checksum=\{fingerprint.checksum}")
      println("zero_crossings=\{fingerprint.zero_crossings}")
      let support = @moonwavkit.supported_format_matrix()
      println("support_entries=\{support.length()}")
      println("fixture_catalog_passed=\{@moonwavkit.fixture_catalog_passed()}")
    }
  }
}
