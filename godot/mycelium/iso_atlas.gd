extends RefCounted
class_name MyceliumIsoAtlas
## Builds AtlasTexture resources (and pivot/offset) from godot_atlas.json (iso v2).
## FX sequences: MyceliumIsoAtlas.load_sequences() → name, frames, fps, blend.
## sprites_2x keys end with `_2x` — stripped so draw code uses logical names.

const ROOT := "res://art/mycelium_iso_v2/"
const JSON_PATH := ROOT + "godot_atlas.json"
## Build 21+: taller art_drop silhouettes prefer loose sprites/ over atlas crops.
const LOOSE_SILHOUETTES := [
	"myc2_plodnice_rozestavena", "myc2_plodnice_dorostla", "myc2_plodnice_zariva",
	"myc2_kotva_rozestavena", "myc2_kotva_dorostla", "myc2_kotva_zariva",
	"myc2_zarodek_rozestavena", "myc2_zarodek_dorostla", "myc2_zarodek_zariva",
	## Mycelium units — spore crawlers (dělník ± nesení, 4 dirs).
	"myc2_delnik_NW", "myc2_delnik_NE", "myc2_delnik_SW", "myc2_delnik_SE",
	"myc2_delnik_neseni_NW", "myc2_delnik_neseni_NE", "myc2_delnik_neseni_SW", "myc2_delnik_neseni_SE",
]


static func _logical_name(name: String, use_2x: bool) -> String:
	if use_2x and name.ends_with("_2x"):
		return name.substr(0, name.length() - 3)
	return name


static func _apply_loose_silhouettes(out: Dictionary, use_2x: bool) -> void:
	## Prefer art_drop 3/4-height sprites over shorter atlas crops when present.
	for logical in LOOSE_SILHOUETTES:
		var file_name: String = logical + ("_2x.png" if use_2x else ".png")
		var path: String = ROOT + "sprites/" + file_name
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		var sz: Vector2 = tex.get_size()
		var prev_h: float = 0.0
		if out.has(logical) and out[logical].has("texture") and out[logical].texture != null:
			prev_h = float(out[logical].texture.get_size().y)
		var pivot := Vector2(sz.x * 0.5, sz.y)
		var foot_pad: float = 6.0 * (2.0 if use_2x else 1.0)
		if out.has(logical) and out[logical].has("pivot"):
			## Keep atlas pivot X; taller crops drop foot to bottom, same-height units keep atlas foot.
			pivot.x = float(out[logical].pivot.x)
			if use_2x and pivot.x < sz.x * 0.25:
				pivot.x = sz.x * 0.5
			if prev_h > 0.0 and sz.y <= prev_h + 1.0:
				pivot.y = float(out[logical].pivot.y)
				if out[logical].has("offset"):
					foot_pad = float(out[logical].offset.y) + pivot.y
		var offset := Vector2(-pivot.x, -pivot.y + foot_pad)
		out[logical] = {
			"texture": tex,
			"pivot": pivot,
			"offset": offset,
		}


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
	_apply_loose_silhouettes(out, use_2x)
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
