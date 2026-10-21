class_name GarageUI
extends Control
## Horizontal parts shelf above a large car workspace; fitting uses Parts validation.
var main
var team := 0
var category := "weapons"
var selected_slot := "front"
var selected_uid := ""
var message := "Drag a part from the top shelf onto a matching socket."
var car: Car
var viewport: SubViewport
var workspace: Control
var drop_zone: GarageDropZone
var socket_buttons := {}
var status: Label
var fight: Button
var remove_button: Button
var parts_scroll: SwipePartsShelf
var shelf_positions := {}
var displayed_category := ""
var spare_picker: OptionButton
var spare_ids: Array = []
var camera: Camera2D
var mechanic: GarageMechanic
var upgrade_open := false
var zoom_feedback := 1.0
var workshop_scene: TextureRect
var revealed_slot := ""
var drag_slot := ""
var drag_uid := ""
var drag_affordable := true
var _drag_visual_alphas := {}
var placement_preview: GaragePlacementPreview
var workspace_pointer := Vector2(-10000,-10000)
var driver_dialog: AcceptDialog
const WORKSHOP := preload("res://art/workshop_background.png")

func setup(owner_node) -> void:
	theme = UI.game_theme()
	main = owner_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rebuild()

func current_build() -> Dictionary:
	return main.builds[team]

