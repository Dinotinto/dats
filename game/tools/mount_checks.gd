extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func settle() -> void:
	for i in 6:
		await physics_frame
		await process_frame
func motion(point: Vector2, relative := Vector2.ZERO, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point; event.global_position=point; event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)
func click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	root.push_input(event,true)
func find_card(node: Node,id: String) -> PartCard:
	if node is PartCard and node.item.id==id: return node
	for child in node.get_children():
		var card := find_card(child,id)
		if card: return card
	return null
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../screenshots/"+name+".png")
func checks() -> void:
	var layout := Parts.equipment_slots({"chassis":"titan","component_stats":{"chassis":{"level":4}}})
	check(layout.filter(func(s):return s.type=="attack").size()==4 and layout.filter(func(s):return s.type=="gadget").size()==3,"Titan has four attack and three defence/gadget slots")
	var inv := Inventory.new()
	inv.persistence_enabled=false
	inv.starter(true)
	var titan := inv.acquire("titan",false)
	titan.level=4
	inv.player_level=31
	var rocket := inv.acquire("rocket",false)
	var lift := inv.acquire("forklift",false)
	var b := inv.synchronize({"chassis":"titan","wheels":"rubber_medium","equipped":{"chassis":titan.uid}})
	for socket in layout: b=inv.equip(b,socket.id,inv.acquire("rocket",false).uid if socket.type=="attack" else lift.uid)
	check(b.component_stats.size()==10 and Parts.energy_report(b).used==14 and inv.build_valid(b),"all seven equipment mounts preserve item ratings and contribute to energy validation")
	var machine := Car.new()
	root.add_child(machine)
	machine.setup(b,0,Vector2.ZERO,Color.WHITE,null)
	machine.freeze_all()
	check(machine.weapon_parts().size()==4 and machine.parts.filter(func(p):return p.id=="forklift").size()==3,"physics assembles four weapons and three real articulated forklifts")
	var front: Vector2=machine._px(Parts.mount_point("titan","defence_front",b))
	check(front.x>0 and front.y>-25,"Titan front defence mount sits low on its front bumper")
	var migrated := b.duplicate(true)
	migrated.chassis="classic"
	migrated.component_stats.chassis.level=1
	migrated=Parts.normalize_build(migrated)
	check(migrated.attack3=="" and migrated.attack4=="" and migrated.defence_front=="" and not migrated.equipped.has("attack3"),"changing chassis clears unsupported extra mounts without losing inventory parts")
	machine.queue_free()
	for id in ["wedge","ram"]:
		var car := Car.new()
		root.add_child(car)
		car.setup({"chassis":id,"wheels":"rubber_medium","defence":"forklift"},0,Vector2.ZERO,Color.WHITE,null)
		car.freeze_all()
		check(car.parts.any(func(p):return p.id=="forklift" and p.slot=="defence" and p.body!=car.chassis),id+" front defence slot fits an articulated forklift")
		car.queue_free()
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	main.inventory.persistence_enabled=false
	var garage: GarageUI=main._garage
	motion(Vector2(10,10))
	await settle()
	check(not garage.socket_buttons.front.button.icon_visible() and not garage.socket_buttons.front_wheel.button.icon_visible(),"occupied attack and wheel icons are hidden while idle")
	garage.remove_part("front")
	await settle()
	check(garage.socket_buttons.front.button.icon_visible(),"removing a part immediately reveals the empty socket")
	var card := find_card(garage,"minigun")
	var start := card.get_global_rect().get_center()
	motion(start)
	click(start,true)
	motion(start+Vector2(0,40),Vector2(0,40),true)
	await settle()
	var target: Vector2=garage.socket_buttons.front.button.get_global_rect().get_center()
	motion(target,target-start,true)
	await settle()
	check(root.gui_is_dragging() and garage.drag_slot=="front" and garage.socket_buttons.front.button.snap_target,"native drag finds and highlights the precise matching mount")
	check(garage.placement_preview.visible and not root.gui_get_drag_data().preview.get_ref().visible,"drag switches from a floating card to an anchored part preview")
	await shot("mount_snap_preview")
	click(target,false)
	await settle()
	check(main.builds[0].front=="minigun","releasing the snapped preview equips the part")
	motion(Vector2(10,10))
	await settle()
	check(not garage.socket_buttons.front.button.icon_visible(),"newly fitted part hides its mount again when pointer leaves")
	var weapon: Car.Part=garage.car.weapon_parts()[0]
	var art := CatalogueArt.equipment("minigun")
	var local: Vector2=garage.car._px(Parts.mount_point(garage.current_build().chassis,"front",garage.current_build()))+(Vector2(art.size.x*.8,art.size.y*.48)-art.anchor)*art.scale
	var point: Vector2=garage.viewport.get_canvas_transform()*garage.car.chassis.to_global(garage.car._m(local))
	motion(garage.workspace.global_position+point)
	await settle()
	check(garage.socket_buttons.front.button.icon_visible(),"hovering the attached weapon reveals its occupied mount")
	var touch := InputEventScreenTouch.new()
	touch.position=garage.workspace.global_position+point
	touch.pressed=true
	root.push_input(touch,true)
	await settle()
	motion(Vector2(10,10))
	await settle()
	check(garage.revealed_slot=="front" and garage.socket_buttons.front.button.icon_visible(),"touch selects the attached weapon and retains its visible mount")
	var position := garage.car.chassis.position
	var rotation := garage.car.chassis.rotation
	garage.select_slot("gadget")
	check(garage.car.chassis.position.is_equal_approx(position) and is_equal_approx(garage.car.chassis.rotation,rotation),"part selection preserves the assembled car position and rotation")
	garage.revealed_slot=""
	var forklift: Dictionary=main.inventory.acquire("forklift",false)
	garage.remove_part("gadget")
	await settle()
	garage.card_click(forklift)
	await settle()
	check(main.builds[0].gadget=="forklift","click-to-fit automatically chooses a compatible front gadget mount")
	var body: Dictionary=main.inventory.acquire("titan",false)
	body.level=4
	main.inventory.player_level=31
	garage.fit_item("chassis",body.uid)
	await settle()
	check(garage.socket_buttons.size()==9,"garage exposes all nine Titan mounting positions")
	for socket in Parts.equipment_slots(garage.current_build()): garage.remove_part(socket.id)
	await settle()
	garage.card_click(forklift)
	await settle()
	check(main.builds[0].defence_front=="forklift","automatic forklift fitting prefers Titan's low front defence mount")
	var owned_weapon: Dictionary=main.inventory.acquire("rocket",false)
	for slot in ["front","top","attack3","attack4"]: garage.fit_item(slot,main.inventory.acquire("rocket",false).uid)
	garage.fit_item("gadget",main.inventory.acquire("first_aid",false).uid)
	garage.fit_item("gadget2",main.inventory.acquire("backpedal",false).uid)
	motion(Vector2(10,10))
	await settle()
	check(garage.car.weapon_parts().size()==4 and garage.socket_buttons.values().all(func(e):return not e.button.icon_visible()),"fully fitted Titan keeps all occupied icons hidden and four weapons active")
	await shot("titan_seamless_mounts")
	garage.select_slot("defence_front")
	await settle()
	await shot("titan_selected_front_defence")
	print("MOUNT CHECKS: %d failures" % failures)
	quit(1 if failures else 0)
