///|
fn wav_bytes(raw : Array[Int32]) -> Bytes {
  Bytes::makei(raw.length(), i => raw[i].to_byte())
}

///|
test "all split positions preserve whole-file samples across PCM and float formats" {
  for
    raw in [
      fixture_pcm8_stereo(),
      fixture_pcm16_mono(),
      fixture_pcm24_mono(),
      fixture_pcm32_mono(),
      fixture_float32_mono(),
      fixture_with_info_and_cue(),
      fixture_with_unknown_chunk(),
      fixture_stereo_phase_test(),
    ] {
    let bytes = wav_bytes(raw)
    let expected = parse_and_decode(raw)
    assert_true(expected.ok)
    for split in 0..<=bytes.length() {
      let decoder = WavStreamDecoder::new()
      let samples : Array[Double] = []
      let emit = fn(buffer : FloatBuffer) {
        for s in buffer.samples {
          samples.push(s)
        }
      }
      decoder.feed(bytes[:split].to_owned(), emit)
      decoder.feed(bytes[split:].to_owned(), emit)
      let format = decoder.finish()
      assert_eq(format, decoder.finish())
      assert_eq(format.channels, expected.float_buffer.channels)
      assert_eq(format.sample_rate, expected.float_buffer.sample_rate)
      assert_eq(samples, expected.float_buffer.samples)
    }
  }
}

///|
test "all incomplete prefixes fail at EOF including a missing final pad" {
  let bytes = wav_bytes(fixture_pcm24_mono())
  for cut in 0..<bytes.length() {
    let decoder = WavStreamDecoder::new()
    for k in 0..<cut {
      decoder.feed(bytes[k:k + 1].to_owned(), _ => ())
    }
    try decoder.finish() catch {
      InvalidStream(_, offset, _) => assert_eq(offset, cut.to_int64())
    } noraise {
      _ => fail("truncated WAV accepted")
    }
    try decoder.feed(b"", _ => ()) catch {
      InvalidStream(_, _, _) => ()
    } noraise {
      _ => fail("failed stream accepted more input")
    }
  }
}

///|
test "valid odd final PCM with no pad and zero-frame files" {
  for samples in [[], [0, 128, 255]] {
    let data = [100, 97, 116, 97, samples.length(), 0, 0, 0, ..samples]
    let body = concat_arrays(fmt_chunk(1, 1, 8000, 8), data)
    let raw = concat_arrays(riff_prefix(body.length() + 4), body)
    let decoder = WavStreamDecoder::new()
    let got = []
    for b in raw {
      decoder.feed(Bytes::make(1, b.to_byte()), block => {
        for s in block.samples {
          got.push(s)
        }
      })
    }
    assert_eq(decoder.finish().sample_rate, 8000)
    assert_eq(got, parse_and_decode(raw).float_buffer.samples)
  }
}

///|
test "large single push emits owned frame-aligned blocks bounded by source bytes and frames" {
  let channels = 63
  let payload = Array::makei(4000 * channels * 3, i => 13 * i % 256)
  let body = concat_arrays(
    fmt_chunk(1, channels, 8000, 24),
    data_chunk(payload),
  )
  let raw = concat_arrays(riff_prefix(4 + body.length()), body)
  let expected = parse_and_decode(raw)
  assert_true(expected.ok)
  let decoder = WavStreamDecoder::new()
  let blocks : Array[FloatBuffer] = []
  decoder.feed(wav_bytes(raw), block => blocks.push(block))
  ignore(decoder.finish())
  assert_true(blocks.length() > 2)
  let mut pos = 0
  for block in blocks {
    assert_eq(block.channels, channels)
    assert_true(
      block.frame_count() <= 2048 && block.samples.length() * 3 <= 65536,
    )
    assert_eq(block.samples.length() % channels, 0)
    for value in block.samples {
      assert_eq(value, expected.float_buffer.samples[pos])
      pos += 1
    }
  }
  assert_eq(pos, expected.float_buffer.samples.length())
}