func rebuild() -> void:
	if main.player_mode: team = 0
	var pose := {}
	if is_instance_valid(car) and is_instance_valid(car.chassis) and car.team == team and car.build.chassis == current_build().chassis:
		pose = {"position":car.chassis.position,"rotation":car.chassis.rotation,"velocity":car.chassis.linear_velocity,"angular":car.chassis.angular_velocity,"rear":car.build.rear_wheel,"front":car.build.front_wheel}
	if is_instance_valid(parts_scroll) and displayed_category != "":
		shelf_positions[displayed_category] = parts_scroll.scroll_horizontal
	for child in get_children():
		remove_child(child)
		child.queue_free()
	socket_buttons.clear()
	main.builds[team] = main.inventory.synchronize(main.builds[team],main.builds[1-team].get("equipped",{}).values())
	main.inventory.save(main.builds)
	var background := ColorRect.new()
	background.color = Color(.13,.09,.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scene := TextureRect.new()
	workshop_scene=scene
	scene.texture=WORKSHOP
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.modulate=Color(.94,.94,.92)
	scene.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(scene)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation",10)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(UI.label("DATS · WORKSHOP",28,Color(1,.8,.3)))
	for i in (1 if main.player_mode else 2):
		var choice := UI.button("MY CAR" if main.player_mode else ("BLUE BUILD" if i==0 else "RED BUILD"),Battle.TEAM_COLORS[i],16,Vector2(130,40))
		choice.pressed.connect(func(): team=i; selected_uid=""; rebuild())
		top.add_child(choice)
	var account := UI.button("SETTINGS",Color(.25,.38,.45),16,Vector2(140,44))
	account.pressed.connect(main.show_settings)
	top.add_child(account)
	var market := UI.button("MARKET",UI.GREEN,17,Vector2(125,48))
	market.pressed.connect(main.show_market)
	top.add_child(market)
	if main.player_mode:
		var in_lobby: bool = is_instance_valid(main._lobby) and main._lobby.in_garage
		var home := UI.button("BACK TO LOBBY" if in_lobby else "HOME",Color(.27,.39,.55),16,Vector2(160 if in_lobby else 110,44))
		home.pressed.connect(main._show_hub)
		top.add_child(home)
	var wallet := UI.label("GOLD %d · %d PARTS · FUSION %d\nPLAYER Lv %d · XP %d/%d · TIER %d" % [main.inventory.gold,main.inventory.items.size(),main.inventory.fusion_energy,main.inventory.player_level,main.inventory.player_xp,Progression.xp_required(main.inventory.player_level),main.inventory.unlocked_tier()],14,Color(1,.85,.4))
	wallet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(wallet)
	var drawer := InventoryDropZone.new()
	drawer.garage = self
	drawer.custom_minimum_size.y = 190
	drawer.add_theme_stylebox_override("panel",UI.box(Color(.10,.22,.34,.96),Color("6FC8E5"),18,2,10))
	root.add_child(drawer)
	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override("separation",4)
	drawer.add_child(inventory_box)
	var shelf_header := HBoxContainer.new()
	inventory_box.add_child(shelf_header)
	shelf_header.add_child(UI.label("PARTS SHELF  •  SWIPE TO BROWSE  •  DRAG TO FIT",19,Color(1,.85,.4)))
	var filters := HBoxContainer.new()
	filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf_header.add_child(filters)
	for group in ["bodies","weapons","gadgets","wheels"]:
		var tab := UI.button(group.capitalize(),UI.ORANGE if category==group else Color("47648D"),17,Vector2(92,44))
		tab.pressed.connect(func(): category=group; rebuild())
		filters.add_child(tab)
	var supply := UI.button("Supply box · "+("%d FREE" % main.inventory.supply_boxes if main.inventory.supply_boxes > 0 else "500 gold"),UI.PURPLE,15,Vector2(174,44))
	supply.pressed.connect(func(): main.economy("box"))
	shelf_header.add_child(supply)
	var scroll := SwipePartsShelf.new()
	scroll.custom_minimum_size.y = 128
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 12
	inventory_box.add_child(scroll)
	parts_scroll = scroll
	displayed_category = category
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation",8)
	scroll.add_child(cards)
	var table: Dictionary = {"bodies":Parts.CHASSIS,"weapons":Parts.WEAPONS,"gadgets":Parts.GADGETS,"wheels":Parts.WHEELS}[category]
	var ordered: Array=[]
	var older: Array=[]
	for owned in main.inventory.items:
		if owned.id in CatalogueArt.HULLS or owned.id in Catalogue.weapons() or owned.id in Catalogue.gadgets() or owned.id in ["booster","armour_plate","shield"]: ordered.append(owned)
		else: older.append(owned)
	ordered.append_array(older)
	if category=="weapons":
		var control_parts := ordered.filter(func(item):return item.id in ["balloon_launcher","net_launcher","flipper_net"])
		ordered = control_parts+ordered.filter(func(item):return item.id not in ["balloon_launcher","net_launcher","flipper_net"])
	for item in ordered:
		if not table.has(item.id): continue
		var card := PartCard.new()
		card.garage = self
		card.item = item
		if item.uid in current_build().get("equipped",{}).values():
			card.badge = "FITTED HERE"
		elif not main.player_mode and item.uid in main.builds[1-team].get("equipped",{}).values():
			card.badge = "ALSO ON OTHER CAR"
		if not main.inventory.can_use(item, current_build()): card.badge = "TIER %d LOCKED" % int(item.level)
		card.custom_minimum_size = Vector2(153,119)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var data := Parts.rated_data(table[item.id],{"component_stats":{"card":item}},"card")
		var limits := "%d ENERGY" % data.get("energy",0) if category in ["weapons","gadgets"] else "NO ENERGY COST"
		if category=="bodies":
			var count := Parts.equipment_slots({"chassis":item.id,"layout_seed":item.layout_seed,"component_stats":{"chassis":item}}).size()+2
			limits = "%d SLOTS · %d ENERGY" % [count,int(data.energy)+int(item.energy_bonus)]
		card.text = "%s\nLv %d · %s %d\n%s" % [data.name,item.level,"ATK" if category=="weapons" else "HP",data.attack if category=="weapons" else data.durability,limits]
		if category=="weapons" and data.attack==0: card.text="%s\nTier %d · CONTROL\n%.1fs RELOAD · %d ENERGY" % [data.name,item.level,float(data.cooldown),int(data.energy)]
		card.add_theme_font_size_override("font_size",13)
		card.add_theme_stylebox_override("normal",UI.box(Color("315270"),Color("FFCE59") if not item.affinities.is_empty() else Progression.tier_color(int(item.level)),14,2,5))
		card.add_theme_stylebox_override("hover",UI.box(Color("466D8D"),Color("FFCE59"),14,2,5))
		card.add_theme_stylebox_override("pressed",UI.box(Color("25435E"),Color("FFCE59"),14,2,5))
		card.tooltip_text = (card.badge+"\n" if card.badge!="" else "")+data.desc+"\n"+affinity_text(item)
		card.pressed.connect(func(): card_click(item))
		cards.add_child(card)
	scroll.set_deferred("scroll_horizontal",int(shelf_positions.get(category,0)))
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation",12)
	root.add_child(split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.8
	split.add_child(left)
	var details_scroll := ScrollContainer.new()
	details_scroll.custom_minimum_size.x = 335
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 315
	details.add_theme_constant_override("separation",7)
	details_scroll.add_child(details)
	var b := current_build()
	var health := Parts.health_breakdown(b)
	var energy := Parts.energy_report(b)
	var attack := 0.0
	for mount in Parts.equipment_slots(b):
		var id: String = b.get(mount.id, "")
		if mount.type == "attack" and Parts.WEAPONS.has(id):
			attack += Parts.rated_data(Parts.WEAPONS[id], b, mount.id).attack
	details.add_child(UI.label("%s · %d HP" % [Parts.CHASSIS[b.chassis].name.to_upper(),health.total],19,Color(1,.9,.67)))
	var attack_label := UI.label("ATTACK RATING %d" % roundi(attack),17,Color(1,.8,.4))
	attack_label.tooltip_text = "Combined upgraded weapon ratings. Contact weapons deal their rating per second; projectiles deal their rating per hit. Minigun rating is maximum DPS; rounds deal 10%."
	details.add_child(attack_label)
	details.add_child(UI.label("ENERGY %d / %d%s" % [energy.used,energy.capacity,"  OVERLOAD" if not energy.valid else ""],17,Color(1,.8,.4)))
	details.add_child(UI.label("⬡ weapon  ·  □ gadget  ·  ○ wheel",14,Color(.95,.86,.7)))
	var mounts := Parts.equipment_slots(b)
	var attack_count := mounts.filter(func(s):return s.type=="attack").size()
	details.add_child(UI.label("%d ATTACK · %d DEFENCE · 2 WHEELS" % [attack_count,mounts.size()-attack_count],13,Color(.95,.86,.7)))
	workspace = Control.new()
	workspace.custom_minimum_size.y = 175
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(workspace)
	var holder := SubViewportContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workspace.add_child(holder)
	viewport = SubViewport.new()
	viewport.transparent_bg=true
	viewport.size = Vector2i(780,360)
	holder.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var shadow := DrawNode.new(func(ci):
		ci.draw_colored_polygon(Art.circle(Vector2.ZERO,1,48,Vector2(155,10)),Color(.08,.04,.05,.18))
		ci.draw_colored_polygon(Art.circle(Vector2.ZERO,1,48,Vector2(125,5)),Color(.08,.04,.05,.2)))
	world.add_child(shadow)
	var ground := StaticBody2D.new()
	ground.collision_layer = Car.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000,40)
	shape.shape = rect
	shape.position.y = 20
	ground.add_child(shape)
	world.add_child(ground)
	car = Car.new()
	world.add_child(car)
	car.setup(b,team,Vector2(0,-3),Battle.TEAM_COLORS[team],null)
	if not pose.is_empty():
		var origin := car.chassis.position
		var destination: Vector2 = pose.position
		if pose.rear != b.rear_wheel or pose.front != b.front_wheel: destination.y = origin.y
		for body in car._bodies():
			body.position = destination + (body.position-origin).rotated(pose.rotation)
			body.rotation += pose.rotation
			body.linear_velocity = pose.velocity
			body.angular_velocity = pose.angular
		for joint in car.get_children():
			if joint is Joint2D:
				joint.position = destination + (joint.position-origin).rotated(pose.rotation)
				joint.rotation += pose.rotation
	car.driver_actor.hide()
	mechanic = GarageMechanic.new()
	world.add_child(mechanic)
	mechanic.setup(car.driver_id(),car.dir)
	camera = Camera2D.new()
	camera.position = Vector2(0,-75)
	camera.zoom = Vector2(1.7,1.7)
	world.add_child(camera)
	drop_zone = GarageDropZone.new()
	drop_zone.garage = self
	drop_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.add_child(drop_zone)
	var sockets := Parts.equipment_slots(b).duplicate(true)
	for i in 2:
		sockets.append({"id":"rear_wheel" if i==0 else "front_wheel","type":"wheel","point":Parts.CHASSIS[b.chassis].wheels[i][0]})
	for socket in sockets:
		var button := GarageSocket.new()
		button.garage = self
		button.slot = socket.id
		button.socket_type = socket.type
		button.selected = selected_slot==socket.id
		button.occupied = b.get(socket.id,"")!=""
		button.size = Vector2(46,46)
		button.tooltip_text = "%s · %s" % [socket.id,Parts.base_for(b.get(socket.id,"")).get("name","Empty")]
		button.pressed.connect(func(): select_slot(socket.id))
		drop_zone.add_child(button)
		socket_buttons[socket.id] = {"button":button,"point":socket.point}
	placement_preview = GaragePlacementPreview.new()
	placement_preview.garage = self
	drop_zone.add_child(placement_preview)
	var tools := VBoxContainer.new()
	details.add_child(tools)
	var driver := UI.button("CHOOSE DRIVER • "+Parts.DRIVERS[car.driver_id()],UI.SKY,18,Vector2(300,60))
	driver.pressed.connect(show_driver_picker)
	tools.add_child(driver)
	var removable: bool = selected_slot != "chassis" and b.get(selected_slot, "") != ""
	var empty := UI.button("Remove this part · "+Parts.base_for(b.get(selected_slot, "")).get("name", "Empty"),UI.PURPLE,17,Vector2(175,52))
	remove_button = empty
	empty.disabled = not removable
	empty.clip_text = true
	empty.pressed.connect(func(): remove_part(selected_slot))
	tools.add_child(empty)
	var random := UI.button("Random valid build",Color("5478A0"),18,Vector2(170,52))
	random.pressed.connect(random_build)
	tools.add_child(random)
	var inspect := UI.label("%s · %s" % [selected_slot.capitalize().replace("_"," "),Parts.base_for(b.get(selected_slot,"")).get("name","Empty")],15,Color(1,.9,.68))
	details.add_child(inspect)
	_build_upgrade_panel(details)
	status = UI.label(message,14,Color(.85,.85,.95))
	root.add_child(status)
	fight = UI.button(("PRACTICE FIGHT" if main.player_mode else "FIGHT!") if all_builds_valid() else "CHECK ENERGY, TIERS & WHEELS",UI.ORANGE,26,Vector2(340,70))
	fight.disabled = not all_builds_valid()
	fight.tooltip_text = "Your car needs two wheels and parts within its tier and energy. Practice uses a local opponent." if main.player_mode else "Both builds need two wheels, affordable energy, and parts no higher than their chassis tier or your unlocked tier."
	fight.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fight.pressed.connect(main._start_battle)
	root.add_child(fight)

func show_driver_picker() -> void:
	if is_instance_valid(driver_dialog): driver_dialog.queue_free()
	driver_dialog = AcceptDialog.new()
	driver_dialog.title = "CHOOSE YOUR DRIVER • ALL SIX AVAILABLE"
	driver_dialog.theme = UI.game_theme()
	driver_dialog.get_ok_button().text = "CLOSE"
	add_child(driver_dialog)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	driver_dialog.add_child(grid)
	for id in Parts.DRIVERS:
		var picked: bool = current_build().driver==id
		var card := UI.button("",UI.ORANGE if picked else Color("416589"),20,Vector2(190,216))
		card.name = id
		card.pressed.connect(choose_driver.bind(id))
		grid.add_child(card)
		var figure := TextureRect.new()
		figure.texture = load("res://art/driver_"+id+"_full.png")
		figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		figure.position = Vector2(10,8)
		figure.size = Vector2(170,158)
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(figure)
		var caption := UI.label(Parts.DRIVERS[id]+(" • SELECTED" if picked else ""),18)
		caption.position = Vector2(4,177)
		caption.size.x = 182
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption)
	driver_dialog.popup_centered(Vector2i(640,510))

