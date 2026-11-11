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
async fn main {
  let args = @env.args()
  let (path, format) = match args[:] {
    [_, path] => (path, @moonwavkit.ReportText)
    [_, "--json", path] => (path, @moonwavkit.ReportJson)
    _ => {
      println("Usage: wavinfo [--json] FILE")
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
