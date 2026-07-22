///|
fn wants_json(args : Array[String]) -> Bool {
  for arg in args {
    if arg == "--json" || arg == "-j" {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn main {
  let format = if wants_json(@env.args()) {
    @moonwavkit.ReportJson
  } else {
    @moonwavkit.ReportText
  }
  println(@moonwavkit.wavinfo_fixture_report(format~))
}