func choose_driver(id: String) -> void:
	DatsAudio.instance().effect("equip")
	if not Parts.DRIVERS.has(id): return
	if is_instance_valid(driver_dialog): driver_dialog.hide(); driver_dialog.queue_free()
	main.builds[team].driver = id
	message = Parts.DRIVERS[id]+" selected."
	rebuild()
	if main.cloud_mode: main.save_cloud()

func _process(_delta: float) -> void:
	if is_instance_valid(car): car.pose_gadgets(_delta)
	if not is_instance_valid(car) or not is_instance_valid(viewport): return
	var car_rect := car_bounds()
	mechanic.position = Vector2(car_rect.position.x - 95.0 if car.dir > 0 else car_rect.end.x + 95.0, -84.0)
	var bounds := model_bounds()
	var model_height := maxf(80,-bounds.position.y)
	var desired_zoom := minf(1.7,minf(float(viewport.size.y)*.80/(model_height+18),float(viewport.size.x)*.85/(bounds.size.x+30)))
	camera.zoom=Vector2.ONE*desired_zoom*zoom_feedback
	camera.position.x=bounds.get_center().x
	camera.position.y=-float(viewport.size.y)*.36/camera.zoom.y
	# Align the physical ground and soft contact shadow with the photographed bench.
	var floor_y: float = workspace.global_position.y+float(viewport.size.y)*.86
	workshop_scene.offset_top=(floor_y-size.y*.687)/.313
	# Keep garage motion within the workspace while allowing suspension and tipping.
	car.chassis.linear_velocity.x *= 0.9
	if absf(car.chassis.position.x)>100: car.chassis.apply_central_force(Vector2(-car.chassis.position.x*60,0))
	for slot in socket_buttons:
		var entry: Dictionary = socket_buttons[slot]
		var world: Vector2 = car.chassis.to_global(car._m(car._px(entry.point)))
		entry.button.position = viewport.get_canvas_transform()*world-entry.button.size*0.5
	update_drag_highlights()

