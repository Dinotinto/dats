extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func settle() -> void:
	for i in 4: await physics_frame
func pair(left: Dictionary) -> Battle:
	var battle := Battle.new()
	battle.show_end_panel=false
	root.add_child(battle)
	battle.start([left,{"chassis":"classic","wheels":"grip","front":"short_sword"}])
	battle.set_physics_process(false)
	for car in battle.cars: car.freeze_all()
	return battle
func checks() -> void:
	var battle := pair({"chassis":"classic","gadget":"first_aid","wheels":"grip"})
	var car: Car = battle.cars[0]
	car.health=car.max_health*.4
	car._run_gadget(.1)
	check(is_equal_approx(car.health,car.max_health*.65),"first aid restores 25 percent below half health")
	car.health=car.max_health*.3
	car._run_gadget(.1)
	check(is_equal_approx(car.health,car.max_health*.3),"first aid cannot trigger twice")
	battle.queue_free()
	await process_frame
	for id in ["booster","backpedal"]:
		battle=pair({"chassis":"classic","gadget":id,"wheels":"grip"})
		car=battle.cars[0]
		for body in car._bodies(): body.freeze=false
		var gadget: Car.Part=car.parts.filter(func(p):return p.id==id)[0]
		car._run_gadget(.2)
		await settle()
		check(car.chassis.linear_velocity.x*(1 if id=="booster" else -1)>0,id+" pushes in its intended direction")
		car._run_gadget(5)
		check(gadget.state.used,id+" uses one start-of-match burst")
		battle.queue_free()
		await process_frame
	battle=pair({"chassis":"classic","front":"double_rocket","wheels":"grip"})
	car=battle.cars[0]
	car._run_launchers(1)
	check(battle._projectiles.size()==2 and battle._projectiles[0].velocity.x*battle._projectiles[1].velocity.x<0,"double rocket launches forward and backward projectiles")
	battle.queue_free()
	await process_frame
	battle=pair({"chassis":"classic","front":"laser","wheels":"grip"})
	car=battle.cars[0]
	var target: Car=battle.cars[1]
	var laser: Car.Part=car.weapon_parts()[0]
	await settle()
	var from := target.chassis.position+Vector2(-170,-30)
	var hp := target.health
	battle.fire_laser(car,laser,from,Vector2.RIGHT)
	check(target.health==hp-100,"level-one laser deals exactly 100 on a visible physical beam hit")
	hp=target.health
	battle.fire_laser(car,laser,from+Vector2(0,-200),Vector2.RIGHT)
	check(target.health==hp,"laser misses a target outside its beam path")
	battle.queue_free()
	await process_frame
	battle=pair({"chassis":"classic","front":"minigun","wheels":"grip"})
	car=battle.cars[0]
	car._run_launchers(1)
	var early: float=car.weapon_parts()[0].state.timer
	car._elapsed=20
	car._run_launchers(1)
	check(car.weapon_parts()[0].state.timer<early,"minigun ramps its firing rate over battle time")
	for shot in battle._projectiles: shot.visual.queue_free()
	battle._projectiles.clear()
	target=battle.cars[1]
	await settle()
	hp=target.health
	battle.launch_projectile(car,car.weapon_parts()[0],target.chassis.position+Vector2(-170,-30),Vector2(1400,0))
	battle._run_projectiles(.25)
	check(target.health==hp-5,"50-DPS level-one minigun round deals five damage on actual impact")
	battle.queue_free()
	await process_frame
	for id in ["forklift","repulse","lifter"]:
		battle=pair({"chassis":"classic","gadget":id,"wheels":"grip"})
		car=battle.cars[0]
		target=battle.cars[1]
		var gadget: Car.Part=car.parts.filter(func(p):return p.id==id)[0]
		car._run_gadget(.5)
		check(gadget.state.timer<=0,id+" cannot activate without physical contact")
		# Bring a real enemy hurt shape into the gadget's actual polygon.
		var hurt := target.chassis_part.nodes.filter(func(n):return n is Area2D)[0] as Area2D
		hurt.global_position=gadget.state.area.global_position+Vector2(-20,20)
		await settle()
		car._run_gadget(.1)
		check(gadget.state.timer>0,id+" activates on actual enemy contact")
		if id=="lifter":
			check(battle._balloons.size()==1,"lifter attaches a visible balloon")
			battle._run_balloons(3.6)
			check(battle._balloons.is_empty(),"balloon expires after 3.5 seconds")
		battle.queue_free()
		await process_frame
	print("EQUIPMENT CHECKS: %d failures" % failures)
	quit(1 if failures else 0)
