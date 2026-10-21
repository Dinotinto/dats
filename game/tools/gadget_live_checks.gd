extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	for id in ["lifter", "repulse"]:
		for scenario in 4:
			var team := scenario%2
			var battle := Battle.new()
			battle.show_end_panel=false
			root.add_child(battle)
			var builds := [{"chassis":"classic","wheels":"rubber_medium"},{"chassis":"classic","wheels":"rubber_medium"}]
			if scenario>=2: builds[1-team]={"chassis":"titan","rear_wheel":"metal_large","front_wheel":"metal_medium"}
			builds[team].gadget=id
			battle.start(builds)
			var owner: Car=battle.cars[team]
			var victim: Car=battle.cars[1-team]
			var gadget: Car.Part=owner.parts.filter(func(p):return p.id==id)[0]
			var activated := false
			var airborne := false
			var pushed := false
			var balloon_ticks := 0
			var lifted_bodies := false
			var ride_height: float=victim.chassis.position.y
			var started := false
			var fell_after_release := false
			for i in 480:
				await physics_frame
				if i==55: ride_height=victim.chassis.position.y
				activated=activated or gadget.state.timer>1
				airborne=airborne or victim.chassis.position.y<ride_height-100
				pushed=pushed or victim.chassis.linear_velocity.x*owner.dir>200
				if id=="lifter" and not battle._balloons.is_empty():
					started=true
					balloon_ticks+=1
					gadget.state.timer=1000 # Observe one complete balloon lifecycle.
					lifted_bodies=lifted_bodies or victim._bodies().all(func(body):return body.global_position.y<ride_height-65)
				if started and battle._balloons.is_empty(): fell_after_release=fell_after_release or victim.chassis.linear_velocity.y>50
				if i==54: check(battle._balloons.is_empty(),"no distant balloon activation")
			var label := " team %d vs %s"%[team,builds[1-team].chassis]
			check(activated,id+" activates in a real approach,"+label)
			if id=="lifter":
				check(airborne and lifted_bodies,"lifter raises the complete enemy assembly,"+label)
				check(balloon_ticks>=200 and balloon_ticks<=212,"balloon holds for 3.5 seconds,"+label)
				check(battle._balloons.is_empty() and fell_after_release and victim._bodies().all(func(body):return body.gravity_scale==1),"balloon releases and normal falling resumes,"+label)
			else: check(pushed,"repulse drives the enemy away,"+label)
			battle.queue_free()
			await process_frame
	for id in ["harpoon","booster"]:
		for team in 2:
			var battle := Battle.new()
			battle.show_end_panel=false
			root.add_child(battle)
			var builds := [{"chassis":"classic","wheels":"rubber_medium"},{"chassis":"classic","wheels":"rubber_medium"}]
			builds[team].gadget=id
			battle.start(builds)
			var owner: Car=battle.cars[team]
			var gadget: Car.Part=owner.parts.filter(func(p):return p.id==id)[0]
			var activated := false
			var reeled := false
			var first_length := -1.0
			for i in 200:
				await physics_frame
				if id=="booster": activated=activated or (gadget.state.used and owner.chassis.linear_velocity.x*owner.dir>150)
				else:
					for cable in battle._cables:
						if cable.owner!=owner: continue
						activated=true
						if first_length<0: first_length=cable.length
						reeled=reeled or cable.length<first_length-50
			check(activated,id+" activates during real driving, team "+str(team))
			if id=="harpoon": check(reeled,"actual hook projectile attaches and reels its cable, team "+str(team))
			battle.queue_free()
			await process_frame
	print("LIVE GADGET CHECKS: %d failures"%failures)
	quit(1 if failures else 0)
