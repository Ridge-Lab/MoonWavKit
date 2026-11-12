///|
// Each line on stdout is one complete MoonEcho fingerprint in file order.
// Analysis windows depend only on sample positions, never on input chunk sizes.
fn emit_fingerprint(samples : Array[Double]) -> Unit raise {
  let audio = @wav.FloatBuffer::new(1, 16000, samples)
  let spectrum = @spectrum.spectrogram(
    audio,
    @spectrum.SpectrumConfig::new(window_length=512, hop_size=256),
  )
  let peaks = @spectrum.extract_peaks(spectrum, @spectrum.PeakConfig::new())
  let fp = @fp.fingerprint(
    peaks,
    @fp.HashConfig::new(),
    frame_count=spectrum.magnitudes.length(),
    bin_count=spectrum.frequencies.length(),
  )
  println(@base64.encode(@fp.encode(fp)))
}

///|
async fn main {
  guard @env.args() is [_, mode, path] else {
    fail("Usage: wav-fingerprint full|stream FILE (16 kHz mono PCM)")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  guard size > 0L && size <= 2147483647L else {
    fail("Expected a WAV file of 1..2147483647 bytes")
  }
  let window = []
  fn accept(block : @wav.FloatBuffer) -> Unit raise {
    guard block.channels == 1 && block.sample_rate == 16000 else {
      fail("The comparison requires a 16 kHz mono recording")
    }
    for sample in block.samples {
      window.push(sample)
      if window.length() == 64000 {
        emit_fingerprint(window)
        window.clear()
      }
    }
  }
  match mode {
    "full" => {
      let bytes = file.read_exactly(size.to_int())
      let result = @wav.parse_and_decode(
        Array::makei(bytes.length(), i => bytes[i].to_int()),
      )
      guard result.ok else { fail(result.error.message) }
      accept(result.float_buffer)
    }
    "stream" => {
      let decoder = @wav.WavStreamDecoder::new()
      let mut left = size
      let mut problem : Error? = None
      while left > 0L {
        // An odd read size also exercises boundaries inside PCM16 samples.
        let n = left.min(65521L).to_int()
        decoder.feed(file.read_exactly(n), block => {
          if problem is None {
            accept(block) catch {
              e => problem = Some(e)
            }
          }
        })
        if problem is Some(e) {
          raise e
        }
        left -= n.to_int64()
      }
      ignore(decoder.finish())
    }
    _ => fail("Expected full or stream")
  }
  if !window.is_empty() {
    emit_fingerprint(window)
  }
}