func model_bounds() -> Rect2:
	var bounds := car_bounds()
	if is_instance_valid(mechanic):
		bounds=bounds.expand(mechanic.position+Vector2(-105,-160))
		bounds=bounds.expand(mechanic.position+Vector2(105,90))
	return bounds

func car_bounds() -> Rect2:
	var bounds := Rect2(car.chassis.position,Vector2.ZERO)
	for part in car.parts:
		for node in part.nodes:
			if node is Area2D:
				for shape in node.get_children():
					if shape is CollisionPolygon2D:
						for point in shape.polygon: bounds=bounds.expand(shape.to_global(point))
			if node is CollisionPolygon2D:
				for point in node.polygon: bounds=bounds.expand(node.to_global(point))
			elif node is CollisionShape2D and node.shape is CircleShape2D:
				var radius: float=node.shape.radius
				bounds=bounds.expand(node.global_position-Vector2.ONE*radius)
				bounds=bounds.expand(node.global_position+Vector2.ONE*radius)
	var face: float=Parts.CHASSIS[current_build().chassis].face*Parts.SCALE
	bounds=bounds.expand(car.driver_world_position()+Vector2(-face*.8,-face*1.2))
	bounds=bounds.expand(car.driver_world_position()+Vector2(face*.8,0))
	return bounds

