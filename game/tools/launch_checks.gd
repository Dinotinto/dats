extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in 5: await process_frame
func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../screenshots/" + name + ".png")
func touch(shelf: SwipePartsShelf, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)
func drag(shelf: SwipePartsShelf, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	root.push_input(event, true)
func checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	check(is_instance_valid(main._launch), "player cold launch starts studio reveal")
	await create_timer(.7).timeout
	await screenshot("launch_studio")
	await create_timer(1.9).timeout
	check(main._launch._ready_to_enter, "studio transitions to interactive title")
	await screenshot("launch_title")
	main._launch._enter()
	await create_timer(.4).timeout
	check(is_instance_valid(main._auth) and not is_instance_valid(main._garage), "title leads to full-screen sign-in")
	await screenshot("launch_signin")
	main._auth.address.text = "test@example.test"
	main._auth.password.text = "short"
	main._auth._submit(true)
	check(main._auth.status.text.contains("8 characters") and not main.cloud.busy, "weak signup password blocked before network")
	main._auth.show_verification()
	check(main._auth.verification.visible and not main._auth.password.is_visible_in_tree(), "email code entry replaces password controls")
	main._auth.code.text = "wrong"
	main._auth._verify()
	check(main._auth.status.text.contains("numeric code") and not main.cloud.busy, "invalid email code blocked before network")
	await screenshot("email_code_verification")
	main._auth.offline_requested.emit()
	await settle()
	await create_timer(.4).timeout
	check(is_instance_valid(main._hub) and not main.cloud_mode, "offline practice leads to home")
	for child in main._hub.panel.get_child(0).get_children():
		if child is Button and (child.text.begins_with("ARENA") or child.text.begins_with("QUICK MATCH")):
			check(child.disabled, "unhosted mode disabled: " + child.text)
	await screenshot("launch_home")
	main._hub.garage_requested.emit()
	await settle()
	var garage: GarageUI = main._garage
	var shelf: SwipePartsShelf = garage.parts_scroll
	var before: Dictionary = main.builds[0].duplicate(true)
	var start := shelf.get_global_rect().position + Vector2(350,45)
	touch(shelf,start,true)
	drag(shelf,start-Vector2(150,0),Vector2(-150,0))
	touch(shelf,start-Vector2(150,0),false)
	check(shelf.scroll_horizontal >= 140 and shelf.swipe_suppresses_click(), "touch across cards pans shelf and suppresses tap")
	check(main.builds[0] == before, "swipe does not equip a part")
	await create_timer(.2).timeout
	touch(shelf,start,true)
	drag(shelf,start+Vector2(0,30),Vector2(0,30))
	check(not shelf.swipe_suppresses_click(), "vertical movement remains available for drag-to-fit")
	touch(shelf,start+Vector2(0,30),false)
	main.cloud.busy = true
	var scroll_before := shelf.scroll_horizontal
	touch(shelf,start,true)
	drag(shelf,start-Vector2(150,0),Vector2(-150,0))
	check(shelf.scroll_horizontal == scroll_before, "cloud transaction blocks shelf input")
	main.cloud.busy = false
	for id in Parts.DRIVERS:
		var mechanic := GarageMechanic.new()
		garage.add_child(mechanic)
		mechanic.setup(id,1)
		check(is_instance_valid(mechanic.full_body) and mechanic.full_body.texture != null, "full-body garage art: " + id)
		mechanic.queue_free()
	await create_timer(.4).timeout
	await screenshot("launch_garage")
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(is_instance_valid(main._hub), "Android Back from garage returns home")
	main._hub.practice_requested.emit()
	await settle()
	check(is_instance_valid(main._battle) and not is_instance_valid(main._hub), "home practice starts local battle")
	main._show_garage()
	main.sign_out()
	await settle()
	check(is_instance_valid(main._auth) and not main.cloud.connected(), "sign-out returns to sign-in")
	main.queue_free()
	await settle()
	print("LAUNCH CHECKS failures=%d" % failures)
	quit(1 if failures else 0)
