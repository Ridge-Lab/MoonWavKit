///|
test "decode Float32 mono, 48000 samples" (it : @bench.T) {
  // Cycle through sign, exponent and mantissa. All samples are finite and
  // in the unit range. Input generation and RIFF parsing are outside timing.
  let payload = Array::makei(48000 * 4, i => {
    let n = i / 4
    let bits = ((n % 2) << 31) | ((126 - n % 16) << 23) | n
    (bits >> (i % 4 * 8)) & 255
  })
  let body = concat_arrays(fmt_chunk(3, 1, 48000, 32), data_chunk(payload))
  let bytes = concat_arrays(riff_prefix(4 + body.length()), body)
  let parsed = parse_wav(bytes)
  assert_true(parsed.ok)
  let check = decode_pcm(bytes, parsed.wav)
  assert_true(check.ok)
  assert_eq(check.float_buffer.samples.length(), 48000)
  assert_eq(check.float_buffer.samples[0], 0.5)
  it.bench(fn() { it.keep(decode_pcm(bytes, parsed.wav)) })
}
