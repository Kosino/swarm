extends RefCounted
class_name ApisIsoAtlas
## AtlasTexture + pivot/offset (+ stack_offset on plast stages) from iso v2 godot_atlas.json.
## FX: ApisIsoAtlas.load_sequences()

const ROOT := "res://art/apis_iso_v2/"
const JSON_PATH := ROOT + "godot_atlas.json"


static func load_all(use_2x: bool = false) -> Dictionary:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("ApisIsoAtlas: cannot open " + JSON_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ApisIsoAtlas: invalid JSON")
		return {}
	var meta: Dictionary = parsed["meta"]
	var atlas_name: String = meta["atlas_2x"] if use_2x else meta["atlas"]
	var tex: Texture2D = load(ROOT + atlas_name) as Texture2D
	if tex == null:
		push_error("ApisIsoAtlas: cannot load " + ROOT + atlas_name)
		return {}
	var key := "sprites_2x" if use_2x else "sprites"
	if not parsed.has(key):
		push_error("ApisIsoAtlas: missing " + key)
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
		var entry := {
			"texture": at,
			"pivot": Vector2(float(pv["x"]), float(pv["y"])),
			"offset": Vector2(float(off["x"]), float(off["y"])),
		}
		if s.has("stack_offset"):
			var so: Dictionary = s["stack_offset"]
			entry["stack_offset"] = Vector2(float(so["x"]), float(so["y"]))
		if s.has("stack_anchor"):
			var sa: Dictionary = s["stack_anchor"]
			entry["stack_anchor"] = Vector2(float(sa["x"]), float(sa["y"]))
		out[name] = entry
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
	return parsed[key]


static func apply_to_sprite(sprite: Sprite2D, entry: Dictionary) -> void:
	sprite.texture = entry["texture"]
	sprite.centered = false
	sprite.offset = entry["offset"]
