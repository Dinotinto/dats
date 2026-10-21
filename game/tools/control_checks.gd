extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	var inv := Inventory.new()
	inv.persistence_enabled=false
	inv.starter(true)
	inv.gold=10000
	inv.toolboxes={"attack":4,"health":4,"power":3}
	check(Parts.WEAPONS.keys().all(func(id):return inv.items.filter(func(i):return i.id==id).size()==1),"starter inventory owns exactly one of each weapon")
	var body := inv.items.filter(func(i):return i.id=="titan")[0] as Dictionary
	var laser := inv.items.filter(func(i):return i.id=="laser")[0] as Dictionary
	var b := inv.synchronize({"chassis":"titan","wheels":"rubber_medium","equipped":{"chassis":body.uid}})
	b=inv.equip(b,"front",laser.uid)
	b=inv.equip(b,"top",laser.uid)
	check(b.top=="" and b.front=="laser","one collected laser cannot fill two slots")
	var other := inv.equip(inv.synchronize({"chassis":"classic","wheels":"rubber_medium"}),"front",laser.uid)
	check(other.front=="laser","different player blueprints may use the same weapon type")
	inv.buy_part("laser",1)
	var copy := inv.items.filter(func(i):return i.id=="laser" and i.uid!=laser.uid)[0] as Dictionary
	b=inv.equip(b,"top",copy.uid)
	check(b.top=="laser" and b.equipped.top!=b.equipped.front,"buying another laser supplies a distinct usable copy")
	for tier in range(1,6):
		body.level=tier
		inv.player_level=(tier-1)*10+1
		b=inv.synchronize(b)
		var slots := Parts.equipment_slots(b)
		var limits := Progression.slot_limits(tier)
		check(slots.filter(func(s):return s.type=="attack").size()==limits.x and slots.filter(func(s):return s.type!="attack").size()==limits.y,"tier %d chassis exposes %d attack/%d defence"%[tier,limits.x,limits.y])
	for chassis in Parts.CHASSIS:
		for tier in range(1,6):
			var slots := Parts.equipment_slots({"chassis":chassis,"component_stats":{"chassis":{"level":tier}}})
			var limits := Progression.slot_limits(tier)
			check(slots.filter(func(s):return s.type=="attack").size()<=limits.x and slots.filter(func(s):return s.type!="attack").size()<=limits.y,chassis+" respects tier %d mount limits"%tier)
	for id in ["balloon_launcher","net_launcher","flipper_net"]:
		for team in 2:
			var battle := Battle.new()
			battle.show_end_panel=false
			root.add_child(battle)
			var builds := [{"chassis":"classic","wheels":"rubber_medium"},{"chassis":"classic","wheels":"rubber_medium"}]
			builds[team].front=id
			battle.start(builds)
			battle.set_physics_process(false)
			for car in battle.cars: car.freeze_all()
			for i in 4: await physics_frame
			var owner: Car=battle.cars[team]
			var target: Car=battle.cars[1-team]
			var weapon: Car.Part=owner.weapon_parts()[0]
			var hp := target.health
			battle.launch_projectile(owner,weapon,target.chassis.position+Vector2(-owner.dir*170,-300),Vector2(owner.dir*650,0))
			battle._run_projectiles(.4)
			check(battle._nets.is_empty() and battle._balloons.is_empty(),id+" projectile miss cannot apply control")
			for shot in battle._projectiles: shot.visual.queue_free()
			battle._projectiles.clear()
			battle.launch_projectile(owner,weapon,target.chassis.position+Vector2(-owner.dir*170,-30),Vector2(owner.dir*650,0))
			check(battle._nets.is_empty() and battle._balloons.is_empty(),id+" cannot apply before projectile impact")
			battle._run_projectiles(.4)
			check(target.health==hp,id+" has no hidden direct damage")
			if id=="balloon_launcher":
				check(battle._balloons.size()==1 and battle._balloons[0].point_lift and absf(battle._balloons[0].anchor.x)>30,"balloon attaches at the physical front impact point")
				for body_part in target._bodies(): body_part.freeze=false
				var tilted := false
				for i in 120:
					battle._run_balloons(1.0/60)
					await physics_frame
					tilted=tilted or absf(target.chassis.rotation)>.3
				check(tilted,"off-centre balloon lift rotates the actual car")
				battle._run_balloons(3.1)
				check(battle._balloons.is_empty(),"projectile balloon releases after five seconds")
			else:
				check(target.restrained and battle._nets.size()==1,"net impact restrains its actual target")
				battle.attach_net(target,false)
				check(battle._nets.size()==1,"nets cannot stack or refresh a restraint")
				check(target.collect_hits(.1).is_empty(),"restrained car cannot deal contact damage")
				var count := battle._projectiles.size()
				target._run_launchers(10)
				check(battle._projectiles.size()==count,"restrained car cannot fire projectiles")
				battle._run_nets(1)
				if id=="flipper_net": check(target.chassis.global_transform.y.y< -.95,"flipper net holds car on its back")
				battle._run_nets(3.9)
				check(target.restrained,"net retains restraint for full five seconds")
				battle._run_nets(1)
				check(not target.restrained and battle._nets.is_empty(),"net releases its target")
				if id=="flipper_net": check(target.chassis.global_transform.y.y>.95,"flipper recovery rights the car before release")
				battle.attach_net(target,true)
				check(battle._nets.is_empty(),"brief recovery immunity prevents immediate net relocking")
			battle.queue_free()
			await process_frame
	for id in ["balloon_launcher","net_launcher","flipper_net"]:
		for team in 2:
			var battle := Battle.new()
			battle.show_end_panel=false
			root.add_child(battle)
			var builds := [{"chassis":"classic","wheels":"rubber_medium"},{"chassis":"classic","wheels":"rubber_medium"}]
			builds[team].front=id
			battle.start(builds)
			var activated := false
			for i in 540:
				await physics_frame
				activated=activated or not battle._balloons.is_empty() or not battle._nets.is_empty()
			check(activated,id+" activates during actual driving, team "+str(team))
			battle.queue_free()
			await process_frame
	print("CONTROL CHECKS: %d failures"%failures)
	quit(1 if failures else 0)