func update_drag_highlights() -> void:
	var payload = get_viewport().gui_get_drag_data()
	var dragging: bool = get_viewport().gui_is_dragging() and payload is Dictionary and payload.has("id")
	var pointer := workspace_pointer
	var in_workspace: bool = Rect2(Vector2.ZERO,workspace.size).has_point(pointer)
	var hover_slot := part_slot_at(pointer) if in_workspace and not dragging else ""
	drag_uid = str(payload.get("uid", "")) if dragging else ""
	drag_slot = drop_slot(pointer,payload) if dragging and in_workspace else ""
	if drag_slot != "" and not can_fit_payload(drag_slot,payload): drag_slot = ""
	if dragging and payload.get("preview") is WeakRef:
		var preview = payload.preview.get_ref()
		if is_instance_valid(preview): preview.visible = drag_slot == ""
	drag_affordable = true
	if drag_slot != "":
		var trial: Dictionary = main.inventory.equip(current_build(),drag_slot,drag_uid)
		drag_affordable = Parts.energy_report(trial).valid
	placement_preview.queue_redraw()
	fade_fitted_parts(dragging)
	for slot in socket_buttons:
		var button: GarageSocket=socket_buttons[slot].button
		var allowed: bool = dragging and can_fit_payload(slot,payload)
		var reveal: bool = slot == revealed_slot or slot == hover_slot or button.is_hovered()
		var snap: bool = dragging and slot == drag_slot
		button.drag_active = dragging
		if button.drop_ready != allowed or button.revealed != reveal or button.snap_target != snap:
			button.drop_ready=allowed; button.revealed=reveal; button.snap_target=snap
			button.queue_redraw()
		button.modulate=Color(1.35,1.2,.7) if allowed else (Color(.5,.5,.5,.45) if dragging else Color.WHITE)
		button.scale=Vector2.ONE*(1.55 if snap else (1.35 if allowed else 1.0))
		button.queue_redraw()
	if dragging and drag_slot != "":
		status.text = ("Release to attach" if drag_affordable else "Energy overload if fitted") + " · " + drag_slot.capitalize().replace("_"," ")
	elif status.text != message: status.text = message

