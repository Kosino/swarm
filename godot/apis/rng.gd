## mulberry32 — bit-exact port of JS Math.imul / >>> version used in headless.ts
class_name ApisRng
extends RefCounted

var _a: int = 0


func _init(seed: int = 0) -> void:
	_a = seed & 0xFFFFFFFF


static func _u32(x: int) -> int:
	return x & 0xFFFFFFFF


static func _to_int32(x: int) -> int:
	var u := x & 0xFFFFFFFF
	if u >= 0x80000000:
		return u - 0x100000000
	return u


static func _usr(x: int, n: int) -> int:
	return (x & 0xFFFFFFFF) >> n


static func _imul(a: int, b: int) -> int:
	## Math.imul: 32-bit signed multiply
	var r := ((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)) & 0xFFFFFFFF
	return _to_int32(r)


func next() -> float:
	_a = (_a + 0x6d2b79f5) & 0xFFFFFFFF
	var t: int = _a
	t = _imul(t ^ _usr(t, 15), t | 1)
	var add := _to_int32(t) + _imul(t ^ _usr(t, 7), t | 61)
	t = _to_int32(t) ^ _to_int32(add)
	return float(_u32(t ^ _usr(t, 14))) / 4294967296.0
