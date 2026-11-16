## Build #18 — graphics settings + draw-budget knobs (presentation only).
class_name SwarmGfx
extends RefCounted

const QUALITIES := ["high", "medium", "low"]
const RESOLUTIONS := [
	{"id": "native", "label": "Native", "w": 0, "h": 0},
	{"id": "1920x1080", "label": "1920×1080", "w": 1920, "h": 1080},
	{"id": "1280x720", "label": "1280×720", "w": 1280, "h": 720},
	{"id": "960x540", "label": "960×540", "w": 960, "h": 540},
]

const HELP_LINES := [
	"WASD / šipky — kamera",
	"Kolečko — zoom",
	"LMB — gesta",
	"RMB / MMB — posun mapy",
	"Esc — menu",
	"H / ? — nápověda",
	"F1 — demo HUD",
	"1–4 / mezerník — rychlost (demo)",
]

## In-memory cache — never hit disk from draw paths.
static var _cache: Dictionary = {}
static var _cache_ready: bool = false


static func defaults() -> Dictionary:
	return {
		"quality": "high",
		"resolution": "native",
		"fullscreen": false,
	}


static func load_gfx() -> Dictionary:
	if _cache_ready:
		return _cache.duplicate()
	var d: Dictionary = SwarmSave.load_all()
	var out := defaults()
	var q := str(d.get("quality", out.quality)).to_lower()
	if q in QUALITIES:
		out.quality = q
	var res := str(d.get("resolution", out.resolution)).to_lower()
	for r in RESOLUTIONS:
		if res == str(r.id):
			out.resolution = res
			break
	out.fullscreen = bool(d.get("fullscreen", false))
	_cache = out.duplicate()
	_cache_ready = true
	return out.duplicate()


static func save_gfx(quality: String, resolution: String, fullscreen: bool) -> void:
	var q := quality.to_lower()
	if q not in QUALITIES:
		q = "high"
	var res := resolution.to_lower()
	var ok_res := false
	for r in RESOLUTIONS:
		if res == str(r.id):
			ok_res = true
			break
	if not ok_res:
		res = "native"
	_cache = {"quality": q, "resolution": res, "fullscreen": fullscreen}
	_cache_ready = true
	SwarmSave.write_all({"quality": q, "resolution": res, "fullscreen": fullscreen})


static func apply(settings: Dictionary = {}) -> void:
	var s: Dictionary = settings if not settings.is_empty() else load_gfx()
	_cache = {
		"quality": str(s.get("quality", "high")),
		"resolution": str(s.get("resolution", "native")),
		"fullscreen": bool(s.get("fullscreen", false)),
	}
	_cache_ready = true
	var fs: bool = bool(_cache.fullscreen)
	## Web / headless: skip window mode changes.
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res_id := str(_cache.resolution)
		var w := 0
		var h := 0
		for r in RESOLUTIONS:
			if str(r.id) == res_id:
				w = int(r.w)
				h = int(r.h)
				break
		if w > 0 and h > 0:
			DisplayServer.window_set_size(Vector2i(w, h))
			var screen := DisplayServer.screen_get_size()
			DisplayServer.window_set_position(Vector2i(
				maxi(0, (screen.x - w) / 2),
				maxi(0, (screen.y - h) / 2)
			))


static func quality() -> String:
	if not _cache_ready:
		load_gfx()
	return str(_cache.get("quality", "high"))


static func q_level() -> int:
	## 0=high, 1=medium, 2=low
	match quality():
		"medium":
			return 1
		"low":
			return 2
		_:
			return 0


static func ribbon_passes() -> int:
	match q_level():
		1:
			return 2
		2:
			return 1
		_:
			return 4


static func ribbon_resample_step() -> float:
	match q_level():
		1:
			return 10.0
		2:
			return 16.0
		_:
			return 8.0


static func max_hypha_chains() -> int:
	match q_level():
		1:
			return 36
		2:
			return 22
		_:
			return 48


static func ground_overlay_step_mul() -> float:
	match q_level():
		1:
			return 1.45
		2:
			return 2.2
		_:
			return 1.0


static func trail_line_passes() -> int:
	match q_level():
		1:
			return 2
		2:
			return 1
		_:
			return 3


