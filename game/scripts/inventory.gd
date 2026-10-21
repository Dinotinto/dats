class_name Inventory
extends RefCounted
## Local owned item instances, immutable socket seeds, currency and permanent fusion awards.
const SAVE_PATH := "user://garage_v2.json"
var gold := 300
var fusion_energy := 10
var toolboxes := {"attack":0,"health":0,"power":0}
var items: Array = []
var next_uid := 1
var blueprints: Array = []
var persistence_enabled := true
var player_level := 1
var player_xp := 0
var wins := 0
var fights := 0
var supply_boxes := 0

func unlocked_tier() -> int:
	return Progression.unlocked_tier(player_level)

func can_use(item: Dictionary, build: Dictionary = {}) -> bool:
	var tier := int(item.get("level", 1))
	if tier > unlocked_tier(): return false
	if build.is_empty() or Parts.CHASSIS.has(item.get("id", "")): return true
	return tier <= int(build.get("component_stats", {}).get("chassis", {}).get("level", 1))

func build_valid(build: Dictionary) -> bool:
	if build.get("rear_wheel", "") == "" or build.get("front_wheel", "") == "": return false
	var seen := []
	for slot in build.get("equipped",{}):
		if Parts.WEAPONS.has(build.get(slot,"")):
			if build.equipped[slot] in seen: return false
			seen.append(build.equipped[slot])
	for item in build.get("component_stats", {}).values():
		if not can_use(item, build): return false
	return Parts.energy_report(build).valid

func award_battle(won: bool) -> String:
	fights += 1
	if won: wins += 1
	var coins := Progression.WIN_GOLD if won else Progression.LOSS_GOLD
	var xp := Progression.WIN_XP if won else Progression.LOSS_XP
	gold += coins
	fusion_energy += 1
	player_xp += xp
	while player_level < Progression.MAX_PLAYER_LEVEL and player_xp >= Progression.xp_required(player_level):
		player_xp -= Progression.xp_required(player_level)
		player_level += 1
	if player_level == Progression.MAX_PLAYER_LEVEL: player_xp = 0
	var extra := ""
	if won and wins % 10 == 0:
		supply_boxes += 1
		extra = " · +1 supply box"
	return "+%d gold · +%d XP%s · player Lv %d (tier %d unlocked)" % [coins, xp, extra, player_level, unlocked_tier()]

func starter(all_parts := false) -> void:
	if all_parts:
		for table in [Parts.CHASSIS,Parts.WEAPONS,Parts.GADGETS,Parts.WHEELS]:
			for id in table: acquire(id,false)
	else:
		for id in Progression.STARTER_IDS: acquire(id,false)

func acquire(id: String, magic := true) -> Dictionary:
	var item := {"uid":str(next_uid),"id":id,"level":1,"xp":0,"fusion_count":0,"rarity":1,"attack_bonus":0.0,"durability_bonus":0.0,"energy_bonus":0,"layout_seed":randi(),"affinities":[]}
	next_uid += 1
	if magic and randf()<0.4:
		item.rarity = 2
		item.affinities = [{"stat":"health","chassis":Catalogue.bodies().keys().pick_random(),"percent":0.20}] if randf()<0.5 else [{"stat":"attack","weapon":Parts.WEAPONS.keys().pick_random(),"percent":0.15}]
	items.append(item)
	return item

func find_item(uid: String) -> Dictionary:
	for item in items:
		if item.uid == uid: return item
	return {}

