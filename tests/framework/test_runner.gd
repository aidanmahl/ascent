class_name TestRunner
extends RefCounted

## Minimal headless test registry. Test functions take no arguments and
## return "" on pass or a failure message on fail (see Expect).

var _names: Array[String] = []
var _fns: Array[Callable] = []

func register(test_name: String, fn: Callable) -> void:
	_names.append(test_name)
	_fns.append(fn)

func run_all() -> bool:
	var all_passed := true
	for i in range(_names.size()):
		var test_name: String = _names[i]
		var fn: Callable = _fns[i]
		var failure: String = fn.call()
		if failure == "":
			print("[PASS] %s" % test_name)
		else:
			all_passed = false
			printerr("[FAIL] %s: %s" % [test_name, failure])
	return all_passed
