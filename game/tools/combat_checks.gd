extends SceneTree

var failures := 0
var battle: Battle

func _initialize() -> void:
	checks.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func settle() -> void:
	for i in 4:
		await physics_frame
		await process_frame

func checks() -> void:
	seed(42)
	battle = Battle.new()
	battle.show_end_panel = false
	root.add_child(battle)
	var b := {"chassis": "wedge", "wheels": "grip", "front": "saw", "top": "", "gadget": "booster"}
	battle.start([b, {"chassis": "bruiser", "wheels": "grip", "front": "", "top": "", "defence": "shield", "gadget": ""}])
	battle.set_physics_process(false)
	for car in battle.cars:
		car.freeze_all()
	await settle()
	var blue: Car = battle.cars[0]
	var red: Car = battle.cars[1]
	check(blue.max_health == 450 and red.max_health == 640, "total health equals body plus both tyres plus fitted gadgets")
	check(blue.collect_hits(1.0 / 60).is_empty(), "separated saw causes no damage")
	# Isolate a tiny target at the blade's former oversized-circle boundary.
	for part in red.parts:
		for node in part.nodes:
			if node is Area2D:
				node.collision_layer = 0
	var target_area := red._make_hurtbox(red.chassis_part, red.chassis)
	var circle := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 1
	circle.shape = shape
	target_area.add_child(circle)
	var hb: Area2D = blue.hitboxes[0].area
	var center: Vector2 = blue.chassis.to_global(blue._m(blue._px(Parts.CHASSIS.wedge.mounts.front) + Parts.WEAPONS.saw.disc_at * Parts.SCALE))
	target_area.global_position = center + Vector2(48, 0)
	await settle()
	check(blue.collect_hits(1.0 / 60).is_empty(), "target outside visible saw receives no phantom damage")
	target_area.global_position = center + Vector2(25, 0)
	await settle()
	check(not blue.collect_hits(1.0 / 60).is_empty(), "visible saw contact generates damage")
	blue._build_modular_weapon("short_sword", Parts.WEAPONS.short_sword, "front", blue.chassis.position, Vector2.ZERO)
	var sword: Car.Part = blue.weapon_parts().back()
	sword.body.freeze = true
	target_area.global_position = sword.body.to_global(blue._m(Vector2(40, 0)))
	await settle()
	check(sword.body == blue.chassis and sword.joint == null and not sword.data.has("arm"), "sword is fixed horizontally to chassis")
	var sword_hits := blue.collect_hits(1.0 / 60).filter(func(h): return h[4] == sword)
	check(sword_hits.size() == 1 and is_equal_approx(sword_hits[0][2], 40.0 / 60.0), "40-rated stationary sword deals 2/3 per 60 Hz contact tick")
	# Touch a second part of the same car; this must not double its attack rating.
	var second_area := red._make_hurtbox(red.wheels[0], red.wheels[0].body)
	var second_shape := CollisionShape2D.new()
	second_shape.shape = shape
	second_area.add_child(second_shape)
	second_area.global_position = target_area.global_position
	await settle()
	check(blue.collect_hits(1.0 / 60).filter(func(h): return h[4] == sword).size() == 1, "one blade overlapping two enemy parts counts once")
	for hz in [30, 60, 120]:
		var before := red.health
		for tick in hz:
			for hit in blue.collect_hits(1.0 / hz).filter(func(h): return h[4] == sword):
				red.apply_damage(hit[1], hit[2], hit[3], hit[4], hit[5])
		check(is_equal_approx(before - red.health, 40.0), "one second of sword contact deducts exactly 40 at %d Hz" % hz)
	var high_sword_mount := blue._px(Parts.mount_point("wedge", "top"))
	blue._build_modular_weapon("long_sword", Parts.WEAPONS.long_sword, "top", blue.chassis.position, high_sword_mount)
	var high_sword: Car.Part = blue.weapon_parts().back()
	target_area.global_position = blue.chassis.to_global(high_sword_mount + Vector2(80, 30))
	second_area.global_position = target_area.global_position
	await settle()
	check(blue.collect_hits(1.0 / 60).filter(func(h): return h[4] == high_sword).is_empty(), "high horizontal sword misses a lower target")
	target_area.global_position = blue.chassis.to_global(high_sword_mount + Vector2(80, 0))
	second_area.global_position = target_area.global_position
	await settle()
	check(not blue.collect_hits(1.0 / 60).filter(func(h): return h[4] == high_sword).is_empty(), "same high blade connects at its actual mount height")
	# Ranged damage and cable attachment require a swept physical impact.
	target_area.global_position = Vector2(200, -200)
	await settle()
	var launcher := Car.Part.new()
	launcher.kind = "weapon"
	launcher.id = "cannon"
	launcher.label = "Cannon"
	launcher.data = Parts.WEAPONS.cannon
	launcher.attack_rating = launcher.data.attack
	launcher.state = {"muzzle": Vector2.ZERO}
	var hp := red.health
	battle.launch_projectile(blue, launcher, Vector2(0, -200), Vector2(1000, 0))
	battle._run_projectiles(0.1)
	check(red.health == hp, "projectile causes no damage before impact")
	battle._run_projectiles(0.11)
	check(red.health == hp - 60, "60-rated cannon impact deducts exactly 60 health")
	launcher.id = "hook"
	launcher.label = "Grappling hook"
	launcher.data = Parts.WEAPONS.hook
	launcher.attack_rating = 0.0
	battle.launch_projectile(blue, launcher, Vector2(0, -200), Vector2(1000, 0))
	battle._run_projectiles(0.1)
	check(battle._cables.is_empty(), "hook miss cannot attach a cable")
	battle._run_projectiles(0.11)
	check(battle._cables.size() == 1, "hook impact attaches a cable")
	battle._run_cables(0.2)
	check(battle._cables.size() == 1 and battle._cables[0].line.points.size() == 2, "attached cable draws and applies tension")
	battle._run_cables(3.0)
	check(battle._cables.is_empty(), "hook cable releases after its lifetime")
	battle._attach_cable(blue, launcher, red, red.chassis_part, Vector2(200, -200))
	battle._cables[0].anchor = red.chassis.to_local(Vector2(1000, -200))
	battle._run_cables(0.01)
	check(battle._cables.is_empty(), "overextended hook cable breaks")
	# Local durability is a damage counter; it never disables equipment mid-fight.
	blue._build_modular_weapon("cannon", Parts.WEAPONS.cannon, "top", blue.chassis.position, blue._px(Parts.mount_point("wedge", "top")))
	for part in blue.parts:
		blue.health = blue.max_health
		blue.apply_damage(part, part.max_hp + 1.0, blue.chassis.position, launcher, false)
		check(part.alive and part.hp == 0 and part.nodes.all(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()), "%s stays attached at zero local durability" % part.label)
	blue.health = blue.max_health
	var before_shots := battle._projectiles.size()
	blue._run_launchers(2.0)
	check(battle._projectiles.size() > before_shots, "cannon keeps firing with exhausted local durability")
	for p in battle._projectiles:
		p.visual.queue_free()
	battle._projectiles.clear()
	blue.health = blue.max_health * 0.34
	check(blue.fear_level() == 1, "low health triggers worried driver reaction")
	blue.health = blue.max_health * 0.14
	check(blue.fear_level() == 2, "critical health triggers panicked driver reaction")
	blue.health = blue.max_health
	check(blue.fear_level() == 0, "healthy drivers retain their normal expression")
	var old_health := red.health
	var body_remaining := red.chassis_part.hp
	red.apply_damage(red.chassis_part, body_remaining, red.chassis.position, launcher, false)
	check(red.alive and red.chassis_part.alive and red.health == old_health - body_remaining, "body durability depletion does not bypass the shared health pool")
	old_health = red.health
	red.apply_damage(red.chassis_part, 30.0, red.chassis.position, launcher, false)
	check(red.health == old_health - 30.0, "body stays damageable while total health remains")
	var defence: Car.Part = red.parts.filter(func(p): return p.kind == "defence")[0]
	defence.hp = 1.0
	old_health = red.health
	red.apply_damage(defence, 60.0, red.chassis.position, launcher, false)
	check(defence.alive and defence.hp == 0 and red.health == old_health - 60.0, "exhausted defence stays fitted and damage deducts only the rated attack")
	target_area.global_position = Vector2(Battle.WALL_X - 10, -84)
	await settle()
	battle.running = true
	battle.time_left = Battle.TIME_LIMIT
	battle._run_walls(1.0 / 60)
	check(red.alive, "empty gap between spikes causes no phantom wall damage")
	# Move a wall and probe the new tip immediately, without waiting for an
	# Area2D overlap cache update. The old position must be harmless.
	battle._wall_x = Battle.WALL_X - 100.0
	target_area.global_position = Vector2(Battle.WALL_X - 10, -104)
	await settle()
	battle._run_walls(1.0 / 60)
	check(red.alive, "former spike location is harmless after wall moves")
	battle._wall_x = Battle.WALL_X
	target_area.global_position = Vector2(Battle.WALL_X - 10, -104)
	await settle()
	battle.running = true
	battle.time_left = Battle.TIME_LIMIT
	battle._run_walls(1.0 / 60)
	check(not red.alive and red.last_hit_by == "Crusher walls", "stationary spike contact destroys whole car before walls move")
	check(red.driver_ejected and not red.driver_actor.visible and battle.escapes.size() == 1, "defeat ejects one driver and empties the cockpit")
	check(red.collect_hits(1.0 / 60).is_empty(), "defeated car cannot continue dealing damage")
	var escape: ParachuteEscape = battle.escapes[0]
	escape.set_process(false)
	var launch_height := escape.position.y
	escape.advance(0.2)
	check(escape.position.y < launch_height and escape.canopy_open == 0, "ejection seat launches upward before canopy opens")
	for i in 20:
		escape.advance(0.05)
	check(escape.canopy_open == 1 and escape.velocity.y <= ParachuteEscape.DESCENT_SPEED, "parachute deploys and limits descent speed")
	check(escape.actor.driver_id == red.driver_id() and not escape.is_class("CollisionObject2D"), "escape preserves the chosen cat and cannot be hit")
	battle.on_car_died(red, red.chassis.position)
	check(battle.escapes.size() == 1, "duplicate death callback cannot eject a second driver")
	for i in 240:
		escape.advance(1.0 / 30.0)
	check(escape.landed and escape.position.y == -88 and escape.velocity == Vector2.ZERO and escape.actor.legs.landed, "full-body escaped driver lands gently and survives")
	battle.running = false
	battle.queue_free()
	await process_frame
	# Construct every new weapon in both mounts and both facing directions.
	var world := Node2D.new()
	root.add_child(world)
	for chassis_id in Parts.CHASSIS:
		var slots := Parts.mount_slots(chassis_id)
		check(slots.size()<=4 and slots.filter(func(s):return s.type=="attack").size()<=2 and slots.filter(func(s):return s.type!="attack").size()<=2, "%s has tier-one combat mount limits" % chassis_id)
		var invalid := {"chassis": chassis_id, "wheels": "grip", "front": "shield", "top": "armour_plate", "defence": "short_sword", "gadget": "short_sword"}
		var car := Car.new()
		world.add_child(car)
		car.setup(invalid, 0, Vector2.ZERO, Color.WHITE, null)
		car.freeze_all()
		check(car.weapon_parts().is_empty() and car.parts.filter(func(p): return p.kind == "defence").is_empty(), "%s rejects attack/defence/utility mismatches in physics builder" % chassis_id)
		car.queue_free()
	var migrated := Parts.normalize_build({"chassis": "ram", "front": "short_sword", "top": "cannon", "defence": "shield"})
	check(migrated.top == "" and migrated.front == "short_sword" and migrated.defence == "shield", "changing chassis removes unsupported mount equipment")
	var upgraded := {"chassis": "wedge", "wheels": "grip", "front": "short_sword", "defence": "armour_plate", "rating_upgrades": {"chassis": {"durability": 25.0}, "front": {"attack": 5.0, "durability": 10.0}, "defence": {"durability": 20.0}}}
	var upgraded_car := Car.new()
	world.add_child(upgraded_car)
	upgraded_car.setup(upgraded, 0, Vector2.ZERO, Color.WHITE, null)
	upgraded_car.freeze_all()
	check(upgraded_car.max_health == 545 and upgraded_car.weapon_parts()[0].attack_rating == 45, "future rating bonuses feed health and combat through one resolver")
	check(upgraded_car.weapon_parts()[0].max_hp == 100, "weapon durability upgrades do not inflate total car health")
	upgraded_car.queue_free()
	for id in ["short_sword", "long_sword", "cannon", "blaster", "hook"]:
		for slot in ["front", "top"]:
			for team in 2:
				var car := Car.new()
				world.add_child(car)
				var build := {"chassis": "wedge", "wheels": "grip", "rear_wheel": "wood_small", "front_wheel": "metal_large", "front": "", "top": "", "gadget": ""}
				build[slot] = id
				car.setup(build, team, Vector2.ZERO, Color.WHITE, null)
				car.freeze_all()
				check(car.weapon_parts().size() == 1 and car.wheels[0].state.radius < car.wheels[1].state.radius, "%s %s team %d with independent sizes" % [id, slot, team])
				car.queue_free()
	await settle()
	world.queue_free()
	print("COMBAT CHECKS: %d failures" % failures)
	quit(1 if failures > 0 else 0)

