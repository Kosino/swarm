## MVP autosave / settings — JSON under user://
class_name SwarmSave
extends RefCounted

const PATH := "user://swarm_mvp.json"
const VERSION := 1


static func _empty() -> Dictionary:
	return {
		"version": VERSION,
		"rod": "",
		"time": 0.0,
		"seed": 42,
		"grown": {"apis": false, "mycelium": false},
		"volume": 0.85,
		"muted": false,
		"updated": 0,
	}


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return _empty()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return _empty()
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _empty()
	var d: Dictionary = parsed
	var out := _empty()
	out.rod = str(d.get("rod", ""))
	out.time = float(d.get("time", 0.0))
	out.seed = int(d.get("seed", 42))
	var grown = d.get("grown", {})
	if typeof(grown) == TYPE_DICTIONARY:
		out.grown = {
			"apis": bool(grown.get("apis", false)),
			"mycelium": bool(grown.get("mycelium", false)),
		}
	out.volume = float(d.get("volume", 0.85))
	out.muted = bool(d.get("muted", false))
	out.updated = int(d.get("updated", 0))
	return out


static func write_all(data: Dictionary) -> void:
	var out := load_all()
	for k in data.keys():
		out[k] = data[k]
	out.version = VERSION
	out.updated = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(out))
	f.close()


static func load_settings() -> Dictionary:
	var d := load_all()
	return {"volume": float(d.volume), "muted": bool(d.muted)}


static func save_settings(volume: float, muted: bool) -> void:
	write_all({"volume": volume, "muted": muted})


static func has_continue() -> bool:
	var d := load_all()
	var rod := str(d.rod)
	var t: float = float(d.time)
	return (rod == "apis" or rod == "mycelium") and t > 8.0 and t < 900.0


static func save_progress(rod: String, time: float, seed: int, grown: Dictionary = {}) -> void:
	var payload := {"rod": rod, "time": time, "seed": seed}
	if not grown.is_empty():
		var cur := load_all()
		var g: Dictionary = cur.grown.duplicate(true)
		if bool(grown.get("apis", false)):
			g.apis = true
		if bool(grown.get("mycelium", false)):
			g.mycelium = true
		payload["grown"] = g
	write_all(payload)


static func clear_progress() -> void:
	var d := load_all()
	write_all({"rod": "", "time": 0.0, "seed": int(d.seed)})
