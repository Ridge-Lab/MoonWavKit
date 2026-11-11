///|
fn parse_header(reader : ByteReader) -> WavParseResult {
  if !reader.slice_can_read(0, 12) {
    WavParseResult::failure(
      WavError::new(ErrorTooShort, "WAV data is shorter than RIFF header"),
    )
  } else if !reader.matches_ascii(0, 82, 73, 70, 70) {
    WavParseResult::failure(
      WavError::new(ErrorNotRiff, "expected RIFF signature"),
    )
  } else if !reader.matches_ascii(8, 87, 65, 86, 69) {
    WavParseResult::failure(
      WavError::new(ErrorNotWave, "expected WAVE signature", offset=8),
    )
  } else {
    let header = {
      riff_id: "RIFF",
      file_size_minus_8: reader.u32_le_at(4),
      wave_id: "WAVE",
    }
    WavParseResult::success({
      header,
      format: WaveFormat::empty(),
      chunks: [],
      info_tags: [],
      cue_points: [],
      fact_sample_count: 0,
      data_offset: 0,
      data_size: 0,
      source_length: reader.length(),
    })
  }
}

///|
fn parse_format(reader : ByteReader, chunk : WaveChunk) -> WaveFormat {
  if chunk.size < 16 || !reader.slice_can_read(chunk.data_offset, 16) {
    WaveFormat::empty()
  } else {
    let extra_size = if chunk.size >= 18 &&
      reader.slice_can_read(chunk.data_offset + 16, 2) {
      reader.u16_le_at(chunk.data_offset + 16)
    } else {
      0
    }
    WaveFormat::new(
      reader.u16_le_at(chunk.data_offset),
      reader.u16_le_at(chunk.data_offset + 2),
      reader.u32_le_at(chunk.data_offset + 4),
      reader.u32_le_at(chunk.data_offset + 8),
      reader.u16_le_at(chunk.data_offset + 12),
      reader.u16_le_at(chunk.data_offset + 14),
      extra_size~,
    )
  }
}

///|
fn ascii_value_at(reader : ByteReader, offset : Int32, size : Int32) -> String {
  if size <= 0 || !reader.slice_can_read(offset, size) {
    ""
  } else {
    let text = for i in 0..<size; acc = "" {
      let byte = reader.byte_at(offset + i)
      if byte == 0 {
        continue acc
      } else if byte >= 32 && byte <= 126 {
        continue acc + String::from_array([byte.to_uint16().unsafe_to_char()])
      } else {
        continue acc
      }
    } nobreak {
      acc
    }
    text
  }
}

///|
fn parse_info_tags(reader : ByteReader, chunk : WaveChunk) -> Array[InfoTag] {
  let tags : Array[InfoTag] = []
  if chunk.size < 4 || !reader.slice_can_read(chunk.data_offset, chunk.size) {
    tags
  } else {
    let list_kind = reader.fourcc_at(chunk.data_offset)
    if list_kind != "INFO" {
      tags
    } else {
      let end = chunk.data_offset + chunk.size
      for offset = chunk.data_offset + 4; offset + 8 <= end; {
        let key = reader.fourcc_at(offset)
        let size = reader.u32_le_at(offset + 4)
        let data_offset = offset + 8
        if data_offset + size > end {
          break tags
        }
        tags.push(InfoTag::new(key, ascii_value_at(reader, data_offset, size)))
        let padded = if size % 2 == 0 { size } else { size + 1 }
        continue data_offset + padded
      } nobreak {
        tags
      }
    }
  }
}

///|
fn parse_cue_points(reader : ByteReader, chunk : WaveChunk) -> Array[CuePoint] {
  let points : Array[CuePoint] = []
  if chunk.size < 4 || !reader.slice_can_read(chunk.data_offset, chunk.size) {
    points
  } else {
    let count = reader.u32_le_at(chunk.data_offset)
    let max_count = (chunk.size - 4) / 24
    let safe_count = if count < max_count { count } else { max_count }
    for i in 0..<safe_count {
      let base = chunk.data_offset + 4 + i * 24
      points.push(
        CuePoint::new(
          reader.u32_le_at(base),
          reader.u32_le_at(base + 4),
          reader.u32_le_at(base + 20),
        ),
      )
    }
    points
  }
}

