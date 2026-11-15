extends RefCounted
class_name MyceliumIsoAtlas
## Builds AtlasTexture resources (and pivot/offset) from godot_atlas.json.
## Usage:
##   var data := MyceliumIsoAtlas.load_all()
##   MyceliumIsoAtlas.apply_to_sprite($Sprite2D, data["myc_iso_puda_a"])

const ROOT := "res://art/mycelium_iso_v1/"
const JSON_PATH := ROOT + "godot_atlas.json"


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
		out[name] = {
			"texture": at,
			"pivot": Vector2(float(pv["x"]), float(pv["y"])),
			"offset": Vector2(float(off["x"]), float(off["y"])),
		}
	return out


## Assigns the atlas region and places the sprite so its pivot sits at Node2D.position.
static func apply_to_sprite(sprite: Sprite2D, entry: Dictionary) -> void:
	sprite.texture = entry["texture"]
	sprite.centered = false
	sprite.offset = entry["offset"]
