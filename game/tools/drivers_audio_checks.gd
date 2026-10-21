extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func capture(file: String) -> void:
	await create_timer(.4).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../screenshots/"+file+".png")
func run() -> void:
	var path := "user://sound.cfg"
	var existed := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_string(path) if existed else ""
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.player_mode = true
	main._show_hub()
	main._hub.driver_requested.emit()
	await process_frame
	var garage: GarageUI = main._garage
	var grid: GridContainer = garage.driver_dialog.get_child(0)
	check(grid.get_child_count()==6,"all six drivers shown in visible picker")
	await capture("drivers_six_picker")
	for id in Parts.DRIVERS:
		garage.choose_driver(id)
		await process_frame
		check(main.builds[0].driver==id and garage.car.driver_id()==id and garage.mechanic.driver_id==id,"select and preview "+id)
	main._show_hub()
	check(main._hub.bolt.texture.resource_path.ends_with("driver_spark_full.png"),"home displays selected character")
	main.show_settings()
	await capture("audio_settings")
	var panel: VBoxContainer = main.settings_dialog.get_child(0)
	panel.get_child(0).button_pressed = false
	panel.get_child(2).button_pressed = false
	check(not DatsAudio.instance().music_enabled and DatsAudio.instance().music.stream_paused,"music off pauses soundtrack")
	check(not DatsAudio.instance().effects_enabled and DatsAudio.instance().voices.all(func(v):return not v.playing),"effects off stops active effects")
	var cfg := ConfigFile.new()
	cfg.load(path)
	check(not cfg.get_value("audio","music_enabled") and not cfg.get_value("audio","effects_enabled"),"audio switches saved to device settings")
	DatsAudio.instance().effects_enabled = true
	DatsAudio.instance().effect("minigun")
	check(DisplayServer.get_name()=="headless" or DatsAudio.instance().voices.any(func(v):return v.playing),"weapon effect reaches audio voice pool")
	for key in ["laser","rocket","minigun","balloon_inflate","balloon_pop","forklift","harpoon","net","explosion"]:
		check(DatsAudio.instance().stream(key).get_length()>0,"audio asset decodes: "+key)
	main.queue_free()
	await process_frame
	if existed:
		var saved := FileAccess.open(path,FileAccess.WRITE)
		saved.store_string(original)
		saved.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DatsAudio.instance().stop_all()
	await create_timer(.15).timeout
	print("DRIVERS & AUDIO failures=%d" % failures)
	quit(1 if failures else 0)
