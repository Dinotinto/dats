extends SceneTree
var failures := 0
class QaCloud extends CloudGarage:
	func configured() -> bool: return true
	func _ready() -> void:
		project_url="http://127.0.0.1:18766"
		public_key="local-test"
		gateway="http://127.0.0.1:18767"
		remember_session=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	var inv := Inventory.new()
	inv.persistence_enabled=false
	inv.starter()
	check(inv.items.size()==7,"limited offline starter mirrors cloud starter")
	for i in 7: inv.award_battle(true)
	check(inv.player_level==1,"seven wins do not advance player level")
	inv.award_battle(true)
	check(inv.player_level==2 and inv.player_xp==20,"eight wins cross first threshold with carry")
	check(Progression.unlocked_tier(10)==1 and Progression.unlocked_tier(11)==2 and Progression.unlocked_tier(41)==5,"tier gates at levels 11 and 41")
	var target := {"id":"laser","level":1,"attack_bonus":0,"durability_bonus":0,"xp":0}
	check(Progression.fusion_value(target,target)==60,"100 laser fusion gains sixty bonus")
	var data := Parts.rated_data(Parts.WEAPONS.laser,{"component_stats":{"front":{"id":"laser","level":1,"attack_bonus":60}}},"front")
	check(data.attack==160,"actual combat resolver uses fused 160 attack")
	for tier in range(1,6):
		var rated := Parts.rated_data(Parts.WEAPONS.laser,{"component_stats":{"front":{"id":"laser","level":tier}}},"front")
		check(rated.attack==[100,250,500,1000,2000][tier-1],"laser tier %d starting rating" % tier)
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._show_auth()
	main.cloud.queue_free()
	var cloud:=QaCloud.new()
	main.add_child(cloud)
	main.cloud=cloud
	var signed: Dictionary=await cloud.authenticate("alice@example.test","qa",false)
	await cloud.call_rpc("dats_identity",{"p_action":"set","p_name":"alice_qa"})
	main.enter_cloud(signed.data)
	main.social.timer=999
	main._show_garage()
	await process_frame
	check(main.inventory.items.size()==7,"new cloud user sees only seven owned parts")
	main.show_market()
	var market: DatsMarket=main.market_dialog
	market.category="wheels"
	market.refresh()
	await create_timer(.3).timeout
	root.get_texture().get_image().save_png("D:/DATS/screenshots/economy_market_wheels.png")
	main.builds[0].front_wheel=""
	main.builds[0].equipped.erase("front_wheel")
	await market.purchase("buy",{"id":"wood_medium","tier":1})
	check(main.inventory.gold==130 and main.inventory.items.size()==8,"market purchase uses real server price and updates inventory")
	check(main.builds[0].front_wheel=="","shopping preserves incomplete garage draft")
	main.builds[0].front_wheel="wood_medium"
	main.builds[0].equipped.front_wheel=main.builds[0].equipped.rear_wheel
	var uid: String=main.builds[0].equipped.rear_wheel
	var spare: String=""
	for item in main.inventory.items:
		if item.id=="wood_medium" and item.uid!=uid: spare=item.uid
	market.hide()
	await main.economy("fuse",{"uid":uid,"spare":spare})
	check(main.inventory.fusion_energy==5 and main.inventory.items.size()==7,"cloud fusion spends energy and consumes spare")
	check(main.builds[0].component_stats.rear_wheel.durability_bonus==33,"cloud fusion refreshes fitted tyre health")
	main._garage.selected_uid=uid
	main._garage.upgrade_open=true
	main._garage.rebuild()
	await create_timer(.3).timeout
	root.get_texture().get_image().save_png("D:/DATS/screenshots/economy_garage.png")
	main.show_market()
	main.market_dialog.category="weapons"
	main.market_dialog.tier=2
	main.market_dialog.refresh()
	await create_timer(.3).timeout
	root.get_texture().get_image().save_png("D:/DATS/screenshots/economy_market_locked.png")
	main.queue_free()
	await process_frame
	print("ECONOMY CLIENT failures=%d" % failures)
	quit(1 if failures else 0)
