class_name DatsHub
extends Control
## Player home. Hosted modes become available when their server endpoints exist.

signal garage_requested
signal practice_requested
signal account_requested
signal private_requested
signal friends_requested
signal driver_requested

const BACKDROP := preload("res://art/launch_arena.png")
const BOLT := preload("res://art/driver_bolt_full.png")
const NOVA := preload("res://art/driver_nova_full.png")

var panel: PanelContainer
var bolt: TextureRect
var nova: TextureRect
var identity: Label

func setup(profile_name: String, level: int, connected: bool, driver := "bolt") -> void:
	theme = UI.game_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene := TextureRect.new()
	scene.texture = BACKDROP
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scene)
	var shade := ColorRect.new()
	shade.color = Color(.05,.16,.28,.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	UI.decorate(self)
	bolt = _figure(BOLT)
	nova = _figure(NOVA)
	if Parts.DRIVERS.has(driver):
		bolt.texture = load("res://art/driver_"+driver+"_full.png")
		var rivals := Parts.DRIVERS.keys()
		var rival: String = rivals[(rivals.find(driver)+1)%rivals.size()]
		nova.texture = load("res://art/driver_"+rival+"_full.png")
	nova.flip_h = true
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 670
	panel.add_theme_stylebox_override("panel",UI.box(Color(.09,.22,.36,.93),Color("FBD680"),30,3,24))
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	panel.add_child(content)
	var title := UI.label("DATS",56,Color("FFCE59"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	identity = UI.label("%s  •  LEVEL %d" % [profile_name,level],19,Color("D3F1FF"))
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.clip_text = true
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(identity)
	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation",14)
	modes.add_theme_constant_override("v_separation",14)
	content.add_child(modes)
	var garage := UI.mode_tile("GARAGE","Build your champion",UI.ORANGE,"⚙")
	garage.pressed.connect(garage_requested.emit)
	modes.add_child(garage)
	var private_fight := UI.mode_tile("FRIEND FIGHT","Invite by username",UI.SKY,"✦")
	private_fight.disabled = not connected
	private_fight.pressed.connect(private_requested.emit)
	modes.add_child(private_fight)
	var practice := UI.mode_tile("PRACTICE","Test your machine",UI.GREEN,"▶")
	practice.pressed.connect(practice_requested.emit)
	modes.add_child(practice)
	var arena := UI.mode_tile("ARENA","Coming next",UI.PURPLE,"★")
	arena.disabled = true
	modes.add_child(arena)
	var quick := UI.button("FRIENDS  •  INVITE & PLAY",UI.PURPLE,17,Vector2(390,48))
	quick.disabled = not connected
	quick.pressed.connect(friends_requested.emit)
	content.add_child(quick)
	var note := UI.label("Build something brilliant. Then let the sparks fly!",16,Color("C5E7F3"),1)
	note.custom_minimum_size = Vector2(430,26)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var account := UI.button("SETTINGS",Color("4D729D"),20,Vector2(230,52))
	account.pressed.connect(account_requested.emit)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	content.add_child(footer)
	var drivers := UI.button("CHOOSE DRIVER • 6",UI.PURPLE,19,Vector2(300,56))
	drivers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drivers.pressed.connect(driver_requested.emit)
	footer.add_child(drivers)
	account.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(account)
	resized.connect(_layout)
	_layout()
	panel.pivot_offset = panel.size*.5
	panel.scale = Vector2(.95,.95)
	panel.modulate.a = 0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(panel,"scale",Vector2.ONE,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(panel,"modulate:a",1.0,.25)

func _figure(texture: Texture2D) -> TextureRect:
	var figure := TextureRect.new()
	figure.texture = texture
	figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(figure)
	return figure

func _layout() -> void:
	if not is_instance_valid(panel): return
	var w := size.x
	var h := size.y
	panel.size = Vector2(690,minf(590,h*.90))
	panel.position = Vector2((w-panel.size.x)*.5,(h-panel.size.y)*.5)
	var gutter := maxf(0.0,panel.position.x-30.0)
	var bolt_h := minf(h*.75,gutter*float(bolt.texture.get_height())/float(bolt.texture.get_width()))
	var nova_h := minf(h*.75,gutter*float(nova.texture.get_height())/float(nova.texture.get_width()))
	bolt.size = Vector2(bolt_h*float(bolt.texture.get_width())/float(bolt.texture.get_height()),bolt_h)
	nova.size = Vector2(nova_h*float(nova.texture.get_width())/float(nova.texture.get_height()),nova_h)
	bolt.position = Vector2(16.0,h-bolt_h-12.0)
	nova.position = Vector2(w-nova.size.x-16.0,h-nova_h-12.0)