func synchronize(source: Dictionary, _reserved: Array = []) -> Dictionary:
	var b := source.duplicate(true)
	var equipped: Dictionary = b.get("equipped", {})
	var body := find_item(equipped.get("chassis",""))
	if not body.is_empty() and body.id==b.get("chassis",""):
		b.layout_seed=body.layout_seed
		if not b.has("component_stats"): b.component_stats={}
		b.component_stats.chassis=body.duplicate(true)
	b=Parts.normalize_build(b)
	equipped=b.get("equipped",{})
	var slots := ["chassis","rear_wheel","front_wheel"]
	for socket in Parts.equipment_slots(b): slots.append(socket.id)
	var stats := {}
	var used_weapons := []
	for slot in slots:
		var id: String = b.get(slot, "")
		if id == "": continue
		var item := find_item(equipped.get(slot,""))
		if item.is_empty() or item.id != id or (Parts.WEAPONS.has(id) and item.get("uid","") in used_weapons):
			item = {}
			for candidate in items:
				if candidate.id == id and (not Parts.WEAPONS.has(id) or not candidate.uid in used_weapons):
					item = candidate
					break
			if item.is_empty() or item.id != id:
				if Parts.WEAPONS.has(id):
					b[slot]=""
					equipped.erase(slot)
					continue
				item = acquire(id,false)
			equipped[slot] = item.uid
		if Parts.WEAPONS.has(id): used_weapons.append(item.uid)
		stats[slot] = item.duplicate(true)
		if slot == "chassis": b.layout_seed = item.layout_seed
	b.equipped = equipped
	b.component_stats = stats
	return Parts.normalize_build(b)

func equip(source: Dictionary, slot: String, uid: String) -> Dictionary:
	var item := find_item(uid)
	if item.is_empty(): return source
	if not can_use(item, source): return source
	if not copy_available(source,slot,uid): return source
	var b := source.duplicate(true)
	if not b.has("equipped"): b.equipped = {}
	# Blueprints may reference the same collected part in either car or mount.
	# Upgrading that item updates every blueprint using it.
	b[slot] = item.id
	b.equipped[slot] = uid
	return synchronize(b)

func copy_available(build: Dictionary, slot: String, uid: String) -> bool:
	var item := find_item(uid)
	if not Parts.WEAPONS.has(item.get("id","")): return true
	for mount in build.get("equipped",{}):
		if mount!=slot and build.equipped[mount]==uid: return false
	return true

func fuse(target_uid: String, spare_uid: String, protected: Array) -> String:
	var target := find_item(target_uid)
	var spare := find_item(spare_uid)
	if target.is_empty() or spare.is_empty() or target_uid==spare_uid: return "Choose a spare part."
	if spare_uid in protected: return "Equipped parts cannot be sacrificed."
	if target.id!=spare.id or int(target.level)!=int(spare.level): return "Fusion needs the same part type and tier."
	if int(target.level)>unlocked_tier(): return "This tier is locked."
	var key := "attack_bonus" if Parts.WEAPONS.has(target.id) and Parts.WEAPONS[target.id].attack>0 else "durability_bonus"
	var bonus := Progression.fusion_value(target,spare)
	if bonus<=float(target.get(key,0)): return "This part has reached its fusion cap."
	var cost := fusion_cost(target)
	if fusion_energy<cost: return "Not enough fusion energy."
	fusion_energy -= cost
	target[key] = bonus
	target.fusion_count = int(target.get("fusion_count",0))+1
	items.erase(spare)
	return "Fused permanently · tier unchanged · +%d bonus" % bonus

func fusion_cost(item: Dictionary) -> int:
	return Progression.fusion_cost(item)

func toolbox(uid: String, kind: String) -> String:
	var item := find_item(uid)
	if item.is_empty() or toolboxes.get(kind,0)<=0: return "No toolbox available."
	if kind=="power" and not Parts.CHASSIS.has(item.id): return "Power toolboxes fit bodies only."
	if kind=="attack" and not Parts.WEAPONS.has(item.id): return "Attack toolboxes fit weapons only."
	if kind=="attack" and Parts.WEAPONS[item.id].attack==0: return "Control weapons use effects, not attack damage."
	if kind=="attack" and Progression.attack(Parts.WEAPONS[item.id].attack,int(item.level))+float(item.attack_bonus)>=Progression.attack(Parts.WEAPONS[item.id].attack,int(item.level))*3:
		return "Attack is at this tier's limit. Upgrade its tier first."
	if kind=="health" and Parts.WEAPONS.has(item.id): return "Health toolboxes fit bodies, wheels and gadgets."
	var key: String = {"power":"energy_bonus","attack":"attack_bonus","health":"durability_bonus"}[kind]
	var base: float=Progression.base_rating(item.id,int(item.level))
	if kind!="power" and float(item.get(key,0))>=base*2: return "This part has reached its fusion cap."
	item[key] = item[key]+1 if kind=="power" else minf(base*2,float(item[key])+(5 if kind=="attack" else 25))
	toolboxes[kind] -= 1
	return "Permanent %s bonus applied." % kind

