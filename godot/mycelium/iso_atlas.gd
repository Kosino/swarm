extends RefCounted
class_name MyceliumIsoAtlas
## Builds AtlasTexture resources (and pivot/offset) from godot_atlas.json (iso v2).
## FX sequences: MyceliumIsoAtlas.load_sequences() → name, frames, fps, blend.
## sprites_2x keys end with `_2x` — stripped so draw code uses logical names.

const ROOT := "res://art/mycelium_iso_v2/"
const JSON_PATH := ROOT + "godot_atlas.json"


static func _logical_name(name: String, use_2x: bool) -> String:
	if use_2x and name.ends_with("_2x"):
		return name.substr(0, name.length() - 3)
	return name


static func load_all(use_2x: bool = false) -> Dictionary:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("MyceliumIsoAtlas: cannot open " + JSON_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MyceliumIsoAtlas: invalid JSON")
		return {}
	var meta: Dictionary = parsed["meta"]
	var atlas_name: String = meta["atlas_2x"] if use_2x else meta["atlas"]
	var tex: Texture2D = load(ROOT + atlas_name) as Texture2D
	if tex == null:
		push_error("MyceliumIsoAtlas: cannot load " + ROOT + atlas_name)
		return {}
	var key := "sprites_2x" if use_2x else "sprites"
	if not parsed.has(key):
		push_error("MyceliumIsoAtlas: missing " + key)
		return {}
	var sprites: Dictionary = parsed[key]
	var out := {}
	for name in sprites:
		var s: Dictionary = sprites[name]
		var at := AtlasTexture.new()
		at.atlas = tex
		var r: Dictionary = s["region"]
		at.region = Rect2(float(r["x"]), float(r["y"]), float(r["w"]), float(r["h"]))
		at.filter_clip = true
		var pv: Dictionary = s["pivot"]
		var off: Dictionary = s["offset"]
		var logical := _logical_name(str(name), use_2x)
		out[logical] = {
			"texture": at,
			"pivot": Vector2(float(pv["x"]), float(pv["y"])),
			"offset": Vector2(float(off["x"]), float(off["y"])),
		}
	return out


static func load_sequences(use_2x: bool = false) -> Dictionary:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var key := "sequences_2x" if use_2x else "sequences"
	if not parsed.has(key):
		return {}
	var raw: Dictionary = parsed[key]
	var out := {}
	for seq_name in raw:
		var seq: Dictionary = raw[seq_name].duplicate(true)
		var frames: Array = []
		for f in seq.get("frames", []):
			frames.append(_logical_name(str(f), use_2x))
		seq["frames"] = frames
		out[str(seq_name)] = seq
	return out


static func apply_to_sprite(sprite: Sprite2D, entry: Dictionary) -> void:
	sprite.texture = entry["texture"]
	sprite.centered = false
	sprite.offset = entry["offset"]
