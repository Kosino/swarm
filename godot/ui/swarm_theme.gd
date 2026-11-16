extends RefCounted
class_name SwarmTheme
## Branded Theme — pro_v3 9-slice / buttons when present, else brass/comb flats + Cinzel/Nunito (OFL).

const CINZEL := "res://fonts/Cinzel-Variable.ttf"
const NUNITO := "res://fonts/Nunito-Variable.ttf"
const PANEL_TEX := "res://art/pro_v3/ui/panel_9slice.png"
const BTN_NORMAL := "res://art/pro_v3/ui/btn_normal.png"
const BTN_HOVER := "res://art/pro_v3/ui/btn_hover.png"
const BTN_PRESSED := "res://art/pro_v3/ui/btn_pressed.png"


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

	var panel: StyleBox = _panel_style(rod)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	var btn_n := _btn_style(BTN_NORMAL, rod, 0.0)
	var btn_h := _btn_style(BTN_HOVER, rod, 0.15)
	var btn_p := _btn_style(BTN_PRESSED, rod, 0.25)
	theme.set_stylebox("normal", "Button", btn_n)
	theme.set_stylebox("hover", "Button", btn_h)
	theme.set_stylebox("pressed", "Button", btn_p)
	theme.set_color("font_color", "Label", Color(0.92, 0.93, 0.88, 0.95))
	theme.set_color("font_color", "Button", Color(0.95, 0.94, 0.88, 0.95))
	return theme


static func _panel_style(rod: String) -> StyleBox:
	if ResourceLoader.exists(PANEL_TEX) or FileAccess.file_exists(PANEL_TEX):
		var tex: Texture2D = load(PANEL_TEX) as Texture2D
		if tex != null:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			## Art Pipeline 9-slice margins: L/T/R/B = 102/74/74/74.
			sb.texture_margin_left = 102
			sb.texture_margin_top = 74
			sb.texture_margin_right = 74
			sb.texture_margin_bottom = 74
			sb.content_margin_left = 18
			sb.content_margin_right = 18
			sb.content_margin_top = 14
			sb.content_margin_bottom = 14
			sb.modulate_color = Color(0.92, 1.0, 0.9, 0.92) if rod != "apis" else Color(1.0, 0.95, 0.85, 0.92)
			return sb
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
	return panel


static func _btn_style(path: String, rod: String, darken: float) -> StyleBox:
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			## Art Pipeline button 9-slice: L/T/R/B = 28/16/28/16.
			sb.texture_margin_left = 28
			sb.texture_margin_top = 16
			sb.texture_margin_right = 28
			sb.texture_margin_bottom = 16
			sb.content_margin_left = 18
			sb.content_margin_right = 18
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			return sb
	var btn := StyleBoxFlat.new()
	var border := Color(0.72, 0.55, 0.28, 0.85) if rod == "apis" else Color(0.42, 0.62, 0.38, 0.75)
	btn.bg_color = border.darkened(0.35 + darken)
	btn.border_color = border
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(5)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	return btn


static func title_font() -> Font:
	return _font(CINZEL)


static func body_font() -> Font:
	return _font(NUNITO)


static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return null
