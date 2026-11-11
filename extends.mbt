// Keep method-call syntax available to clients built against 0.1.3.

///|
pub extend AmplitudeBin with Eq::{equal, not_equal}

///|
pub extend AmplitudeBin with @debug.Debug::{to_repr}

///|
pub extend AmplitudeHistogram with Eq::{equal, not_equal}

///|
pub extend AmplitudeHistogram with @debug.Debug::{to_repr}

///|
pub extend AudioFingerprint with Eq::{equal, not_equal}

///|
pub extend AudioFingerprint with @debug.Debug::{to_repr}

///|
pub extend AudioRegion with Eq::{equal, not_equal}

///|
pub extend AudioRegion with @debug.Debug::{to_repr}

///|
pub extend AudioRegionKind with Eq::{equal, not_equal}

///|
pub extend AudioRegionKind with @debug.Debug::{to_repr}

///|
pub extend AudioSegmentOptions with Eq::{equal, not_equal}

///|
pub extend AudioSegmentOptions with @debug.Debug::{to_repr}

///|
pub extend AudioSegmentation with Eq::{equal, not_equal}

///|
pub extend AudioSegmentation with @debug.Debug::{to_repr}

///|
pub extend AudioStats with Eq::{equal, not_equal}

///|
pub extend AudioStats with @debug.Debug::{to_repr}

///|
pub extend BufferComparison with Eq::{equal, not_equal}

///|
pub extend BufferComparison with @debug.Debug::{to_repr}

///|
pub extend BufferMixResult with Eq::{equal, not_equal}

///|
pub extend BufferMixResult with @debug.Debug::{to_repr}

///|
pub extend ByteEncodeResult with Eq::{equal, not_equal}

///|
pub extend ByteEncodeResult with @debug.Debug::{to_repr}

///|
pub extend ByteReader with Eq::{equal, not_equal}

///|
pub extend ByteReader with @debug.Debug::{to_repr}

///|
pub extend ChannelStats with Eq::{equal, not_equal}

///|
pub extend ChannelStats with @debug.Debug::{to_repr}

///|
pub extend ChunkSummary with Eq::{equal, not_equal}

///|
pub extend ChunkSummary with @debug.Debug::{to_repr}

///|
pub extend CuePoint with Eq::{equal, not_equal}

///|
pub extend CuePoint with @debug.Debug::{to_repr}

///|
pub extend CueTimeline with Eq::{equal, not_equal}

///|
pub extend CueTimeline with @debug.Debug::{to_repr}

///|
pub extend DecodeOptions with Eq::{equal, not_equal}

///|
pub extend DecodeOptions with @debug.Debug::{to_repr}

///|
pub extend DecodeResult with Eq::{equal, not_equal}

///|
pub extend DecodeResult with @debug.Debug::{to_repr}

///|
pub extend FixtureCase with Eq::{equal, not_equal}

///|
pub extend FixtureCase with @debug.Debug::{to_repr}

///|
pub extend FixtureCaseResult with Eq::{equal, not_equal}

///|
pub extend FixtureCaseResult with @debug.Debug::{to_repr}

///|
pub extend FixtureExpectation with Eq::{equal, not_equal}

///|
pub extend FixtureExpectation with @debug.Debug::{to_repr}

///|
pub extend FloatBuffer with Eq::{equal, not_equal}

///|
pub extend FloatBuffer with @debug.Debug::{to_repr}

///|
pub extend FormatSummary with Eq::{equal, not_equal}

///|
pub extend FormatSummary with @debug.Debug::{to_repr}

///|
pub extend FrameRange with Eq::{equal, not_equal}

///|
pub extend FrameRange with @debug.Debug::{to_repr}

///|
pub extend InfoCatalog with Eq::{equal, not_equal}

///|
pub extend InfoCatalog with @debug.Debug::{to_repr}

///|
pub extend InfoTag with Eq::{equal, not_equal}

///|
pub extend InfoTag with @debug.Debug::{to_repr}

///|
pub extend LoopResult with Eq::{equal, not_equal}

