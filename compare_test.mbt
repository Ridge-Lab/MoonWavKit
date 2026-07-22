///|
test "compare buffers reports exact equality" {
  let a = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.5, -0.5])
  let b = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.5, -0.5])
  let comparison = @moonwavkit.compare_buffers(a, b)
  assert_true(comparison.comparable)
  assert_true(comparison.equal_with_tolerance)
  assert_eq(comparison.max_abs_error, 0.0)
  assert_eq(comparison.mean_abs_error, 0.0)
  assert_true(@moonwavkit.buffers_are_close(a, b))
}

///|
test "compare buffers respects tolerance" {
  let a = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.5, -0.5])
  let b = @moonwavkit.FloatBuffer::new(1, 8000, [0.0, 0.501, -0.5])
  let loose = @moonwavkit.compare_buffers(a, b, tolerance=0.01)
  let strict = @moonwavkit.compare_buffers(a, b, tolerance=0.0001)
  assert_true(loose.equal_with_tolerance)
  assert_false(strict.equal_with_tolerance)
  assert_true(loose.max_abs_error > 0.0009)
}

///|
test "compare buffers rejects incompatible formats" {
  let a = @moonwavkit.FloatBuffer::new(1, 8000, [0.0])
  let b = @moonwavkit.FloatBuffer::new(2, 8000, [0.0, 0.0])
  let comparison = @moonwavkit.compare_buffers(a, b)
  assert_false(comparison.comparable)
  assert_true(comparison.error.kind == @moonwavkit.ErrorInvalidArgument)
}

///|
test "comparison text renders pass and fail" {
  let a = @moonwavkit.FloatBuffer::new(1, 8000, [0.0])
  let b = @moonwavkit.FloatBuffer::new(1, 8000, [0.0])
  let pass = @moonwavkit.comparison_to_text(@moonwavkit.compare_buffers(a, b))
  let fail = @moonwavkit.comparison_to_text(
    @moonwavkit.compare_buffers(a, @moonwavkit.FloatBuffer::empty()),
  )
  assert_true(pass.contains("PASS"))
  assert_true(fail.contains("FAIL"))
}
