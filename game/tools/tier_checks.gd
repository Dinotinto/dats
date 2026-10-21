extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in 6:
		await physics_frame
		await process_frame
func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
func checks() -> void:
	var inv := Inventory.new()
	inv.persistence_enabled = false
	inv.starter(true)
	inv.gold=10000
	inv.toolboxes={"attack":4,"health":4,"power":3}
	for tier in range(1, 11):
		var legal := true
		var band := Progression.attack_band(tier)
		for id in Parts.WEAPONS:
			if Parts.WEAPONS[id].attack==0: continue
			var data := Parts.rated_data(Parts.WEAPONS[id], {"component_stats":{"front":{"level":tier}}}, "front")
			legal = legal and data.attack >= band.x and data.attack <= band.y
		check(legal, "every damaging weapon stays in tier %d attack band before bonuses" % tier)
	var laser := inv.acquire("laser", false)
	var body := inv.acquire("classic", false)
	var build := inv.synchronize({"chassis":"classic", "front":"laser", "wheels":"rubber_medium", "equipped":{"chassis":body.uid,"front":laser.uid}})
	check(Parts.rated_data(Parts.WEAPONS.laser,build,"front").attack==100 and Parts.energy_report(build).used==3,"level-one laser is 100 attack and three energy")
	laser.attack_bonus=500
	laser.affinities=[{"stat":"attack","weapon":"laser","percent":0.15}]
	build=inv.synchronize(build)
	check(Parts.rated_data(Parts.WEAPONS.laser,build,"front").attack==300,"toolbox and magic bonuses cannot exceed three times base attack")
	laser.attack_bonus=0
	laser.affinities=[]
	var low_energy := Parts.energy_report(build)
	laser.level=5
	body.level=5
	build=inv.synchronize(build)
	var high_energy := Parts.energy_report(build)
	check(high_energy.used==7 and high_energy.capacity==low_energy.capacity+16,"level-five parts cost more energy and chassis capacity rises")
	check(not inv.can_use(laser,build),"player level one cannot use a level-five part")
	inv.player_level=41
	check(inv.can_use(laser,build),"player level 41 unlocks level-five equipment on a level-five body")
	body.level=1
	build=inv.synchronize(build)
	check(not inv.can_use(laser,build),"higher-tier weapons require a supporting chassis tier")
	check(Progression.unlocked_tier(10)==1 and Progression.unlocked_tier(11)==2 and Progression.unlocked_tier(100)==10,"player levels one through 100 unlock ten equipment tiers")
	inv.player_level=1
	laser.level=1
	var spare := inv.acquire("stinger",false)
	var coins := inv.gold
	check(inv.fuse(laser.uid,spare.uid,[]).begins_with("Fusion needs") and inv.gold==coins and not inv.find_item(spare.uid).is_empty(),"mismatched fusion consumes neither gold nor spare")
	inv.player_level=11
	spare=inv.acquire("laser",false)
	check(inv.fuse(laser.uid,spare.uid,[]).begins_with("Fused") and laser.level==1 and laser.attack_bonus==60,"matching fusion increases attack while preserving tier")
	inv.player_level=1
	inv.player_xp=0
	coins=inv.gold
	inv.award_battle(true)
	inv.award_battle(true)
	inv.award_battle(true)
	check(inv.player_level==1 and inv.gold==coins+180 and inv.supply_boxes==0 and inv.wins==3,"three wins grant slower XP and gold")
	for i in 7: inv.award_battle(true)
	check(inv.supply_boxes==1,"ten wins grant a supply box")
	coins=inv.gold
	inv.open_box()
	check(inv.gold==coins and inv.supply_boxes==0,"earned supply box opens without spending gold")
	inv.player_level=21
	coins=inv.gold
	inv.buy_part("laser",3)
	check(inv.gold==coins-Progression.market_price("laser",3) and inv.items.back().level==3,"gold shop sells unlocked higher-tier parts")
	coins=inv.gold
	check(inv.buy_part("laser",4)=="That tier is locked." and inv.gold==coins,"shop rejects locked tiers before spending currency")
	inv.persistence_enabled=true
	inv.save([build],"user://tier_test.json")
	var restored := Inventory.new()
	check(restored.restore("user://tier_test.json") and restored.player_level==inv.player_level and restored.player_xp==inv.player_xp and restored.wins==10,"player progression and rewards survive disk reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tier_test.json"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await settle()
	main.inventory.persistence_enabled=false
	var garage: GarageUI = main._garage
	var gadget: Dictionary = main.inventory.acquire("backpedal",false)
	garage.fit_item("gadget",gadget.uid)
	await settle()
	garage.card_click(gadget)
	await settle()
	check(garage.selected_slot=="gadget" and not garage.remove_button.disabled,"clicking a fitted gadget selects it for removal")
	click(garage.remove_button.get_global_rect().get_center())
	await settle()
	check(main.builds[0].gadget=="" and garage.car.parts.all(func(p):return p.id!="backpedal"),"Remove this part detaches the selected gadget from the build and physics car")
	var rocket: Dictionary = main.inventory.acquire("rocket",false)
	garage.fit_item("front",rocket.uid)
	await settle()
	garage.team=1
	garage.rebuild()
	await settle()
	garage.fit_item("front",rocket.uid)
	await settle()
	check(main.builds[0].equipped.front==rocket.uid and main.builds[1].equipped.front==rocket.uid,"both cars can fit the same collected weapon")
	garage.card_click(rocket)
	await settle()
	click(garage.remove_button.get_global_rect().get_center())
	await settle()
	check(main.builds[1].front=="" and main.builds[0].front=="rocket","removing a shared weapon affects only the selected car")
	garage.select_slot("front_wheel")
	await settle()
	click(garage.remove_button.get_global_rect().get_center())
	await settle()
	check(main.builds[1].front_wheel=="" and garage.car.wheels.size()==1 and garage.fight.disabled,"wheel removal persists and incomplete cars cannot fight")
	var wheel: Dictionary = main.inventory.acquire("rubber_medium",false)
	garage.fit_item("front_wheel",wheel.uid)
	await settle()
	check(garage.car.wheels.size()==2 and not garage.fight.disabled,"reattaching a wheel restores a valid car")
	# Native click on the visible rocket nose, away from its mount button.
	garage.fit_item("front",rocket.uid)
	await settle()
	var weapon: Car.Part = garage.car.weapon_parts()[0]
	var art: Dictionary = CatalogueArt.equipment("rocket")
	var local: Vector2 = garage.car._px(Parts.mount_point(garage.current_build().chassis,"front",garage.current_build())) + (Vector2(art.size.x*.88,art.size.y*.5)-art.anchor)*art.scale
	var screen: Vector2 = garage.viewport.get_canvas_transform()*garage.car.chassis.to_global(garage.car._m(local))
	garage.selected_slot="gadget"
	click(garage.workspace.global_position+screen)
	await settle()
	check(garage.selected_slot=="front","clicking the weapon artwork selects its actual mount")
	# Exercise the actual battle-finished handler, return to garage, and saved profile.
	var old_gold: int = main.inventory.gold
	var old_fights: int = main.inventory.fights
	main._start_battle()
	check(is_instance_valid(main._battle),"valid shared-part blueprints can enter a real battle")
	var result: Dictionary = await main._battle.finished
	check(main.inventory.gold==old_gold+(Progression.WIN_GOLD if result.winner==0 else Progression.LOSS_GOLD) and main.inventory.fights==old_fights+1 and main.reward_message.contains("XP"),"completed battle awards outcome-based XP and gold through the game handler")
	main._show_garage()
	await settle()
	check(main._garage.message==main.reward_message and main._garage.all_builds_valid(),"returning to the garage shows earned rewards and retains valid builds")
	print("TIER AND REMOVAL CHECKS: %d failures" % failures)
	quit(1 if failures else 0)
