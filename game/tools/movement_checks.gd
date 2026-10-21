extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func ticks(count: int) -> void:
	for i in count: await physics_frame
func pair(builds: Array) -> Battle:
	var battle := Battle.new()
	battle.show_end_panel=false
	root.add_child(battle)
	battle.start(builds)
	return battle
func run() -> void:
	for team in 2:
		var builds := [{"chassis":"classic","wheels":"rubber_medium","front":"stinger"},{"chassis":"classic","wheels":"rubber_medium","front":"stinger"}]
		builds[team].gadget="backpedal"
		var battle := pair(builds)
		var car: Car=battle.cars[team]
		await ticks(60) # Let the READY countdown finish before measuring retreat.
		var start := car.chassis.position.x
		await ticks(60)
		check((car.chassis.position.x-start)*car.dir< -40,"backpedal retreats against live forward motors, team "+str(team))
		check(car.reversing_time>.5,"backpedal engages reversing wheel drive, team "+str(team))
		battle.queue_free()
		await process_frame
	for team in 2:
		var builds := [{"chassis":"classic","wheels":"rubber_medium"},{"chassis":"classic","wheels":"rubber_medium"}]
		builds[team].gadget="forklift"
		var battle := pair(builds)
		var car: Car=battle.cars[team]
		var enemy: Car=battle.cars[1-team]
		var fork: Car.Part=car.parts.filter(func(p):return p.id=="forklift")[0]
		check(fork.body!=car.chassis and fork.joint is PinJoint2D,"forklift has a real articulated physics arm")
		var contacted := false
		var rotates := false
		var raised := false
		var starting_y: float=enemy.chassis.position.y
		for i in 240:
			await physics_frame
			if fork.state.phase=="lift":
				contacted=true
				rotates=rotates or angle_difference(car.chassis.rotation,fork.body.rotation)*car.dir< -.1
				raised=raised or enemy.chassis.position.y<starting_y-10
		check(contacted,"forklift activates on actual enemy contact, team "+str(team))
		check(rotates,"forklift rotates anticlockwise left / clockwise right, team "+str(team))
		check(raised,"forklift lifts the complete enemy car above its ride height, team "+str(team))
		battle.queue_free()
		await process_frame
	var battle := pair([{"chassis":"classic","front":"stinger","wheels":"rubber_medium"},{"chassis":"classic","front":"stinger","wheels":"rubber_medium"}])
	await ticks(150)
	check(battle.cars.all(func(car):return car.total_dealt()>20),"opposing melee weapons overlap and both reach enemy bodies")
	for car in battle.cars:
		check(car.weapon_parts()[0].nodes.filter(func(node):return node is CollisionPolygon2D).is_empty(),"fixed weapons retain contact sensors without a blocking solid shape")
	battle.queue_free()
	await process_frame
	battle=pair([{"chassis":"classic","front":"stinger","gadget":"harpoon","wheels":"rubber_medium"},{"chassis":"surfer","wheels":"rubber_medium"}])
	battle.set_physics_process(false)
	var owner: Car=battle.cars[0]
	var target: Car=battle.cars[1]
	var hook: Car.Part=owner.parts.filter(func(p):return p.id=="harpoon")[0]
	for car in battle.cars:
		for body in car._bodies(): body.gravity_scale=0
	var initial := owner.chassis.position.distance_to(target.chassis.position)
	var impact := target.chassis.position+Vector2(-100,-20)
	# A fired hook shows its rope before impact; misses never attach.
	battle.launch_projectile(owner,hook,owner.chassis.to_global(hook.state.muzzle),Vector2(1000,0))
	check(battle._projectiles[0].rope is Line2D,"flying harpoon has a visible trailing cable")
	battle._run_projectiles(.05)
	check(battle._cables.is_empty(),"harpoon cannot grapple before a physical projectile hit")
	# Exercise the winch after the impact callback with real unfrozen car assemblies.
	battle._attach_cable(owner,hook,target,target.chassis_part,impact)
	for i in 90:
		battle._run_cables(1.0/60)
		await physics_frame
	check(owner.chassis.position.distance_to(target.chassis.position)<initial-80,"tensioned harpoon draws the enemy into melee range")
	check(hook.state.hooked,"hook stays attached while reeling instead of firing duplicate cables")
	battle._run_cables(3)
	check(battle._cables.is_empty() and not hook.state.hooked,"hook releases and can fire again after its pull")
	battle.queue_free()
	print("MOVEMENT CHECKS: %d failures"%failures)
	quit(1 if failures else 0)
