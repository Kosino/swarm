## Screen-space keybind help (CanvasLayer child). Build #18.
extends Node2D

const STheme = preload("res://ui/swarm_theme.gd")

var open: bool = false
var _font: Font


func _ready() -> void:
	_font = STheme.body_font()
	visible = false


func set_open(v: bool) -> void:
	open = v
	visible = v
	queue_redraw()


func _process(_dt: float) -> void:
	if open:
		queue_redraw()


func _draw() -> void:
	if not open:
		return
	SwarmGfx.draw_help(self, _font, get_viewport_rect().size)
