## Safe SFX facade — works under --script headless (no SwarmAudio global).
class_name SwarmSfx
extends RefCounted


static func _audio():
	var tree = Engine.get_main_loop()
	if tree == null or not (tree is SceneTree):
		return null
	var root: Window = (tree as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null("SwarmAudio")


static func play_dum(big: bool = false, soft: bool = false) -> void:
	var a = _audio()
	if a != null:
		a.play_dum(big, soft)


static func play_soft(kind: String) -> void:
	var a = _audio()
	if a != null:
		a.play_soft(kind)


static func play_bzz() -> void:
	var a = _audio()
	if a != null:
		a.play_bzz()


static func play_chime() -> void:
	var a = _audio()
	if a != null:
		a.play_chime()


static func play_ui(kind: String) -> void:
	var a = _audio()
	if a != null:
		a.play_ui(kind)


static func play_place(soft: bool = false) -> void:
	var a = _audio()
	if a != null:
		a.play_place(soft)


static func play_pulse(big: bool = false) -> void:
	var a = _audio()
	if a != null:
		a.play_pulse(big)


static func set_ambient(rod: String) -> void:
	var a = _audio()
	if a != null:
		a.set_ambient(rod)