static func trail_blit_every() -> int:
	## Draw feromon sprites every N segments (1 = every).
	match q_level():
		1:
			return 2
		2:
			return 4
		_:
			return 1


static func worker_spacing() -> float:
	match q_level():
		1:
			return 52.0
		2:
			return 72.0
		_:
			return 40.0


static func max_workers_drawn() -> int:
	match q_level():
		1:
			return 48
		2:
			return 28
		_:
			return 80


static func max_builders_drawn() -> int:
	match q_level():
		1:
			return 8
		2:
			return 5
		_:
			return 10


static func decal_count() -> int:
	match q_level():
		1:
			return 28
		2:
			return 12
		_:
			return 48


static func dust_amount() -> int:
	match q_level():
		1:
			return 24
		2:
			return 8
		_:
			return 40


static func mote_amount() -> int:
	## Larger pollen / spore ambient motes (on top of fine dust).
	match q_level():
		1:
			return 16
		2:
			return 6
		_:
			return 28


static func detail_decal_count() -> int:
	## Extra biome detail stamps beyond base decal_count.
	match q_level():
		1:
			return 18
		2:
			return 8
		_:
			return 36


static func glow_enabled() -> bool:
	return q_level() < 2


static func soft_shadows() -> bool:
	return q_level() < 2


static func hyfa_tex_accent() -> bool:
	return q_level() == 0


static func soil_sparse_mod() -> int:
	## Higher = fewer soil/meadow atlas stamps.
	match q_level():
		1:
			return 7
		2:
			return 11
		_:
			return 5


## Iso-space AABB around camera for cheap sprite/ribbon culling.
static func view_bounds(camera: Camera2D, margin: float = 180.0) -> Rect2:
	if camera == null:
		return Rect2(-99999, -99999, 199998, 199998)
	var vp: Vector2 = camera.get_viewport_rect().size
	var z: float = maxf(camera.zoom.x, 0.05)
	var half: Vector2 = vp * 0.5 / z
	var c: Vector2 = camera.position
	return Rect2(c - half - Vector2(margin, margin), half * 2.0 + Vector2(margin, margin) * 2.0)


static func iso_in_view(iso: Vector2, bounds: Rect2) -> bool:
	return bounds.has_point(iso)


static func cycle_quality(cur: String) -> String:
	var i := QUALITIES.find(cur.to_lower())
	if i < 0:
		return "high"
	return QUALITIES[(i + 1) % QUALITIES.size()]


static func cycle_resolution(cur: String) -> String:
	var ids: Array = []
	for r in RESOLUTIONS:
		ids.append(str(r.id))
	var i := ids.find(cur.to_lower())
	if i < 0:
		return "native"
	return str(ids[(i + 1) % ids.size()])


static func resolution_label(id: String) -> String:
	for r in RESOLUTIONS:
		if str(r.id) == id:
			return str(r.label)
	return "Native"


static func quality_label(id: String) -> String:
	match id.to_lower():
		"medium":
			return "Medium"
		"low":
			return "Low"
		_:
			return "High"


static func draw_help(host: CanvasItem, font: Font, vp: Vector2, alpha: float = 0.92) -> void:
	if alpha <= 0.02:
		return
	var panel := Rect2(vp.x * 0.5 - 210.0, vp.y * 0.5 - 150.0, 420.0, 300.0)
	host.draw_rect(panel, Color(0.05, 0.06, 0.05, 0.82 * alpha), true)
	host.draw_rect(panel, Color(0.75, 0.8, 0.7, 0.55 * alpha), false, 1.5)
	var title_col := Color(0.92, 0.94, 0.88, alpha)
	var body_col := Color(0.82, 0.86, 0.8, 0.92 * alpha)
	var f: Font = font if font else ThemeDB.fallback_font
	host.draw_string(f, panel.position + Vector2(24, 36), "Ovládání", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, title_col)
	var y: float = 68.0
	for line in HELP_LINES:
		host.draw_string(f, panel.position + Vector2(24, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, body_col)
		y += 24.0
	host.draw_string(f, panel.position + Vector2(24, panel.size.y - 22.0), "H / ? zavře", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.65, 0.7, 0.62, 0.75 * alpha))
