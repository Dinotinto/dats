extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func front_slot(body: String) -> String:
	var answer := ""
	var x := -10000.0
	for mount in Parts.equipment_slots({"chassis":body}):
		if mount.type!="attack" and mount.point.x>x: answer = mount.id; x = mount.point.x
	return answer
func run() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	battle.show_end_panel = false
	battle.start([{"chassis":"classic","wheels":"rubber_medium","front":"balloon_launcher"},{"chassis":"titan","wheels":"rubber_medium"}])
	battle.set_physics_process(false)
	var owner: Car = battle.cars[0]
	for car in battle.cars:
		for body in car._bodies(): body.freeze = true
	for tick in 600: owner._run_launchers(1.0/60.0)
	check(battle._projectiles.size()==3,"balloon fires three times in first ten seconds")
	check(absf(float(owner.parts.filter(func(p):return p.id=="balloon_launcher")[0].data.first_delay)-.7)<.01,"balloon first shot is 0.7 seconds after combat starts")
	battle.time_left = Battle.TIME_LIMIT-19
	battle._run_walls(1)
	check(battle._wall_x==1450,"walls stay at wider starting distance through 19 seconds")
	battle.time_left = Battle.TIME_LIMIT-20
	battle._run_walls(1)
	check(battle._wall_x<1450,"walls begin moving after twenty seconds")
	battle.queue_free()
	await process_frame
	battle = Battle.new()
	root.add_child(battle)
	battle.show_end_panel = false
	battle.start([{"chassis":"classic","wheels":"rubber_medium","front":"balloon_launcher"},{"chassis":"titan","wheels":"rubber_medium"}])
	var attached := false
	var lifted := false
	var initial_y: float = battle.cars[1].chassis.position.y
	for tick in 420:
		await physics_frame
		if not battle._balloons.is_empty():
			attached = attached or battle._balloons[0].point_lift
			lifted = lifted or battle.cars[1].chassis.position.y<initial_y-20
	check(attached,"actual balloon projectile hits and attaches to vehicle")
	check(lifted,"balloon hit physically lifts the target")
	battle.queue_free()
	await process_frame
	for team in 2:
		battle = Battle.new()
		root.add_child(battle)
		battle.show_end_panel = false
		var builds := [{"chassis":"classic","wheels":"rubber_medium"},{"chassis":"classic","wheels":"rubber_medium"}]
		builds[team][front_slot("classic")] = "forklift"
		builds[1-team][front_slot("classic")] = "repulse"
		battle.start(builds)
		var defender: Car = battle.cars[1-team]
		var attacker: Car = battle.cars[team]
		var repulse: Car.Part = defender.parts.filter(func(p):return p.id=="repulse")[0]
		var fired := false
		var pushed := false
		for tick in 360:
			await physics_frame
			fired = fired or repulse.state.timer>3
			pushed = pushed or attacker.chassis.linear_velocity.x*defender.dir>180
		check(fired and pushed,"front Repulse physically pushes approaching forklift away, side "+str(team))
		battle.queue_free()
		await process_frame
	print("CONTROL BALANCE failures=%d" % failures)
	quit(1 if failures else 0)
