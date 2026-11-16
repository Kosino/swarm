extends RefCounted
class_name SwarmTheme
## Branded Theme — brass / comb / wing-vein panels + Cinzel titles / Nunito body (OFL).

const CINZEL := "res://fonts/Cinzel-Variable.ttf"
const NUNITO := "res://fonts/Nunito-Variable.ttf"


static func build(rod: String = "mycelium") -> Theme:
	var theme := Theme.new()
	var title := _font(CINZEL)
	var body := _font(NUNITO)
	if title:
		theme.set_font("font", "Label", title)
		theme.set_font("font", "Button", title)
	if body:
		theme.set_font("font", "LineEdit", body)
	theme.set_font_size("font_size", "Label", 15)
	theme.set_font_size("font_size", "Button", 16)

	var panel := StyleBoxFlat.new()
	if rod == "apis":
		panel.bg_color = Color(0.12, 0.09, 0.05, 0.78)
		panel.border_color = Color(0.72, 0.55, 0.28, 0.85)
	else:
		panel.bg_color = Color(0.07, 0.1, 0.06, 0.78)
		panel.border_color = Color(0.42, 0.62, 0.38, 0.75)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 4
	theme.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = panel.border_color.darkened(0.35)
	btn.border_color = panel.border_color
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(5)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", btn)
	var btn_h := btn.duplicate()
	btn_h.bg_color = panel.border_color.darkened(0.15)
	theme.set_stylebox("hover", "Button", btn_h)
	theme.set_color("font_color", "Label", Color(0.92, 0.93, 0.88, 0.95))
	theme.set_color("font_color", "Button", Color(0.95, 0.94, 0.88, 0.95))
	return theme


static func title_font() -> Font:
	return _font(CINZEL)


static func body_font() -> Font:
	return _font(NUNITO)


static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null