func fade_fitted_parts(dragging: bool) -> void:
	if not dragging:
		for visual in _drag_visual_alphas:
			if is_instance_valid(visual): visual.self_modulate.a = _drag_visual_alphas[visual]
		_drag_visual_alphas.clear()
		return
	for part in car.parts:
		if part.kind == "chassis": continue
		for visual in part.visuals:
			if not is_instance_valid(visual): continue
			if not _drag_visual_alphas.has(visual): _drag_visual_alphas[visual] = visual.self_modulate.a
			visual.self_modulate.a = .22

## Preview and release share ownership, category and tier validation.
func drop_slot(point: Vector2, payload: Dictionary) -> String:
	if not Rect2(Vector2.ZERO,workspace.size).has_point(point): return ""
	if Parts.CHASSIS.has(payload.get("id","")):
		return "chassis" if can_fit_payload("chassis",payload) else ""
	var bounds := car_bounds()
	var canvas := viewport.get_canvas_transform()
	var body_region := Rect2(canvas * bounds.position,bounds.size * camera.zoom).grow(55.0)
	var over_car := body_region.has_point(point)
	var nearest := ""
	var best := INF
	for slot in socket_buttons:
		if not can_fit_payload(slot,payload): continue
		var button: GarageSocket = socket_buttons[slot].button
		var distance := point.distance_to(button.position+button.size*.5)
		if not over_car and distance > 145.0: continue
		# Precise drops replace a mount; broad drops favour an empty one.
		var score := distance
		if distance > 45.0 and current_build().get(slot,"") != "": score += 65.0
		if score < best: best = score; nearest = slot
	return nearest

func can_fit_payload(slot: String, payload: Dictionary) -> bool:
	var item: Dictionary = main.inventory.find_item(str(payload.get("uid","")))
	return not item.is_empty() and compatible(slot,item.id) and main.inventory.can_use(item,current_build()) and main.inventory.copy_available(current_build(),slot,str(item.uid))

func nearest_socket(point: Vector2,id: String) -> String:
	if Parts.CHASSIS.has(id): return "chassis"
	var nearest := ""
	var distance := 145.0
	for slot in socket_buttons:
		if not compatible(slot,id): continue
		var button: GarageSocket = socket_buttons[slot].button
		var center: Vector2 = button.position+button.size*0.5
		var d := point.distance_to(center)
		if d<distance: nearest=slot; distance=d
	return nearest

func compatible(slot: String,id: String) -> bool:
	if slot in ["rear_wheel","front_wheel"]: return Parts.WHEELS.has(id)
	if slot=="chassis": return Parts.CHASSIS.has(id)
	return id in Parts.options_for_mount(current_build().chassis,slot,current_build())

func fit_item(slot: String,uid: String) -> void:
	DatsAudio.instance().effect("equip")
	var item: Dictionary = main.inventory.find_item(uid)
	if not main.inventory.copy_available(current_build(),slot,uid):
		message="This copy is already fitted. Buy another copy or earn one from a supply box."
		rebuild()
		return
	if slot=="" or item.is_empty() or not compatible(slot,item.id):
		message = "This part needs a matching socket."
		rebuild()
		return
	if not main.inventory.can_use(item, current_build()):
		message = "Lv %d needs player level %d and a chassis of at least the same tier." % [int(item.level), (int(item.level)-1)*10+1]
		rebuild()
		return
	main.builds[team] = main.inventory.equip(current_build(),slot,uid)
	selected_slot = slot
	selected_uid = uid
	revealed_slot = ""
	message = "Attached %s to %s." % [Parts.base_for(item.id).name,slot]
	rebuild()

func card_click(item: Dictionary) -> void:
	if is_instance_valid(parts_scroll) and parts_scroll.swipe_suppresses_click(): return
	for slot in current_build().get("equipped", {}):
		if current_build().equipped[slot] == item.uid:
			select_slot(slot)
			return
	if Parts.CHASSIS.has(item.id): fit_item("chassis",item.uid)
	elif slot_for_item(item.id) != "": fit_item(slot_for_item(item.id),item.uid)
	else:
		selected_uid=item.uid
		message="%s selected for upgrading. Select a matching socket to fit it." % Parts.base_for(item.id).name
		rebuild()

func remove_part(slot: String) -> void:
	if slot in ["chassis","driver"] or current_build().get(slot, "") == "": return
	main.builds[team][slot] = ""
	main.builds[team].equipped.erase(slot)
	selected_uid=""
	revealed_slot = ""
	message="Part returned to inventory."
	rebuild()

