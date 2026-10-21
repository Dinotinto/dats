extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func checks() -> void:
	var inventory := Inventory.new()
	inventory.persistence_enabled=false
	inventory.starter(true)
	inventory.gold=10000
	inventory.toolboxes={"attack":4,"health":4,"power":3}
	for id in Catalogue.bodies():
		var counts := {}
		var legal := true
		for roll in 30:
			var sockets := Parts.equipment_slots({"chassis":id,"layout_seed":roll})
			counts[sockets.size()+2]=true
			legal = legal and sockets.size()==4
		check(legal and counts.size()==1,id+" has two attack and two defence mounts at tier one")
		var car := Car.new()
		root.add_child(car)
		car.setup({"chassis":id,"front":"blade","gadget":"forklift","wheels":"rubber_small"},0,Vector2.ZERO,Color.WHITE,null)
		car.freeze_all()
		check(car.chassis.get_children().filter(func(n):return n is CollisionShape2D or n is CollisionPolygon2D).size()>0,id+" has a physical hull")
		car.queue_free()
	var body := inventory.acquire("classic",false)
	var weapon := inventory.acquire("rocket",false)
	var build := inventory.synchronize({"chassis":"classic","wheels":"rubber_medium","front":"rocket","equipped":{"chassis":body.uid,"front":weapon.uid}})
	var original_seed: int = body.layout_seed
	inventory.toolbox(body.uid,"power")
	inventory.toolbox(weapon.uid,"attack")
	build=inventory.synchronize(build)
	check(Parts.energy_report(build).capacity==16,"power toolbox permanently adds one energy")
	check(Parts.rated_data(Parts.WEAPONS.rocket,build,"front").attack==70,"attack toolbox permanently adds five attack")
	check(int(body.layout_seed)==original_seed,"upgrades preserve collected socket layout")
	weapon.affinities=[{"stat":"attack","weapon":"rocket","percent":.15},{"stat":"health","chassis":"titan","percent":.2}]
	build=inventory.synchronize(build)
	check(is_equal_approx(Parts.rated_data(Parts.WEAPONS.rocket,build,"front").attack,80.5),"matching affinity multiplies upgraded weapon attack")
	var titan := build.duplicate(true)
	titan.chassis="titan"
	titan=inventory.synchronize(titan)
	var raw := titan.duplicate(true)
	raw.component_stats.front.affinities=[]
	check(is_equal_approx(Parts.health_breakdown(titan).total,Parts.health_breakdown(raw).total*1.2),"matching body affinity multiplies total health")
	check(Parts.energy_report(build).used==2,"wheels cost no energy")
	var duplicate := inventory.synchronize(build,build.equipped.values())
	check(duplicate.equipped.front==build.equipped.front,"both blueprints can select the same collected weapon")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify({"items":inventory.items,"build":build}))
	var copy := Inventory.new()
	copy.items=decoded.items
	var restored := copy.synchronize(decoded.build)
	check(Parts.energy_report(restored)==Parts.energy_report(build) and Parts.health_breakdown(restored)==Parts.health_breakdown(build),"JSON blueprint preserves energy, levels and health")
	check(int(restored.layout_seed)==original_seed,"JSON blueprint preserves exact socket roll")
	inventory.persistence_enabled=true
	inventory.save([build],"user://progression_test.json")
	var disk := Inventory.new()
	var loaded := disk.restore("user://progression_test.json")
	check(loaded and disk.gold==inventory.gold and disk.toolboxes==inventory.toolboxes and disk.items.size()==inventory.items.size(),"disk save and reload preserve currency, toolboxes and owned parts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progression_test.json"))
	for id in Parts.WEAPONS:
		var car := Car.new()
		root.add_child(car)
		car.setup({"chassis":"classic","front":id,"wheels":"grip"},0,Vector2.ZERO,Color.WHITE,null)
		car.freeze_all()
		check(car.weapon_parts().size()==1 and car.weapon_parts()[0].attack_rating==Progression.attack(Parts.WEAPONS[id].attack,1),id+" builds with rated attack")
		car.queue_free()
	for id in Parts.GADGETS:
		var car := Car.new()
		root.add_child(car)
		car.setup({"chassis":"classic","gadget":id,"wheels":"grip"},0,Vector2.ZERO,Color.WHITE,null)
		car.freeze_all()
		check(car.parts.filter(func(p):return p.id==id).size()==1,id+" fits square socket")
		car.queue_free()
	await process_frame
	print("PROGRESSION CHECKS: %d failures" % failures)
	quit(1 if failures else 0)
