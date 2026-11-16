extends RefCounted
class_name SwarmProArt
## Data-driven pro_v3 loader. Paths come from pivots.json (`file` / `file_2x`);
## Phase B may overwrite the same filenames — no hardcoded absolute paths in scenes.
## Optional aliases.json maps gameplay keys → pivots ids (thin, stable).

const ROOT := "res://art/pro_v3/"
const PIVOTS := ROOT + "pivots.json"
const ALIASES := ROOT + "aliases.json"

## Fallback aliases if aliases.json missing (Phase A).
const DEFAULT_ALIASES := {
	"myc_infected": "myc_pro_stroj_infikovany",
	"myc_infected_beetle": "myc_pro_brouk_infikovany",
	"myc_skeleton": "myc_pro_skelet",
	"myc_giant_fruit": "myc_pro_plodnice_obri",
	"myc_seed_capsule": "myc_pro_plodnice_obri_tobolka",
	"apis_rust_machine": "apis_pro_stroj_rezavy",
	"apis_tree_flower": "apis_pro_strom_kvet",
	"apis_queen": "apis_pro_kralovna",
	"apis_royal_cell": "apis_pro_kukla",
	"logo": "logo_swarm",
	"swarm_logo": "logo_swarm_sm",
	"menu_bg": "menu_dual",
	"menu_title": "menu_dual",
	"menu_choose": "menu_dual",
	"menu_apis": "menu_apis",
	"menu_mycelium": "menu_mycelium",
	"planet_apis": "menu_apis",
	"planet_mycelium": "menu_mycelium",
	"myc_tex_puda_hola": "myc_tex_puda_hola",
	"myc_tex_puda_prorostla": "myc_tex_puda_prorostla",
	"myc_tex_puda_zarici": "myc_tex_puda_zarici",
	"apis_tex_louka_divoka": "apis_tex_louka_divoka",
	"apis_tex_louka_osazena": "apis_tex_louka_osazena",
	"apis_tex_louka_ziva": "apis_tex_louka_ziva",
	"apis_tex_skala": "apis_tex_skala",
	"apis_tex_skala_okraj": "apis_tex_skala_okraj",
	## Phase B placeholders (same filenames when Art Pipeline drops them):
	"reticle": "ui_reticle",
	"ending_planet": "ending_planet",
	"ui_panel": "ui_panel",
}


static func load_all(use_2x: bool = false) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(PIVOTS):
		return out
	var pf := FileAccess.open(PIVOTS, FileAccess.READ)
	if pf == null:
		return out
	var pivots: Variant = JSON.parse_string(pf.get_as_text())
	pf.close()
	if typeof(pivots) != TYPE_DICTIONARY:
		return out

	var aliases: Dictionary = DEFAULT_ALIASES.duplicate()
	if FileAccess.file_exists(ALIASES):
		var af := FileAccess.open(ALIASES, FileAccess.READ)
		if af:
			var ap: Variant = JSON.parse_string(af.get_as_text())
			af.close()
			if typeof(ap) == TYPE_DICTIONARY:
				for k in ap:
					aliases[str(k)] = str(ap[k])

	## Index every pivots entry by its own id (and by basename).
	for asset_id in pivots:
		var entry: Dictionary = pivots[asset_id]
		var loaded := _load_entry(entry, use_2x)
		if loaded.is_empty():
			continue
		out[str(asset_id)] = loaded

	## Gameplay aliases → same texture entries (shared refs).
	for logical in aliases:
		var aid: String = str(aliases[logical])
		if out.has(aid):
			out[str(logical)] = out[aid]
	return out


static func _load_entry(entry: Dictionary, use_2x: bool) -> Dictionary:
	var rel := ""
	if use_2x and entry.has("file_2x"):
		rel = str(entry["file_2x"])
	elif entry.has("file"):
		rel = str(entry["file"])
	if rel == "":
		return {}
	var path := ROOT + rel
	## Phase B may add file before import — try FileAccess then load().
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		## Fallback: if 2x missing, try 1x.
		if use_2x and entry.has("file"):
			path = ROOT + str(entry["file"])
			use_2x = false
			if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
				return {}
		else:
			return {}
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return {}
	var pv_key := "pivot_2x" if use_2x and entry.has("pivot_2x") else "pivot"
	var pivot := Vector2.ZERO
	if entry.has(pv_key):
		var pv = entry[pv_key]
		if typeof(pv) == TYPE_ARRAY and pv.size() >= 2:
			pivot = Vector2(float(pv[0]), float(pv[1]))
	return {
		"texture": tex,
		"pivot": pivot,
		"path": rel,
		"notes": str(entry.get("notes", "")),
	}


static func has(pro: Dictionary, key: String) -> bool:
	return pro.has(key) and tex(pro, key) != null


static func tex(pro: Dictionary, key: String) -> Texture2D:
	if not pro.has(key):
		return null
	var e = pro[key]
	if e is Texture2D:
		return e
	if e is Dictionary and e.has("texture"):
		return e.texture
	return null


static func pivot(pro: Dictionary, key: String) -> Vector2:
	if not pro.has(key):
		return Vector2.ZERO
	var e = pro[key]
	if e is Dictionary and e.has("pivot"):
		return e.pivot
	return Vector2.ZERO


static func blit(host: CanvasItem, pro: Dictionary, key: String, iso: Vector2, scale: float = 1.0, modulate: Color = Color.WHITE) -> void:
	var t := tex(pro, key)
	if t == null:
		return
	var pv := pivot(pro, key)
	var sz: Vector2 = t.get_size() * scale
	var off: Vector2 = -pv * scale if pv != Vector2.ZERO else -sz * 0.5
	host.draw_texture_rect(t, Rect2(iso + off, sz), false, modulate)


static func blit_tex(host: CanvasItem, texture: Texture2D, iso: Vector2, scale: float = 1.0, modulate: Color = Color.WHITE, pivot_v: Vector2 = Vector2.ZERO) -> void:
	if texture == null:
		return
	var sz: Vector2 = texture.get_size() * scale
	var off := -pivot_v * scale if pivot_v != Vector2.ZERO else -sz * 0.5
	host.draw_texture_rect(texture, Rect2(iso + off, sz), false, modulate)
