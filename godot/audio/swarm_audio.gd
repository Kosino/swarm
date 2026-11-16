## Procedural CC0-style tones + per-Rod ambient. No sample packs / no speech.
extends Node

var volume: float = 0.85
var muted: bool = false

var _players: Array = []
var _ambient: AudioStreamPlayer
var _ambient_rod: String = ""
var _menu_blend: float = 0.5
var _t: float = 0.0


func _ready() -> void:
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Master"
	add_child(_ambient)
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	var s: Dictionary = SwarmSave.load_settings()
	volume = float(s.get("volume", 0.85))
	muted = bool(s.get("muted", false))
	_apply_master()


func _process(dt: float) -> void:
	_t += dt


func effective() -> float:
	return 0.0 if muted else clampf(volume, 0.0, 1.0)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	if volume > 0.02:
		muted = false
	_apply_master()
	SwarmSave.save_settings(volume, muted)


func cycle_volume() -> void:
	## Icon-only control: mute → 33% → 66% → 100% → mute.
	if muted or volume < 0.05:
		muted = false
		volume = 0.33
	elif volume < 0.5:
		volume = 0.66
	elif volume < 0.85:
		volume = 1.0
	else:
		muted = true
		volume = 0.0
	_apply_master()
	SwarmSave.save_settings(volume, muted)


func toggle_mute() -> void:
	muted = not muted
	if not muted and volume < 0.05:
		volume = 0.66
	_apply_master()
	SwarmSave.save_settings(volume, muted)


func _apply_master() -> void:
	var db: float = -80.0 if effective() <= 0.001 else linear_to_db(effective())
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	if _ambient.playing:
		_ambient.volume_db = -8.0


func set_ambient(rod: String) -> void:
	## rod: "", "apis", "mycelium", "menu"
	if rod == _ambient_rod and _ambient.playing:
		return
	_ambient_rod = rod
	_ambient.stop()
	if rod == "" or effective() <= 0.001:
		return
	var stream: AudioStream = _make_ambient(rod)
	_ambient.stream = stream
	_ambient.volume_db = -10.0
	_ambient.play()


func play_dum(big: bool = false, soft: bool = false) -> void:
	if effective() <= 0.001:
		return
	var freq: float = 52.0 if big else (108.0 * 0.92 if soft else 108.0)
	var peak: float = 0.22 if big else (0.09 if soft else 0.14)
	var dur: float = 0.28 if not big else 0.34
	_play_tone(freq, dur, peak, "sine", 420.0 if not soft else 360.0, true)


func play_bzz() -> void:
	if effective() <= 0.001:
		return
	_play_tone(180.0, 0.18, 0.045, "triangle", 280.0, true, true)


func play_chime() -> void:
	if effective() <= 0.001:
		return
	_play_tone(520.0, 0.35, 0.06, "sine", 1400.0, false)


func play_soft(kind: String) -> void:
	if effective() <= 0.001:
		return
	match kind:
		"bubble":
			_play_tone(140.0, 0.42, 0.08, "sine", 480.0, true)
		"puff":
			_play_tone(70.0, 0.28, 0.06, "triangle", 320.0, true)
		"rain":
			_play_tone(220.0, 0.55, 0.045, "triangle", 900.0, true)
		"beat":
			_play_tone(58.0, 0.5, 0.1, "sine", 280.0, true)
		"hiss":
			_play_tone(310.0, 0.22, 0.05, "sawtooth", 700.0, true)
		"open":
			_play_tone(180.0, 0.32, 0.06, "sine", 600.0, true)
		"copper":
			_play_tone(96.0, 0.45, 0.09, "triangle", 420.0, true)
		"dual":
			_play_tone(160.0, 0.4, 0.05, "triangle", 500.0, true)
			_play_tone(210.0, 0.4, 0.04, "sine", 700.0, true)
		"chord":
			_play_tone(110.0, 0.55, 0.07, "sine", 400.0, true)
			_play_tone(165.0, 0.55, 0.05, "sine", 500.0, true)
			_play_tone(220.0, 0.55, 0.04, "sine", 600.0, true)
		"wind":
			_play_tone(55.0, 0.6, 0.055, "sawtooth", 280.0, true)
		"clean":
			_play_tone(280.0, 0.45, 0.07, "sine", 900.0, false)
		"gesture":
			_play_tone(240.0, 0.12, 0.035, "sine", 800.0, true)
		_:
			_play_tone(120.0, 0.3, 0.05, "sine", 500.0, true)


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func _play_tone(
	freq: float, dur: float, peak: float, wave: String, lp: float, fall: bool, band: bool = false
) -> void:
	var stream := _synth(freq, dur, peak, wave, lp, fall, band)
	var p := _free_player()
	p.stream = stream
	p.volume_db = 0.0
	p.play()