///|
test "streamed float preserves finite out-of-range amplitude and silences non-finite samples" {
  let words = [
    0x40200000, 0xc0400000, 0x7fc00000, 0x7f800000, 0xff800000, 0x80000000,
  ]
  let bytes = Array::makei(words.length() * 4, i => {
    (words[i / 4] >> (i % 4 * 8)) & 255
  })
  let body = concat_arrays(fmt_chunk(3, 2, 48000, 32), data_chunk(bytes))
  let decoder = WavStreamDecoder::new(clamp=false)
  let blocks = []
  decoder.feed(wav_bytes(concat_arrays(riff_prefix(4 + body.length()), body)), b => {
    blocks.push(b)
  })
  ignore(decoder.finish())
  assert_eq(blocks[0].samples, [2.5, -3.0, 0.0, 0.0, 0.0, -0.0])
  assert_eq(blocks[0].samples[5].reinterpret_as_int64(), 0x8000000000000000L)
}

///|
test "traversal rejects wrong order, duplicates, unaligned data and invalid lengths" {
  let fmt = fmt_chunk(1, 1, 8000, 16)
  let data = data_chunk([0, 0])
  let cases : Array[(Array[Int32], WavErrorKind)] = [
    (concat_arrays(data, fmt), ErrorMissingFormat),
    (concat3(fmt, fmt, data), ErrorInvalidFormat),
    (concat3(fmt, data, data), ErrorInvalidFormat),
    (concat_arrays(fmt, data_chunk([0])), ErrorTruncatedData),
    (fmt, ErrorMissingData),
    (
      concat_arrays(fmt, [100, 97, 116, 97, 0xff, 0xff, 0xff, 0xff]),
      ErrorChunkOutOfBounds,
    ),
    (
      concat_arrays(fmt, [74, 85, 78, 75, 1, 0, 0, 0, 0xff]),
      ErrorChunkOutOfBounds,
    ),
    (concat3(fmt_chunk(3, 1, 8000, 16), data, []), ErrorUnsupportedFormat),
  ]
  for (body, code) in cases {
    let decoder = WavStreamDecoder::new()
    try {
      decoder.feed(
        wav_bytes(concat_arrays(riff_prefix(4 + body.length()), body)),
        _ => (),
      )
      ignore(decoder.finish())
    } catch {
      InvalidStream(actual, _, _) => assert_eq(actual, code)
    } noraise {
      _ => fail("malformed WAV accepted")
    }
  }
}

///|
test "skip unknown chunks with high unsigned size without buffering payload" {
  let decoder = WavStreamDecoder::new()
  decoder.feed(b"RIFF\xff\xff\xff\xffWAVEJUNK\x01\x00\x00\x80", _ => ())
  decoder.feed(Bytes::make(65536, b'\x00'), _ => ())
  assert_eq(decoder.buffer.length(), 0)
  try decoder.finish() catch {
    InvalidStream(ErrorTruncatedData, 65556L, _) => ()
    _ => fail("incorrect EOF for large chunk")
  } noraise {
    _ => fail("truncated large chunk accepted")
  }
}

///|
test "stream lifecycle rejects callback reentry and writes after finish" {
  let decoder = WavStreamDecoder::new()
  let mut rejected = 0
  decoder.feed(wav_bytes(fixture_pcm16_mono()), _ => {
    decoder.feed(b"x", _ => ()) catch {
      InvalidStream(ErrorInvalidArgument, _, _) => rejected += 1
      _ => ()
    }
    ignore(decoder.finish()) catch {
      InvalidStream(ErrorInvalidArgument, _, _) => rejected += 1
      _ => ()
    }
  })
  assert_eq(rejected, 2)
  ignore(decoder.finish())
  try decoder.feed(b"", _ => ()) catch {
    InvalidStream(ErrorInvalidArgument, _, _) => ()
    _ => fail("unexpected final state")
  } noraise {
    _ => fail("feed after finish accepted")
  }
}

///|
test "byte-rate multiplication cannot wrap to an apparently valid positive Int" {
  let fmt = fmt_chunk(1, 4, 536870913, 16)
  let body = concat_arrays(fmt, data_chunk([]))
  let raw = concat_arrays(riff_prefix(4 + body.length()), body)
  assert_false(parse_wav(raw).ok)
  let decoder = WavStreamDecoder::new()
  try decoder.feed(wav_bytes(raw), _ => ()) catch {
    InvalidStream(ErrorInvalidFormat, _, _) => ()
    _ => fail("unexpected byte-rate error")
  } noraise {
    _ => fail("invalid byte rate accepted")
  }
}