func select_slot(slot: String) -> void:
	selected_slot = slot
	revealed_slot = slot
	selected_uid = current_build().equipped.get(slot, "")
	message = "%s selected. Use Remove this part to detach it." % Parts.base_for(current_build().get(slot, "")).get("name", "Empty socket")
	rebuild()

func select_part_at(point: Vector2) -> void:
	var slot := part_slot_at(point)
	if slot != "": select_slot(slot)
	else:
		revealed_slot = ""
		update_drag_highlights()

func part_slot_at(point: Vector2) -> String:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = viewport.get_canvas_transform().affine_inverse() * point
	query.collision_mask = Car.HURT_LAYERS[team]
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var closest := ""
	var distance := INF
	for hit in car.get_world_2d().direct_space_state.intersect_point(query, 64):
		if not hit.collider.has_meta("part"): continue
		var part: Car.Part = hit.collider.get_meta("part")
		if part.kind == "chassis":
			if closest == "": closest = "chassis"
			continue
		if socket_buttons.has(part.slot):
			var button: GarageSocket = socket_buttons[part.slot].button
			var d := point.distance_to(button.position + button.size * 0.5)
			if d < distance: distance = d; closest = part.slot
	return closest

func _input(event: InputEvent) -> void:
	if main.cloud.busy: return
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventScreenTouch:
		workspace_pointer = event.position - workspace.global_position
	if event is InputEventScreenTouch and event.pressed and workspace.get_global_rect().has_point(event.position):
		var local: Vector2 = event.position - workspace.global_position
		for slot in socket_buttons:
			if socket_buttons[slot].button.get_rect().has_point(local):
				select_slot(slot)
				return
		select_part_at(local)

func slot_for_item(id: String) -> String:
	if revealed_slot == selected_slot and compatible(selected_slot,id): return selected_slot
	var choices := []
	for slot in socket_buttons:
		if compatible(slot,id): choices.append(slot)
	if choices.is_empty(): return ""
	if id in ["forklift", "repulse", "lifter", "armour_plate", "shield", "booster", "backpedal"]:
		choices.sort_custom(func(a,b):
			var pa: Vector2 = socket_buttons[a].point
			var pb: Vector2 = socket_buttons[b].point
			if id in ["booster","backpedal"]: return pa.x < pb.x
			return pa.x + pa.y*.25 > pb.x + pb.y*.25)
	for slot in choices:
		if current_build().get(slot,"") == "": return slot
	return selected_slot if selected_slot in choices else str(choices[0])

func protected_ids() -> Array:
	var result := []
	for b in main.builds: result.append_array(b.get("equipped",{}).values())
	return result

func all_builds_valid() -> bool:
	for i in (1 if main.player_mode else 2):
		if not main.inventory.build_valid(main.builds[i]): return false
	return true

func affinity_text(item: Dictionary) -> String:
	var lines := []
	for bonus in item.get("affinities",[]):
		lines.append("+%d%% %s when using %s" % [roundi(bonus.percent*100),bonus.stat,bonus.get("chassis",bonus.get("weapon",""))])
	return " · ".join(lines)