func _synth(
	freq: float, dur: float, peak: float, wave: String, lp: float, fall: bool, band: bool
) -> AudioStreamWAV:
	var hz := 22050
	var n: int = int(ceil(dur * float(hz))) + 1
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var two_pi := TAU / float(hz)
	## Lightweight 1-pole lowpass stand-in (envelope shapes the tone enough for MVP).
	for i in range(n):
		var t: float = float(i) / float(hz)
		var env: float = 0.0
		if t < 0.02:
			env = peak * (t / 0.02)
		else:
			var u: float = (t - 0.02) / maxf(0.001, dur - 0.02)
			env = peak * exp(-3.2 * u)
		var s: float = 0.0
		match wave:
			"triangle":
				var tri: float = fmod(phase / PI, 2.0)
				s = (tri if tri <= 1.0 else 2.0 - tri) * 2.0 - 1.0
			"sawtooth":
				s = fmod(phase / PI, 2.0) - 1.0
			_:
				s = sin(phase)
		if band:
			s *= 0.7 + 0.3 * sin(phase * 0.37)
		var f_now: float = freq
		if fall:
			f_now = maxf(30.0, freq * (1.0 - 0.45 * minf(1.0, t / dur)))
		phase += two_pi * f_now
		## Cheap spectral tilt using lp as brightness scaler.
		var bright: float = clampf(lp / 1200.0, 0.25, 1.2)
		var sample: int = int(clampf(s * env * bright, -1.0, 1.0) * 32000.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = hz
	stream.stereo = false
	stream.data = data
	return stream


func _make_ambient(rod: String) -> AudioStreamWAV:
	var hz := 22050
	var secs := 3.0
	var n: int = int(secs * hz)
	var data := PackedByteArray()
	data.resize(n * 2)
	var base: float = 72.0
	var hum2: float = 108.0
	if rod == "apis":
		base = 96.0
		hum2 = 180.0
	elif rod == "menu":
		base = 84.0
		hum2 = 140.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 if rod != "apis" else 77
	for i in range(n):
		var t: float = float(i) / float(hz)
		var s: float = 0.0
		if rod == "apis":
			s = 0.22 * sin(TAU * base * t)
			s += 0.12 * sin(TAU * hum2 * t + 0.4)
			s += 0.04 * sin(TAU * (hum2 * 1.5) * t)
			## Soft wing shimmer.
			s *= 0.85 + 0.15 * sin(TAU * 4.5 * t)
		elif rod == "mycelium":
			s = 0.2 * sin(TAU * base * t)
			s += 0.1 * sin(TAU * (base * 0.5) * t)
			## Occasional drip tick.
			var drip: float = fmod(t * 0.7 + 0.15, 1.0)
			if drip < 0.035:
				s += 0.18 * sin(TAU * 420.0 * t) * (1.0 - drip / 0.035)
		else:
			s = 0.14 * sin(TAU * base * t) + 0.1 * sin(TAU * hum2 * t)
			s += 0.05 * sin(TAU * 52.0 * t)
		s += (rng.randf() - 0.5) * 0.02
		## Loop-friendly fade edges.
		var edge: float = minf(t, secs - t)
		var gate: float = clampf(edge / 0.08, 0.0, 1.0)
		var sample: int = int(clampf(s * 0.35 * gate, -1.0, 1.0) * 28000.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = hz
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	stream.data = data
	return stream
