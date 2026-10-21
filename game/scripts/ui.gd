class_name UI
extends RefCounted
## Shared styling for menus and HUD.
const ROUND_FONT := preload("res://art/fonts/Fredoka.ttf")
const INK := Color("25354D")
const SKY := Color("23B9E7")
const ORANGE := Color("FF9638")
const GREEN := Color("68C647")
const PURPLE := Color("9C70E8")
static var textures := {}
static var round_type: FontVariation

static func font() -> Font:
	if round_type == null:
		round_type = FontVariation.new()
		round_type.base_font = ROUND_FONT
		round_type.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):570}
	return round_type

static func button_skin(accent: Color, pressed := false) -> StyleBoxTexture:
	var key := accent.to_html()+str(pressed)
	if not textures.has(key):
		var top := accent.lightened(.22).to_html(false)
		var bottom := accent.darkened(.06).to_html(false)
		var edge := accent.darkened(.43).to_html(false)
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="80"><defs><linearGradient id="a" x2="0" y2="1"><stop stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><rect x="2" y="8" width="252" height="70" rx="19" fill="#%s"/><rect x="2" y="2" width="252" height="68" rx="18" fill="url(#a)" stroke="#%s" stroke-width="3"/><path d="M24 7H232Q247 7 247 22V29Q128 45 9 29V22Q9 7 24 7" fill="white" opacity=".15"/><path d="M218 10l-17 51h12l17-51z" fill="white" opacity=".12"/></svg>' % [top,bottom,edge,edge]
		var image := Image.new()
		image.load_svg_from_string(svg)
		textures[key] = ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = textures[key]
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,20)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 9 if pressed else 5
	style.content_margin_bottom = 5 if pressed else 9
	return style

static func game_theme() -> Theme:
	var result := Theme.new()
	result.default_font = font()
	result.default_font_size = 18
	for state in ["normal","hover","pressed"]:
		result.set_stylebox(state,"Button",button_skin(SKY,state=="pressed"))
	result.set_stylebox("disabled","Button",button_skin(Color("8695AD")))
	result.set_color("font_color","Button",Color.WHITE)
	result.set_color("font_outline_color","Button",INK)
	result.set_constant("outline_size","Button",1)
	result.set_stylebox("normal","LineEdit",box(Color("FCF5DC"),Color("5CA4C7"),14,2,14))
	result.set_stylebox("focus","LineEdit",box(Color.WHITE,Color("FFBA44"),14,3,14))
	result.set_color("font_color","LineEdit",INK)
	result.set_color("font_placeholder_color","LineEdit",Color("65758D"))
	result.set_color("caret_color","LineEdit",INK)
	result.set_color("selection_color","LineEdit",Color("9CDCF5"))
	result.set_stylebox("panel","AcceptDialog",box(Color("203C5E"),Color("FFD374"),24,3,22))
	return result

static func decorate(parent: Control) -> void:
	var sparkle := DrawNode.new(func(ci):
		for n in 14:
			var p := Vector2(fmod(71+n*197.0,parent.size.x),fmod(97+n*113.0,parent.size.y))
			var r := 3.0+float(n%3)*2
			ci.draw_line(p-Vector2(r,0),p+Vector2(r,0),Color(1,.9,.57,.25),2)
			ci.draw_line(p-Vector2(0,r),p+Vector2(0,r),Color(1,.9,.57,.25),2))
	parent.add_child(sparkle)
	parent.resized.connect(sparkle.queue_redraw)

static func mode_tile(title: String, subtitle: String, accent: Color, symbol: String) -> Button:
	var b := button("",accent,24,Vector2(300,112))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := label(symbol,42,Color("FFF1C8"),2)
	icon.position = Vector2(18,18)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var name := label(title,27,Color.WHITE,2)
	name.position = Vector2(78,19)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name)
	var detail := label(subtitle,16,Color("FFF1DB"),1)
	detail.position = Vector2(78,58)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(detail)
	return b


static func box(bg: Color, border := Art.INK, radius := 14, border_w := 3, margin := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s


static func button(text: String, accent: Color, font_size := 24, min_size := Vector2(170, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): DatsAudio.instance().effect("ui_click"))
	b.custom_minimum_size = Vector2(min_size.x,maxf(56,min_size.y)) if min_size.y>=44 else min_size
	b.add_theme_font_override("font",font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.85))
	b.add_theme_color_override("font_outline_color", Art.INK)
	b.add_theme_constant_override("outline_size", 1)
	var normal := button_skin(accent)
	var hover := button_skin(accent.lightened(.12))
	var pressed := button_skin(accent.darkened(.08),true)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled",button_skin(Color("74869E")))
	b.add_theme_color_override("font_disabled_color",Color("E0E6EF"))
	var focus := box(Color(0,0,0,0),Color("FFF1AF"),18,3,0)
	focus.shadow_size = 0
	b.add_theme_stylebox_override("focus", focus)
	b.mouse_entered.connect(func():
		if not b.disabled: b.modulate = Color(1.08,1.08,1.08))
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
	return b


static func label(text: String, size: int, color := Color.WHITE, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = mini(outline,3 if size>=40 else 1)
	ls.outline_color = Art.INK
	ls.shadow_size = 0
	l.label_settings = ls
	return l


static func picker_button(text: String) -> Button:
	var result := button(text, Color(0.3, 0.26, 0.45), 18, Vector2(46, 32))
	for state in ["normal", "hover", "pressed"]:
		var style: StyleBoxTexture = result.get_theme_stylebox(state).duplicate()
		style.set_content_margin_all(3)
		result.add_theme_stylebox_override(state, style)
	return result


## A round driver portrait with a coloured ring.
static func portrait(driver: String, color: Color, size := 64.0, mirror := false) -> Control:
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.add_theme_stylebox_override("panel", box(color.darkened(0.2), Art.INK, int(size / 2), 3, 0))
	var face := TextureRect.new()
	face.texture = Sprites.tex("driver_" + driver)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.flip_h = mirror
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 4
	face.offset_top = 4
	face.offset_right = -4
	face.offset_bottom = -4
	holder.add_child(face)
	var ring := Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = color
	rs.set_border_width_all(4)
	rs.set_corner_radius_all(int(size / 2))
	ring.add_theme_stylebox_override("panel", rs)
	holder.add_child(ring)
	return holder