func _build_upgrade_panel(parent: Control) -> void:
	var item: Dictionary = main.inventory.find_item(selected_uid)
	if item.is_empty(): item=main.inventory.find_item(current_build().equipped.get(selected_slot,""))
	if item.is_empty():
		parent.add_child(UI.label("Select an equipped part or inventory card to fuse upgrades.",14))
		return
	selected_uid=item.uid
	var toggle := UI.button(("Close upgrades" if upgrade_open else "Upgrade part")+" · "+Parts.base_for(item.id).name+" · Lv %d" % item.level,Color("9C70E8"),17,Vector2(240,52))
	toggle.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	toggle.pressed.connect(func(): upgrade_open=not upgrade_open; rebuild())
	parent.add_child(toggle)
	var copy := UI.button("Buy another copy · %d gold" % Progression.market_price(item.id,int(item.level)),Color(.38,.36,.17),13,Vector2(240,32))
	copy.pressed.connect(func(): main.economy("buy",{"id":item.id,"tier":int(item.level)}))
	parent.add_child(copy)
	if not upgrade_open: return
	var next_tier := mini(5, int(item.level) + 1)
	var can_upgrade: bool = int(item.level) < mini(5,main.inventory.unlocked_tier())
	parent.add_child(UI.label("Tier %d unlocked · next at player Lv %d" % [main.inventory.unlocked_tier(), mini(100, int(item.level)*10+1)],13,Color(1,.85,.5)))
	var buy := UI.button("Buy %s Lv %d · %d gold" % [Parts.base_for(item.id).name, next_tier, Progression.market_price(item.id,next_tier)],Color(.38,.36,.17),13,Vector2(240,32))
	buy.clip_text = true
	buy.disabled = not can_upgrade
	buy.pressed.connect(func(): main.economy("buy",{"id":item.id,"tier":next_tier}))
	parent.add_child(buy)
	parent.add_child(UI.label("FUSE %s · Tier %d · %d combinations\nSame type + same tier. Maximum 3× base rating.\n%s" % [Parts.base_for(item.id).name,item.level,item.get("fusion_count",0),affinity_text(item)],15,Color(1,.85,.5)))
	var row := HBoxContainer.new()
	parent.add_child(row)
	spare_picker=OptionButton.new()
	spare_picker.custom_minimum_size.x=170
	spare_ids=[]
	var protected := protected_ids()
	for spare in main.inventory.items:
		if spare.uid==item.uid or spare.uid in protected or spare.id!=item.id or int(spare.level)!=int(item.level): continue
		spare_picker.add_item("%s · Lv %d" % [Parts.base_for(spare.id).name,spare.level])
		spare_ids.append(spare.uid)
	row.add_child(spare_picker)
	var fuse := UI.button("Fuse · %d energy" % main.inventory.fusion_cost(item),Color(.55,.3,.55),14,Vector2(125,36))
	fuse.disabled=spare_ids.is_empty() or main.inventory.fusion_energy<main.inventory.fusion_cost(item)
	fuse.pressed.connect(func(): main.economy("fuse",{"uid":selected_uid,"spare":spare_ids[spare_picker.selected]}))
	row.add_child(fuse)
	var preview := UI.label("Buy a matching copy in Market to fuse.",14,Color("9EE9C1"))
	parent.add_child(preview)
	if not spare_ids.is_empty():
		var update_preview := func(_index=0):
			var spare: Dictionary=main.inventory.find_item(spare_ids[spare_picker.selected])
			var rating: float=Progression.base_rating(item.id,int(item.level))+Progression.fusion_value(item,spare)
			var label: String="ATK" if Parts.WEAPONS.has(item.id) and Parts.WEAPONS[item.id].attack>0 else "HP"
			preview.text="After fusion: %s %d • Tier %d stays unchanged\nSpare is consumed. Car energy capacity stays unchanged." % [label,rating,item.level]
			if Parts.WEAPONS.has(item.id) and Parts.WEAPONS[item.id].attack==0:
				var fused: Dictionary=item.duplicate(true)
				fused.durability_bonus=Progression.fusion_value(item,spare)
				var rated: Dictionary=Parts.rated_data(Parts.WEAPONS[item.id],{"component_stats":{"card":fused}},"card")
				preview.text="After fusion: %.1fs reload • Tier %d unchanged\nSpare is consumed. No direct damage is added." % [rated.cooldown,item.level]
		spare_picker.item_selected.connect(update_preview)
		update_preview.call()
	var boxes := VBoxContainer.new()
	parent.add_child(boxes)
	for kind in ["attack","health","power"]:
		var button := UI.button("%s +%d (%d)" % [kind.capitalize(),1 if kind=="power" else (5 if kind=="attack" else 25),main.inventory.toolboxes[kind]],Color(.28,.4,.42),14,Vector2(135,31))
		button.pressed.connect(func(): main.economy("toolbox",{"uid":selected_uid,"kind":kind}))
		boxes.add_child(button)

func refresh_stats() -> void:
	for i in main.builds.size(): main.builds[i]=main.inventory.synchronize(main.builds[i])
	rebuild()

func random_build() -> void:
	var b := current_build()
	for socket in Parts.equipment_slots(b): b[socket.id]=""; b.equipped.erase(socket.id)
	for socket in Parts.equipment_slots(b):
		var candidates: Array = main.inventory.items.filter(func(item): return compatible(socket.id,item.id) and main.inventory.can_use(item,b))
		if candidates.is_empty(): continue
		var item: Dictionary = candidates.pick_random()
		var trial: Dictionary = main.inventory.equip(b,socket.id,item.uid)
		if Parts.energy_report(trial).valid: b=trial
	main.builds[team]=b
	message="Random build stays within the energy budget."
	rebuild()
