///|
/// Error categories returned by the parser, decoder, validator, and CLI model.
#derive(Eq, @debug.Debug)
pub(all) enum WavErrorKind {
  ErrorNone
  ErrorTooShort
  ErrorNotRiff
  ErrorNotWave
  ErrorChunkOutOfBounds
  ErrorMissingFormat
  ErrorMissingData
  ErrorUnsupportedFormat
  ErrorInvalidFormat
  ErrorTruncatedData
  ErrorInvalidArgument
}

///|
pub fn WavErrorKind::code(self : WavErrorKind) -> String {
  match self {
    ErrorNone => "none"
    ErrorTooShort => "too-short"
    ErrorNotRiff => "not-riff"
    ErrorNotWave => "not-wave"
    ErrorChunkOutOfBounds => "chunk-out-of-bounds"
    ErrorMissingFormat => "missing-fmt"
    ErrorMissingData => "missing-data"
    ErrorUnsupportedFormat => "unsupported-format"
    ErrorInvalidFormat => "invalid-format"
    ErrorTruncatedData => "truncated-data"
    ErrorInvalidArgument => "invalid-argument"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WavError {
  kind : WavErrorKind
  offset : Int32
  message : String
}

///|
pub fn WavError::none() -> WavError {
  { kind: ErrorNone, offset: 0, message: "", }
}

///|
pub fn WavError::new(
  kind : WavErrorKind,
  message : String,
  offset~ : Int32 = 0,
) -> WavError {
  { kind, offset, message, }
}

///|
pub fn WavError::is_error(self : WavError) -> Bool {
  self.kind != ErrorNone
}

///|
pub fn WavError::code(self : WavError) -> String {
  self.kind.code()
}

///|
/// Non-owning reader over an integer byte array. Values outside 0..255 are masked.
#derive(Eq, @debug.Debug)
pub(all) struct ByteReader {
  bytes : Array[Int32]
  offset : Int32
}

///|
pub fn ByteReader::new(bytes : Array[Int32]) -> ByteReader {
  { bytes, offset: 0, }
}

///|
pub fn ByteReader::at(bytes : Array[Int32], offset : Int32) -> ByteReader {
  { bytes, offset, }
}

///|
pub fn ByteReader::length(self : ByteReader) -> Int32 {
  self.bytes.length()
}

///|
pub fn ByteReader::remaining(self : ByteReader) -> Int32 {
  self.bytes.length() - self.offset
}

///|
pub fn ByteReader::can_read(self : ByteReader, count : Int32) -> Bool {
  self.slice_can_read(self.offset, count)
}

///|
pub fn ByteReader::slice_can_read(
  self : ByteReader,
  offset : Int32,
  count : Int32,
) -> Bool {
  offset >= 0 && count >= 0 && count <= self.bytes.length() - offset
}

///|
pub fn ByteReader::byte_at(self : ByteReader, offset : Int32) -> Int32 {
  if self.slice_can_read(offset, 1) {
    self.bytes[offset] & 0xff
  } else {
    0
  }
}

///|
pub fn ByteReader::u16_le_at(self : ByteReader, offset : Int32) -> Int32 {
  self.byte_at(offset) | (self.byte_at(offset + 1) << 8)
}

///|
pub fn ByteReader::u24_le_at(self : ByteReader, offset : Int32) -> Int32 {
  self.byte_at(offset) |
  (self.byte_at(offset + 1) << 8) |
  (self.byte_at(offset + 2) << 16)
}

///|
pub fn ByteReader::u32_le_at(self : ByteReader, offset : Int32) -> Int32 {
  self.byte_at(offset) |
  (self.byte_at(offset + 1) << 8) |
  (self.byte_at(offset + 2) << 16) |
  (self.byte_at(offset + 3) << 24)
}

///|
pub fn ByteReader::i16_le_at(self : ByteReader, offset : Int32) -> Int32 {
  let raw = self.u16_le_at(offset)
  if raw >= 0x8000 {
    raw - 0x10000
  } else {
    raw
  }
}

///|
pub fn ByteReader::i24_le_at(self : ByteReader, offset : Int32) -> Int32 {
  let raw = self.u24_le_at(offset)
  if raw >= 0x800000 {
    raw - 0x1000000
  } else {
    raw
  }
}

///|
pub fn ByteReader::i32_le_at(self : ByteReader, offset : Int32) -> Int32 {
  let raw = self.u32_le_at(offset)
  raw
}

///|
pub fn ByteReader::matches_ascii(
  self : ByteReader,
  offset : Int32,
  a : Int32,
  b : Int32,
  c : Int32,
  d : Int32,
) -> Bool {
  self.byte_at(offset) == a &&
  self.byte_at(offset + 1) == b &&
  self.byte_at(offset + 2) == c &&
  self.byte_at(offset + 3) == d
}

///|
pub fn ByteReader::fourcc_at(self : ByteReader, offset : Int32) -> String {
  if self.matches_ascii(offset, 82, 73, 70, 70) {
    "RIFF"
  } else if self.matches_ascii(offset, 87, 65, 86, 69) {
    "WAVE"
  } else if self.matches_ascii(offset, 102, 109, 116, 32) {
    "fmt "
  } else if self.matches_ascii(offset, 100, 97, 116, 97) {
    "data"
  } else if self.matches_ascii(offset, 102, 97, 99, 116) {
    "fact"
  } else if self.matches_ascii(offset, 76, 73, 83, 84) {
    "LIST"
  } else if self.matches_ascii(offset, 73, 78, 70, 79) {
    "INFO"
  } else if self.matches_ascii(offset, 99, 117, 101, 32) {
    "cue "
  } else if self.slice_can_read(offset, 4) {
    let b0 = self.byte_at(offset)
    let b1 = self.byte_at(offset + 1)
    let b2 = self.byte_at(offset + 2)
    let b3 = self.byte_at(offset + 3)
    if b0 >= 32 &&
      b0 <= 126 &&
      b1 >= 32 &&
      b1 <= 126 &&
      b2 >= 32 &&
      b2 <= 126 &&
      b3 >= 32 &&
      b3 <= 126 {
      String::from_array([
        b0.to_uint16().unsafe_to_char(),
        b1.to_uint16().unsafe_to_char(),
        b2.to_uint16().unsafe_to_char(),
        b3.to_uint16().unsafe_to_char(),
      ])
    } else {
      "unknown"
    }
  } else {
    "unknown"
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct RiffHeader {
  riff_id : String
  file_size_minus_8 : Int32
  wave_id : String
}

///|
pub fn RiffHeader::empty() -> RiffHeader {
  { riff_id: "", file_size_minus_8: 0, wave_id: "", }
}

///|
pub fn RiffHeader::is_valid(self : RiffHeader) -> Bool {
  self.riff_id == "RIFF" &&
  self.wave_id == "WAVE" &&
  self.file_size_minus_8 >= 4
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WaveChunk {
  id : String
  offset : Int32
  data_offset : Int32
  size : Int32
  padded_size : Int32
}

///|
pub fn WaveChunk::new(
  id : String,
  offset : Int32,
  data_offset : Int32,
  size : Int32,
) -> WaveChunk {
  let padded_size = if size % 2 == 0 { size } else { size + 1 }
  { id, offset, data_offset, size, padded_size, }
}

///|
pub fn WaveChunk::empty() -> WaveChunk {
  { id: "", offset: 0, data_offset: 0, size: 0, padded_size: 0, }
}

///|
pub fn WaveChunk::end_offset(self : WaveChunk) -> Int32 {
  self.data_offset + self.padded_size
}

///|
pub fn WaveChunk::contains(self : WaveChunk, offset : Int32) -> Bool {
  offset >= self.data_offset && offset < self.data_offset + self.size
}

///|
pub fn WaveChunk::is_known(self : WaveChunk) -> Bool {
  self.id == "fmt " ||
  self.id == "data" ||
  self.id == "fact" ||
  self.id == "LIST" ||
  self.id == "cue "
}

///|
#derive(Eq, @debug.Debug)
pub(all) enum WaveEncoding {
  EncodingUnknown
  EncodingPcm
  EncodingIeeeFloat
  EncodingALaw
  EncodingMuLaw
  EncodingExtensible
}

///|
pub fn WaveEncoding::label(self : WaveEncoding) -> String {
  match self {
    EncodingUnknown => "unknown"
    EncodingPcm => "pcm"
    EncodingIeeeFloat => "ieee-float"
    EncodingALaw => "a-law"
    EncodingMuLaw => "mu-law"
    EncodingExtensible => "extensible"
  }
}

///|
pub fn encoding_from_code(code : Int32) -> WaveEncoding {
  match code {
    1 => EncodingPcm
    3 => EncodingIeeeFloat
    6 => EncodingALaw
    7 => EncodingMuLaw
    65534 => EncodingExtensible
    _ => EncodingUnknown
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WaveFormat {
  audio_format : Int32
  encoding : WaveEncoding
  channels : Int32
  sample_rate : Int32
  byte_rate : Int32
  block_align : Int32
  bits_per_sample : Int32
  extra_size : Int32
}

///|
pub fn WaveFormat::empty() -> WaveFormat {
  {
    audio_format: 0,
    encoding: EncodingUnknown,
    channels: 0,
    sample_rate: 0,
    byte_rate: 0,
    block_align: 0,
    bits_per_sample: 0,
    extra_size: 0,
  }
}

///|
pub fn WaveFormat::new(
  audio_format : Int32,
  channels : Int32,
  sample_rate : Int32,
  byte_rate : Int32,
  block_align : Int32,
  bits_per_sample : Int32,
  extra_size~ : Int32 = 0,
) -> WaveFormat {
  {
    audio_format,
    encoding: encoding_from_code(audio_format),
    channels,
    sample_rate,
    byte_rate,
    block_align,
    bits_per_sample,
    extra_size,
  }
}

///|
pub fn WaveFormat::bytes_per_sample(self : WaveFormat) -> Int32 {
  self.bits_per_sample / 8
}

///|
pub fn WaveFormat::expected_block_align(self : WaveFormat) -> Int32 {
  self.channels * self.bytes_per_sample()
}

///|
pub fn WaveFormat::expected_byte_rate(self : WaveFormat) -> Int32 {
  self.sample_rate * self.expected_block_align()
}

///|
pub fn WaveFormat::is_pcm(self : WaveFormat) -> Bool {
  self.encoding == EncodingPcm
}

///|
pub fn WaveFormat::is_float(self : WaveFormat) -> Bool {
  self.encoding == EncodingIeeeFloat
}

///|
pub fn WaveFormat::is_supported(self : WaveFormat) -> Bool {
  (
    self.is_pcm() &&
    (
      self.bits_per_sample == 8 ||
      self.bits_per_sample == 16 ||
      self.bits_per_sample == 24 ||
      self.bits_per_sample == 32
    )
  ) ||
  (self.is_float() && self.bits_per_sample == 32)
}

///|
pub fn WaveFormat::is_valid(self : WaveFormat) -> Bool {
  self.channels > 0 &&
  self.sample_rate > 0 &&
  self.byte_rate > 0 &&
  self.block_align > 0 &&
  self.bits_per_sample > 0 &&
  self.expected_block_align() == self.block_align &&
  self.expected_byte_rate() == self.byte_rate
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct InfoTag {
  key : String
  value : String
}

///|
pub fn InfoTag::new(key : String, value : String) -> InfoTag {
  { key, value, }
}

///|
pub fn InfoTag::empty() -> InfoTag {
  { key: "", value: "", }
}

///|
pub fn InfoTag::is_valid(self : InfoTag) -> Bool {
  self.key.length() > 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct CuePoint {
  id : Int32
  position : Int32
  sample_offset : Int32
}

///|
pub fn CuePoint::new(
  id : Int32,
  position : Int32,
  sample_offset : Int32,
) -> CuePoint {
  { id, position, sample_offset, }
}

///|
pub fn CuePoint::empty() -> CuePoint {
  { id: 0, position: 0, sample_offset: 0, }
}

///|
pub fn CuePoint::is_valid(self : CuePoint) -> Bool {
  self.id >= 0 && self.position >= 0 && self.sample_offset >= 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WaveInfo {
  duration_seconds : Double
  frame_count : Int32
  sample_count : Int32
  data_bytes : Int32
}

///|
pub fn WaveInfo::empty() -> WaveInfo {
  { duration_seconds: 0.0, frame_count: 0, sample_count: 0, data_bytes: 0, }
}

///|
pub fn WaveInfo::is_valid(self : WaveInfo) -> Bool {
  self.duration_seconds >= 0.0 &&
  self.frame_count >= 0 &&
  self.sample_count >= 0 &&
  self.data_bytes >= 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct ParsedWav {
  header : RiffHeader
  format : WaveFormat
  chunks : Array[WaveChunk]
  info_tags : Array[InfoTag]
  cue_points : Array[CuePoint]
  fact_sample_count : Int32
  data_offset : Int32
  data_size : Int32
  source_length : Int32
}

///|
pub fn ParsedWav::empty() -> ParsedWav {
  {
    header: RiffHeader::empty(),
    format: WaveFormat::empty(),
    chunks: [],
    info_tags: [],
    cue_points: [],
    fact_sample_count: 0,
    data_offset: 0,
    data_size: 0,
    source_length: 0,
  }
}

///|
pub fn ParsedWav::has_chunk(self : ParsedWav, id : String) -> Bool {
  for chunk in self.chunks {
    if chunk.id == id {
      break true
    }
  } nobreak {
    false
  }
}

///|
pub fn ParsedWav::info(self : ParsedWav) -> WaveInfo {
  if self.format.block_align <= 0 || self.format.sample_rate <= 0 {
    WaveInfo::empty()
  } else {
    let frame_count = self.data_size / self.format.block_align
    let sample_count = frame_count * self.format.channels
    {
      duration_seconds: frame_count.to_double() /
      self.format.sample_rate.to_double(),
      frame_count,
      sample_count,
      data_bytes: self.data_size,
    }
  }
}

///|
pub fn ParsedWav::is_complete(self : ParsedWav) -> Bool {
  self.header.is_valid() &&
  self.format.is_valid() &&
  self.data_offset > 0 &&
  self.data_size >= 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WavParseResult {
  ok : Bool
  wav : ParsedWav
  error : WavError
}

///|
pub fn WavParseResult::success(wav : ParsedWav) -> WavParseResult {
  { ok: true, wav, error: WavError::none(), }
}

///|
pub fn WavParseResult::failure(error : WavError) -> WavParseResult {
  { ok: false, wav: ParsedWav::empty(), error, }
}

///|
pub fn WavParseResult::is_ok(self : WavParseResult) -> Bool {
  self.ok
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct DecodeOptions {
  normalize : Bool
  clamp : Bool
  target_channels : Int32
}

///|
pub fn DecodeOptions::new(
  normalize~ : Bool = true,
  clamp~ : Bool = true,
  target_channels~ : Int32 = 0,
) -> DecodeOptions {
  { normalize, clamp, target_channels, }
}

///|
pub fn DecodeOptions::is_valid(self : DecodeOptions) -> Bool {
  // v0.1 always exposes normalized floating-point samples. Keep the field in
  // the public model for compatibility, but reject unsupported raw output.
  self.normalize && self.target_channels >= 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct PcmBuffer {
  channels : Int32
  sample_rate : Int32
  bits_per_sample : Int32
  samples : Array[Int32]
}

///|
pub fn PcmBuffer::empty() -> PcmBuffer {
  { channels: 0, sample_rate: 0, bits_per_sample: 0, samples: [], }
}

///|
pub fn PcmBuffer::new(
  channels : Int32,
  sample_rate : Int32,
  bits_per_sample : Int32,
  samples : Array[Int32],
) -> PcmBuffer {
  { channels, sample_rate, bits_per_sample, samples, }
}

///|
pub fn PcmBuffer::frame_count(self : PcmBuffer) -> Int32 {
  if self.channels <= 0 {
    0
  } else {
    self.samples.length() / self.channels
  }
}

///|
pub fn PcmBuffer::duration_seconds(self : PcmBuffer) -> Double {
  if self.sample_rate <= 0 {
    0.0
  } else {
    self.frame_count().to_double() / self.sample_rate.to_double()
  }
}

///|
pub fn PcmBuffer::is_valid(self : PcmBuffer) -> Bool {
  self.channels > 0 &&
  self.sample_rate > 0 &&
  self.bits_per_sample > 0 &&
  self.samples.length() % self.channels == 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct FloatBuffer {
  channels : Int32
  sample_rate : Int32
  samples : Array[Double]
}

///|
pub fn FloatBuffer::empty() -> FloatBuffer {
  { channels: 0, sample_rate: 0, samples: [], }
}

///|
pub fn FloatBuffer::new(
  channels : Int32,
  sample_rate : Int32,
  samples : Array[Double],
) -> FloatBuffer {
  { channels, sample_rate, samples, }
}

///|
pub fn FloatBuffer::frame_count(self : FloatBuffer) -> Int32 {
  if self.channels <= 0 {
    0
  } else {
    self.samples.length() / self.channels
  }
}

///|
pub fn FloatBuffer::duration_seconds(self : FloatBuffer) -> Double {
  if self.sample_rate <= 0 {
    0.0
  } else {
    self.frame_count().to_double() / self.sample_rate.to_double()
  }
}

///|
pub fn FloatBuffer::is_valid(self : FloatBuffer) -> Bool {
  self.channels > 0 &&
  self.sample_rate > 0 &&
  self.samples.length() % self.channels == 0
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct DecodeResult {
  ok : Bool
  pcm : PcmBuffer
  float_buffer : FloatBuffer
  error : WavError
}

///|
pub fn DecodeResult::success(
  pcm : PcmBuffer,
  float_buffer : FloatBuffer,
) -> DecodeResult {
  { ok: true, pcm, float_buffer, error: WavError::none(), }
}

///|
pub fn DecodeResult::failure(error : WavError) -> DecodeResult {
  {
    ok: false,
    pcm: PcmBuffer::empty(),
    float_buffer: FloatBuffer::empty(),
    error,
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct AudioStats {
  duration_seconds : Double
  frame_count : Int32
  sample_count : Int32
  peak : Double
  rms : Double
  silent_samples : Int32
  clipped_samples : Int32
  dc_offset : Double
}

///|
pub fn AudioStats::empty() -> AudioStats {
  {
    duration_seconds: 0.0,
    frame_count: 0,
    sample_count: 0,
    peak: 0.0,
    rms: 0.0,
    silent_samples: 0,
    clipped_samples: 0,
    dc_offset: 0.0,
  }
}

///|
pub fn AudioStats::has_clipping(self : AudioStats) -> Bool {
  self.clipped_samples > 0
}

///|
pub fn AudioStats::silence_ratio(self : AudioStats) -> Double {
  if self.sample_count == 0 {
    0.0
  } else {
    self.silent_samples.to_double() / self.sample_count.to_double()
  }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WaveformBucket {
  index : Int32
  min : Double
  max : Double
  average_abs : Double
}

///|
pub fn WaveformBucket::empty(index : Int32) -> WaveformBucket {
  { index, min: 0.0, max: 0.0, average_abs: 0.0, }
}

///|
#derive(Eq, @debug.Debug)
pub(all) struct WaveformSummary {
  buckets : Array[WaveformBucket]
  bucket_count : Int32
  source_samples : Int32
}

///|
pub fn WaveformSummary::empty() -> WaveformSummary {
  { buckets: [], bucket_count: 0, source_samples: 0, }
}

///|
pub fn WaveformSummary::is_valid(self : WaveformSummary) -> Bool {
  self.bucket_count == self.buckets.length() && self.source_samples >= 0
}