///|
pub extend LoopResult with @debug.Debug::{to_repr}

///|
pub extend NormalizeReport with Eq::{equal, not_equal}

///|
pub extend NormalizeReport with @debug.Debug::{to_repr}

///|
pub extend ParsedWav with Eq::{equal, not_equal}

///|
pub extend ParsedWav with @debug.Debug::{to_repr}

///|
pub extend PcmBuffer with Eq::{equal, not_equal}

///|
pub extend PcmBuffer with @debug.Debug::{to_repr}

///|
pub extend PcmEncoding with Eq::{equal, not_equal}

///|
pub extend PcmEncoding with @debug.Debug::{to_repr}

///|
pub extend QualityFinding with Eq::{equal, not_equal}

///|
pub extend QualityFinding with @debug.Debug::{to_repr}

///|
pub extend QualityFindingKind with Eq::{equal, not_equal}

///|
pub extend QualityFindingKind with @debug.Debug::{to_repr}

///|
pub extend QualityProfile with Eq::{equal, not_equal}

///|
pub extend QualityProfile with @debug.Debug::{to_repr}

///|
pub extend ReportFormat with Eq::{equal, not_equal}

///|
pub extend ReportFormat with @debug.Debug::{to_repr}

///|
pub extend ResampleResult with Eq::{equal, not_equal}

///|
pub extend ResampleResult with @debug.Debug::{to_repr}

///|
pub extend RiffHeader with Eq::{equal, not_equal}

///|
pub extend RiffHeader with @debug.Debug::{to_repr}

///|
pub extend SampleRegion with Eq::{equal, not_equal}

///|
pub extend SampleRegion with @debug.Debug::{to_repr}

///|
pub extend SupportEntry with Eq::{equal, not_equal}

///|
pub extend SupportEntry with @debug.Debug::{to_repr}

///|
pub extend TrimResult with Eq::{equal, not_equal}

///|
pub extend TrimResult with @debug.Debug::{to_repr}

///|
pub extend ValidationIssue with Eq::{equal, not_equal}

///|
pub extend ValidationIssue with @debug.Debug::{to_repr}

///|
pub extend ValidationReport with Eq::{equal, not_equal}

///|
pub extend ValidationReport with @debug.Debug::{to_repr}

///|
pub extend ValidationSeverity with Eq::{equal, not_equal}

///|
pub extend ValidationSeverity with @debug.Debug::{to_repr}

///|
pub extend WavError with Eq::{equal, not_equal}

///|
pub extend WavError with @debug.Debug::{to_repr}

///|
pub extend WavErrorKind with Eq::{equal, not_equal}

///|
pub extend WavErrorKind with @debug.Debug::{to_repr}

///|
pub extend WavParseResult with Eq::{equal, not_equal}

///|
pub extend WavParseResult with @debug.Debug::{to_repr}

///|
pub extend WavReport with Eq::{equal, not_equal}

///|
pub extend WavReport with @debug.Debug::{to_repr}

///|
pub extend WaveChunk with Eq::{equal, not_equal}

///|
pub extend WaveChunk with @debug.Debug::{to_repr}

///|
pub extend WaveEncoding with Eq::{equal, not_equal}

///|
pub extend WaveEncoding with @debug.Debug::{to_repr}

///|
pub extend WaveFormat with Eq::{equal, not_equal}

///|
pub extend WaveFormat with @debug.Debug::{to_repr}

///|
pub extend WaveInfo with Eq::{equal, not_equal}

///|
pub extend WaveInfo with @debug.Debug::{to_repr}

///|
pub extend WaveformBucket with Eq::{equal, not_equal}

///|
pub extend WaveformBucket with @debug.Debug::{to_repr}

///|
pub extend WaveformPoint with Eq::{equal, not_equal}

///|
pub extend WaveformPoint with @debug.Debug::{to_repr}

///|
pub extend WaveformSummary with Eq::{equal, not_equal}

///|
pub extend WaveformSummary with @debug.Debug::{to_repr}
