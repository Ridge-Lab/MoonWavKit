///|
#derive(Eq, @debug.Debug)
pub(all) struct BufferComparison {
  comparable : Bool
  sample_count : Int32
  max_abs_error : Double
  mean_abs_error : Double
  equal_with_tolerance : Bool
  error : WavError
}

///|
pub fn BufferComparison::failure(error : WavError) -> BufferComparison {
  {
    comparable: false,
    sample_count: 0,
    max_abs_error: 0.0,
    mean_abs_error: 0.0,
    equal_with_tolerance: false,
    error,
  }
}

///|
pub fn BufferComparison::success(
  sample_count : Int32,
  max_abs_error : Double,
  mean_abs_error : Double,
  equal_with_tolerance : Bool,
) -> BufferComparison {
  {
    comparable: true,
    sample_count,
    max_abs_error,
    mean_abs_error,
    equal_with_tolerance,
    error: WavError::none(),
  }
}

///|
pub fn compare_buffers(
  expected : FloatBuffer,
  actual : FloatBuffer,
  tolerance~ : Double = 0.0001,
) -> BufferComparison {
  if !compatible_format(expected, actual) {
    BufferComparison::failure(
      WavError::new(
        ErrorInvalidArgument,
        "buffers must share channels and sample rate",
      ),
    )
  } else if expected.samples.length() != actual.samples.length() {
    BufferComparison::failure(
      WavError::new(
        ErrorInvalidArgument,
        "buffers must have identical sample count",
      ),
    )
  } else if tolerance < 0.0 {
    BufferComparison::failure(
      WavError::new(ErrorInvalidArgument, "tolerance must be non-negative"),
    )
  } else {
    let max_error = for i in 0..<expected.samples.length(); value = 0.0 {
      continue max_double(
          value,
          abs_double(expected.samples[i] - actual.samples[i]),
        )
    } nobreak {
      value
    }
    let sum_error = for i in 0..<expected.samples.length(); value = 0.0 {
      continue value + abs_double(expected.samples[i] - actual.samples[i])
    } nobreak {
      value
    }
    let mean = if expected.samples.length() == 0 {
      0.0
    } else {
      sum_error / expected.samples.length().to_double()
    }
    BufferComparison::success(
      expected.samples.length(),
      max_error,
      mean,
      max_error <= tolerance,
    )
  }
}

///|
pub fn buffers_are_close(
  expected : FloatBuffer,
  actual : FloatBuffer,
  tolerance~ : Double = 0.0001,
) -> Bool {
  let comparison = compare_buffers(expected, actual, tolerance~)
  comparison.comparable && comparison.equal_with_tolerance
}

///|
pub fn comparison_to_text(comparison : BufferComparison) -> String {
  if !comparison.comparable {
    "MoonWavKit comparison: FAIL\nerror: \{comparison.error.code()}"
  } else {
    "MoonWavKit comparison: PASS\nsamples: \{comparison.sample_count}\nmax_abs_error: \{comparison.max_abs_error}\nmean_abs_error: \{comparison.mean_abs_error}\nwithin_tolerance: \{comparison.equal_with_tolerance}"
  }
}
