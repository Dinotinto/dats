extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func capture(file: String) -> void:
	await create_timer(.6).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../screenshots/"+file+".png")
func run() -> void:
	var hub := DatsHub.new()
	root.add_child(hub)
	hub.setup("@dinotinto",1,true)
	await capture("gamey_home")
	check(hub.panel.get_global_rect().end.y<=root.size.y,"home menu fits landscape screen")
	var grid: GridContainer = hub.panel.get_child(0).get_child(2)
	check(grid.get_child_count()==4 and grid.get_child(0).size.y>=112,"large game mode tiles")
	check(not grid.get_child(1).disabled and grid.get_child(3).disabled,"friend fights available; unfinished arena clearly disabled")
	hub.queue_free()
	await process_frame
	var auth := DatsAuthLanding.new()
	root.add_child(auth)
	await capture("gamey_signin")
	check(auth.signin.size.y>=68 and auth.address.size.y>=62,"larger sign-in buttons and inputs")
	check(auth.google.get_theme_constant("outline_size")==0,"Google text remains clear on white button")
	check(auth.panel.get_global_rect().end.y<=root.size.y,"sign-in fits landscape screen")
	auth.queue_free()
	print("MENU VISUAL failures=%d" % failures)
	quit(1 if failures else 0)
