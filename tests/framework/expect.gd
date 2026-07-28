class_name Expect

## Each assertion returns "" on success or a failure message on failure,
## so test functions can just return the first non-empty result.

static func equal(actual, expected, label: String) -> String:
	if actual != expected:
		return "%s: expected %s, got %s" % [label, expected, actual]
	return ""

static func approx(actual: float, expected: float, label: String, epsilon: float = 0.001) -> String:
	if not is_equal_approx_eps(actual, expected, epsilon):
		return "%s: expected ~%s, got %s" % [label, expected, actual]
	return ""

static func is_true(actual: bool, label: String) -> String:
	if not actual:
		return "%s: expected true" % label
	return ""

static func is_false(actual: bool, label: String) -> String:
	if actual:
		return "%s: expected false" % label
	return ""

static func is_equal_approx_eps(a: float, b: float, epsilon: float) -> bool:
	return absf(a - b) <= epsilon
