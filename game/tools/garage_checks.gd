extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func settle() -> void:
	for i in 5: await process_frame
func find_card(node: Node,id: String) -> PartCard:
	if node is PartCard and node.item.id==id: return node
	for child in node.get_children():
		var card := find_card(child,id)
		if card: return card
	return null
func mouse_move(point: Vector2,relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point
	event.global_position=point
	event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)
func mouse_button(point: Vector2,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	root.push_input(event,true)
func checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	main.inventory.persistence_enabled=false
	var garage: GarageUI = main._garage
	check(garage.parts_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO and garage.parts_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"owned parts scroll horizontally across the top")
	check(garage.parts_scroll.get_global_rect().end.y<=garage.workspace.get_global_rect().position.y,"parts shelf sits above car and drag sockets")
	check(garage.mechanic.driver_id==garage.car.driver_id() and is_instance_valid(garage.mechanic.full_body) and not garage.car.driver_actor.visible,"selected driver stands beside the car during garage work")
	check(garage.mechanic.position.x<garage.car_bounds().position.x,"blue driver stands outside the car silhouette")
	check(garage.socket_buttons.front.button.socket_type=="attack" and garage.socket_buttons.front_wheel.button.socket_type=="wheel","machined mounts retain distinct weapon and wheel shapes")
	var item: Dictionary = main.inventory.acquire("laser",false)
	garage.fit_item("front",item.uid)
	await settle()
	check(main.builds[0].front=="laser","inventory weapon attaches to a compatible hex socket")
	check(garage.car.weapon_parts()[0].attack_rating==100,"garage preview uses the equipped item rating")
	var shield: Dictionary = main.inventory.acquire("shield",false)
	garage.fit_item("front",shield.uid)
	check(main.builds[0].front=="laser","gadget cannot replace a weapon in a hex socket")
	var rocket: Dictionary = main.inventory.acquire("double_rocket",false)
	var body: Dictionary = main.inventory.acquire("classic",false)
	while Catalogue.layout("classic",int(body.layout_seed)).size()<3: body.layout_seed+=1
	garage.fit_item("chassis",body.uid)
	await settle()
	body.energy_bonus=-9
	garage.fit_item("top",rocket.uid)
	await settle()
	check(not Parts.energy_report(main.builds[0]).valid and garage.fight.disabled,"over-budget blueprint visibly locks Fight")
	body.energy_bonus=0
	garage.remove_part("top")
	await settle()
	check(Parts.energy_report(main.builds[0]).valid and not garage.fight.disabled,"removing a part restores an affordable build")
	var entry: Dictionary = garage.socket_buttons.front
	var drop: Vector2 = entry.button.position+entry.button.size*0.5
	check(garage.nearest_socket(drop,"short_sword")=="front","screen-to-world drag finds the nearest compatible socket")
	check(garage.nearest_socket(drop,"shield")!="front","drag lookup rejects incompatible socket shapes")
	garage.drop_zone._drop_data(drop,{"id":"laser","uid":item.uid})
	await settle()
	check(main.builds[0].equipped.front==item.uid,"drop handler attaches the owned item instance")
	check(garage.fight.get_global_rect().end.y<=root.get_visible_rect().end.y,"Fight and upgrade controls fit at 1280 by 720")
	check(not garage.car.chassis.freeze,"garage leaves suspension and chassis physics active")
	var spare: Dictionary = main.inventory.acquire("stinger",false)
	garage.selected_uid=item.uid
	var old_gold: int = main.inventory.gold
	main.inventory.player_level=11
	main.inventory.fuse(item.uid,spare.uid,garage.protected_ids())
	garage.refresh_stats()
	await settle()
	check(item.level==2 and main.inventory.find_item(spare.uid).is_empty() and main.inventory.gold<old_gold,"fusion consumes spare and gold and increases target level")
	check(garage.car.weapon_parts()[0].attack_rating>100,"fused attack carries into the actual assembled car")
	check(main.inventory.fuse(item.uid,main.builds[0].equipped.chassis,garage.protected_ids()).begins_with("Equipped"),"fusion protects equipped parts")
	var card := find_card(garage,"minigun")
	var start := card.get_global_rect().get_center()
	var target: Vector2 = garage.socket_buttons.front.button.get_global_rect().get_center()
	mouse_move(start,Vector2.ZERO)
	mouse_button(start,true)
	mouse_move(start+Vector2(-40,0),Vector2(-40,0))
	await settle()
	check(root.gui_is_dragging(),"native mouse gesture starts an inventory drag")
	garage.update_drag_highlights()
	check(garage.socket_buttons.front.button.modulate.a==1 and garage.socket_buttons.front_wheel.button.modulate.a<.5,"drag illuminates compatible sockets and dims incompatible wheel mounts")
	check(garage.socket_buttons.front.button.icon_visible() and not garage.socket_buttons.front_wheel.button.icon_visible(),"only compatible mounts remain visible, including occupied ones")
	check(garage.car.weapon_parts()[0].visuals[0].self_modulate.a < .3,"fitted equipment fades during dragging")
	target = garage.socket_buttons.front.button.get_global_rect().get_center()
	mouse_move(target,target-start)
	await settle()
	mouse_button(target,false)
	await settle()
	check(main.builds[0].front=="minigun","native drag and release snaps the weapon onto its hex socket")
	check(garage.car.weapon_parts()[0].visuals[0].self_modulate.a == 1,"fitted art restores after release")
	var equipped: GarageSocket = garage.socket_buttons.front.button
	start=equipped.get_global_rect().get_center()
	card=find_card(garage,"minigun")
	target=card.get_global_rect().get_center()
	mouse_move(start,Vector2.ZERO)
	mouse_button(start,true)
	mouse_move(start+Vector2(40,0),Vector2(40,0))
	await settle()
	mouse_move(target,target-start)
	await settle()
	mouse_button(target,false)
	await settle()
	check(main.builds[0].front=="","native drag returns an equipped part to inventory")
	card=find_card(garage,"minigun")
	start=card.get_global_rect().get_center()
	target=garage.socket_buttons.front.button.get_global_rect().get_center()+Vector2(110,-30)
	mouse_move(start,Vector2.ZERO)
	mouse_button(start,true)
	mouse_move(start+Vector2(-40,0),Vector2(-40,0))
	await settle()
	mouse_move(target,target-start)
	await settle()
	check(garage.drag_slot=="front","finger-sized miss still previews the intended compatible mount")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../screenshots/touch_fitting_preview.png")
	mouse_button(target,false)
	await settle()
	check(main.builds[0].front=="minigun","release more than 100 pixels from mount fits on the first drop")
	garage.upgrade_open=true
	garage.rebuild()
	await settle()
	check(garage.fight.get_global_rect().end.y<=root.get_visible_rect().end.y,"expanded fusion and toolbox controls keep Fight visible")
	var titan: Dictionary=main.inventory.acquire("titan",false)
	garage.fit_item("chassis",titan.uid)
	await settle()
	var bounds := garage.model_bounds()
	var head: Vector2=garage.viewport.get_canvas_transform()*bounds.position
	var feet: Vector2=garage.viewport.get_canvas_transform()*bounds.end
	check(head.y>=0 and feet.y<=garage.viewport.size.y,"tall Titan chassis fits fully even with upgrade controls expanded")
	garage.parts_scroll.scroll_horizontal = 220
	var remembered := garage.parts_scroll.scroll_horizontal
	garage.category="gadgets"
	garage.rebuild()
	await settle()
	garage.parts_scroll.scroll_horizontal = 100
	garage.category="weapons"
	garage.rebuild()
	await settle()
	check(remembered>0 and garage.parts_scroll.scroll_horizontal==remembered,"each shelf category restores its own horizontal scroll position")
	garage.team=1
	garage.rebuild()
	await settle()
	check(garage.mechanic.position.x>garage.car_bounds().end.x and garage.mechanic.driver_id==garage.car.driver_id(),"red build has its selected mechanic beside the rear of the car")
	print("GARAGE CHECKS: %d failures" % failures)
	quit(1 if failures else 0)
