class_name DatsLaunch
extends Control
## Illustrated studio ident followed by a game key-art title screen.

signal finished

const STUDIO_ART := preload("res://art/studio_portal_branded.png")
const TITLE_ART := preload("res://art/launch_key_art.png")

var studio: Control
var hero: Control
var title_crest: Panel
var enter: Button
var _ready_to_enter := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_hero()
	_build_studio()
	resized.connect(_layout)
	_layout()
	_animate_intro()

func _art(texture: Texture2D, parent: Control) -> void:
	var scene := TextureRect.new()
	scene.texture = texture
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scene)

func _build_studio() -> void:
	studio = Control.new()
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(studio)
	_art(STUDIO_ART,studio)
	studio.modulate.a = 0.0

func _build_hero() -> void:
	hero = Control.new()
	hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hero)
	_art(TITLE_ART,hero)
	title_crest = Panel.new()
	title_crest.add_theme_stylebox_override("panel",UI.box(Color(.045,.09,.18,.79),Color(.99,.70,.27),25,4,6))
	hero.add_child(title_crest)
	var title := UI.label("DATS",91,Color(1,.82,.42),13)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_crest.add_child(title)
	var strap := UI.label("BUILD  •  TUNE  •  BATTLE",20,Color(.96,.96,1),5)
	strap.name = "Strap"
	strap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_crest.add_child(strap)
	enter = UI.button("CONTINUE",Color(.9,.41,.11),27,Vector2(275,68))
	enter.size = enter.custom_minimum_size
	enter.disabled = true
	enter.pressed.connect(_enter)
	hero.add_child(enter)
	hero.modulate.a = 0.0

func _layout() -> void:
	if not is_instance_valid(hero) or not is_instance_valid(studio): return
	var w := size.x
	var h := size.y
	title_crest.size = Vector2(w*.31,h*.28)
	title_crest.position = Vector2((w-title_crest.size.x)*.5,h*.10)
	var title: Label = title_crest.get_node("Title")
	title.position = Vector2(0,h*.008)
	title.size = Vector2(title_crest.size.x,h*.18)
	var strap: Label = title_crest.get_node("Strap")
	strap.position = Vector2(0,h*.19)
	strap.size = Vector2(title_crest.size.x,h*.055)
	enter.position = Vector2((w-enter.size.x)*.5,h*.83)

func _animate_intro() -> void:
	var reveal := create_tween()
	reveal.tween_property(studio,"modulate:a",1.0,.5)
	reveal.tween_interval(1.35)
	reveal.tween_property(studio,"modulate:a",0.0,.47)
	reveal.parallel().tween_property(hero,"modulate:a",1.0,.5)
	reveal.tween_callback(func(): studio.hide(); enter.disabled = false; _ready_to_enter = true)

func _enter() -> void:
	if not _ready_to_enter: return
	_ready_to_enter = false
	enter.disabled = true
	var fade := create_tween()
	fade.tween_property(self,"modulate:a",0.0,.26)
	fade.tween_callback(func(): finished.emit(); queue_free())
