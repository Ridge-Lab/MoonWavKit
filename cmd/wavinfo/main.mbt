///|
async fn inspect_file(path : String) -> @moonwavkit.WavReport {
  if @fs.kind(path) != Regular {
    return @moonwavkit.WavReport::failure("input-limit")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if file.kind() != Regular || size < 0 || size > 16777216 {
    return @moonwavkit.WavReport::failure("input-limit")
  }
  let bytes = file.read_exactly(size.to_int())
  @moonwavkit.build_report(Array::makei(bytes.length(), i => bytes[i].to_int()))
}

///|
async fn inspect_stream(path : String) -> Json {
  if @fs.kind(path) != Regular {
    return { "ok": false, "error": "input-limit" }
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let decoder = @moonwavkit.WavStreamDecoder::new()
  let mut samples = 0L
  let mut peak = 0.0
  let mut squares = 0.0
  let mut remaining = file.size()
  if file.kind() != Regular || remaining < 0L {
    return { "ok": false, "error": "input-limit" }
  }
  while remaining > 0L {
    let size = remaining.min(65536L).to_int()
    let bytes = file.read_exactly(size)
    decoder.feed(bytes, block => {
      samples += block.samples.length().to_int64()
      for sample in block.samples {
        peak = peak.max(sample.abs())
        squares += sample * sample
      }
    })
    remaining -= size.to_int64()
  }
  let format = decoder.finish()
  let rms = if samples == 0L {
    0.0
  } else {
    (squares / samples.to_double()).sqrt()
  }
  {
    "ok": true,
    "encoding": format.encoding.label(),
    "channels": format.channels,
    "bits_per_sample": format.bits_per_sample,
    "sample_rate": format.sample_rate,
    "frames": Json::number((samples / format.channels.to_int64()).to_double()),
    "peak": peak,
    "rms": rms,
  }
}

///|
async fn main {
  let args = @env.args()
  if args[:] is [_, "--stream", path] {
    let report = inspect_stream(path) catch {
      @moonwavkit.InvalidStream(kind, _, _) =>
        { "ok": false, "error": kind.code() }
      _ => { "ok": false, "error": "input-io" }
    }
    println(report.stringify())
    if report is { "ok": False, .. } {
      @env.exit(1)
    }
    return
  }
  let (path, format) = match args[:] {
    [_, path] => (path, @moonwavkit.ReportText)
    [_, "--json", path] => (path, @moonwavkit.ReportJson)
    _ => {
      println("Usage: wavinfo [--json | --stream] FILE")
      @env.exit(2)
    }
  }
  let report = inspect_file(path) catch {
    _ => @moonwavkit.WavReport::failure("input-io")
  }
  println(report.render(format))
  if !report.ok {
    @env.exit(1)
  }
}