func open_box() -> String:
	if supply_boxes > 0: supply_boxes -= 1
	elif gold >= 500: gold -= 500
	else: return "A supply box costs 500 gold, or earn one every ten wins."
	var pool := Parts.WEAPONS.keys()+Parts.GADGETS.keys()+Catalogue.bodies().keys()+Parts.WHEELS.keys()
	var names := []
	for i in 3:
		var item := acquire(pool.pick_random())
		item.level = randi_range(1, mini(5,unlocked_tier()))
		if item.level<Progression.minimum_tier(item.id): item.id="wood_medium"
		names.append("%s Lv %d" % [Parts.base_for(item.id).name, item.level])
	fusion_energy += 5
	var kind: String = toolboxes.keys().pick_random()
	toolboxes[kind] += 1
	return "Supply box: %s · +1 %s toolbox" % [", ".join(names),kind]

func energy_box() -> String:
	if gold<300: return "An energy box costs 300 gold."
	gold -= 300
	fusion_energy += 10
	return "+10 fusion energy. Chassis capacity is unchanged."

func buy_part(id: String, tier: int) -> String:
	if Parts.base_for(id).is_empty() or tier < 1 or tier > unlocked_tier(): return "That tier is locked."
	if tier<Progression.minimum_tier(id) or tier>5: return "This material or tier is locked."
	var cost := Progression.market_price(id,tier)
	if gold < cost: return "Buying this tier costs %d gold." % cost
	gold -= cost
	var item := acquire(id, false)
	item.level = tier
	return "Bought %s Lv %d." % [Parts.base_for(id).name, tier]

func save(builds: Array, path: String = SAVE_PATH) -> void:
	if not persistence_enabled: return
	blueprints = builds.duplicate(true)
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"version":2,"catalogue_revision":3,"gold":gold,"fusion_energy":fusion_energy,"toolboxes":toolboxes,"items":items,"next_uid":next_uid,"blueprints":blueprints,"progression":{"level":player_level,"xp":player_xp,"wins":wins,"fights":fights,"supply_boxes":supply_boxes}}))

func restore(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0)!=2: return false
	gold = int(data.gold)
	fusion_energy = int(data.get("fusion_energy",10))
	toolboxes = data.toolboxes
	for kind in toolboxes: toolboxes[kind]=int(toolboxes[kind])
	items = data.items
	for item in items:
		for key in ["level","xp","fusion_count","rarity","energy_bonus","layout_seed"]: item[key]=int(item.get(key,0))
		item.level = clampi(int(item.level), 1, Progression.MAX_PART_LEVEL)
	next_uid = int(data.next_uid)
	if false: # Legacy inventories are preserved; no catalogue-wide grants.
		for id in ["balloon_launcher","net_launcher","flipper_net"]:
			if not items.any(func(item):return item.id==id): acquire(id,false)
	blueprints = data.blueprints
	var profile: Dictionary = data.get("progression", {})
	var legacy_tier := 1
	for item in items: legacy_tier = maxi(legacy_tier, int(item.level))
	player_level = clampi(int(profile.get("level", (legacy_tier-1)*10+1)), 1, Progression.MAX_PLAYER_LEVEL)
	player_xp = maxi(0, int(profile.get("xp", 0)))
	wins = maxi(0, int(profile.get("wins", 0)))
	fights = maxi(0, int(profile.get("fights", 0)))
	supply_boxes = maxi(0, int(profile.get("supply_boxes", 0)))
	return true