///|
fn parse_fact_sample_count(reader : ByteReader, chunk : WaveChunk) -> Int32 {
  if chunk.size >= 4 && reader.slice_can_read(chunk.data_offset, 4) {
    reader.u32_le_at(chunk.data_offset)
  } else {
    0
  }
}

///|
fn validate_chunk_bounds(reader : ByteReader, chunk : WaveChunk) -> Bool {
  chunk.offset >= 12 &&
  chunk.size >= 0 &&
  chunk.data_offset >= chunk.offset + 8 &&
  chunk.end_offset() <= reader.length()
}

///|
/// Parse a RIFF/WAVE byte array into structural metadata. The parser skips
/// unknown chunks while preserving their id and bounds.
pub fn parse_wav(bytes : Array[Int32]) -> WavParseResult {
  let reader = ByteReader::new(bytes)
  let header_result = parse_header(reader)
  if !header_result.ok {
    header_result
  } else {
    let chunks : Array[WaveChunk] = []
    let info_tags : Array[InfoTag] = []
    let cue_points : Array[CuePoint] = []
    let mut format = WaveFormat::empty()
    let mut data_offset = 0
    let mut data_size = 0
    let mut fact_sample_count = 0
    let parse_error = for offset = 12; offset + 8 <= reader.length(); {
      let id = reader.fourcc_at(offset)
      let size = reader.u32_le_at(offset + 4)
      let chunk = WaveChunk::new(id, offset, offset + 8, size)
      if !validate_chunk_bounds(reader, chunk) {
        break Some(
          WavError::new(
            ErrorChunkOutOfBounds,
            "chunk extends beyond the available byte array",
            offset~,
          ),
        )
      }
      chunks.push(chunk)
      if id == "fmt " {
        format = parse_format(reader, chunk)
      } else if id == "data" {
        data_offset = chunk.data_offset
        data_size = chunk.size
      } else if id == "fact" {
        fact_sample_count = parse_fact_sample_count(reader, chunk)
      } else if id == "LIST" {
        for tag in parse_info_tags(reader, chunk) {
          info_tags.push(tag)
        }
      } else if id == "cue " {
        for point in parse_cue_points(reader, chunk) {
          cue_points.push(point)
        }
      }
      continue chunk.end_offset()
    } nobreak {
      None
    }
    match parse_error {
      Some(error) => WavParseResult::failure(error)
      None =>
        if !format.is_valid() {
          WavParseResult::failure(
            WavError::new(ErrorMissingFormat, "missing or invalid fmt chunk"),
          )
        } else if data_offset == 0 || data_size == 0 {
          WavParseResult::failure(
            WavError::new(ErrorMissingData, "missing data chunk"),
          )
        } else {
          WavParseResult::success({
            header: header_result.wav.header,
            format,
            chunks,
            info_tags,
            cue_points,
            fact_sample_count,
            data_offset,
            data_size,
            source_length: bytes.length(),
          })
        }
    }
  }
}

///|
pub fn validate_wav(bytes : Array[Int32]) -> WavError {
  let parsed = parse_wav(bytes)
  if !parsed.ok {
    parsed.error
  } else if !parsed.wav.format.is_supported() {
    WavError::new(
      ErrorUnsupportedFormat,
      "format is structurally valid but unsupported by v1",
    )
  } else if parsed.wav.data_size % parsed.wav.format.block_align != 0 {
    WavError::new(
      ErrorTruncatedData,
      "data chunk is not aligned to complete sample frames",
    )
  } else {
    WavError::none()
  }
}
