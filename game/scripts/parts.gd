class_name Parts
extends RefCounted
## Part catalogue. Art positions are in sprite pixels (see tools/art_build.gd); everything is
## authored for a car facing +x and mirrored automatically for the right-hand car.

## World units per sprite pixel.
const SCALE := 0.42
const EQUIPMENT_SLOT_IDS := ["front", "top", "attack3", "attack4", "defence", "gadget", "gadget2", "defence_front", "gadget3"]

# Combat mount count is a chassis property. Booster sockets are separate utility mounts.
const MOUNTS := {
	"wedge": [{"id": "front", "label": "A1 Low attack", "type": "attack", "point": Vector2(566, 213)}, {"id": "top", "label": "A2 High attack", "type": "attack", "point": Vector2(470, 150)}, {"id": "defence", "label": "D1 Defence", "type": "defence", "point": Vector2(590, 270)}],
	"bruiser": [{"id": "front", "label": "A1 Low attack", "type": "attack", "point": Vector2(405, 300)}, {"id": "top", "label": "A2 High attack", "type": "attack", "point": Vector2(318, 190)}, {"id": "defence", "label": "D1 Defence", "type": "defence", "point": Vector2(445, 330)}],
	"scrapper": [{"id": "front", "label": "A1 Attack", "type": "attack", "point": Vector2(598, 245)}, {"id": "defence", "label": "D1 Defence", "type": "defence", "point": Vector2(625, 295)}],
	"ram": [{"id": "front", "label": "A1 Attack", "type": "attack", "point": Vector2(548, 300)}, {"id": "defence", "label": "D1 Defence", "type": "defence", "point": Vector2(570, 320)}],
}

const DEFENCES := {
	"armour_plate": {"name": "Armour plate", "desc": "Compact front armour. Its durability contributes to total health.", "durability": 100.0, "mass": 1.8, "half_height": 25.0},
	"shield": {"name": "Shield", "desc": "Tall, heavy front shield. Its durability contributes to total health.", "durability": 160.0, "mass": 3.0, "half_height": 45.0},
}

# origin: sprite pixel used as the chassis body origin (between the wheel hubs).
# com: centre of mass, sprite pixels relative to origin (lower = harder to flip).
# wheels: [hub pixel, radius px]. mounts: where weapons/gadget attach.
static var CHASSIS := {
	"wedge": {
		"name": "Wedge", "driver": "bolt", "paint": Color(0.25, 0.45, 0.85),
		"desc": "Light and quick with a long sloped nose that slides under enemies.",
		"durability": 200.0, "mass": 9.0,
		"origin": Vector2(372, 264), "com": Vector2(10, -10), "chin": Vector2(368, 113), "face": 110.0,
		"wheels": [[Vector2(229, 258), 84.0], [Vector2(515, 271), 73.0]],
		"mounts": {"front": Vector2(566, 213), "top": Vector2(470, 150), "gadget": Vector2(178, 200)},
	},
	"bruiser": {
		"name": "Bruiser", "driver": "tank", "paint": Color(0.78, 0.24, 0.2),
		"desc": "Heavy armoured box. Wins pushing contests, but its flat front is easy to climb.",
		"durability": 280.0, "mass": 14.0,
		"origin": Vector2(240, 376), "com": Vector2(0, -55), "chin": Vector2(236, 160), "face": 95.0,
		"wheels": [[Vector2(100, 376), 88.0], [Vector2(381, 376), 86.0]],
		"mounts": {"front": Vector2(405, 300), "top": Vector2(318, 190), "gadget": Vector2(32, 250)},
	},
	"scrapper": {
		"name": "Scrapper", "driver": "patch", "paint": Color(0.25, 0.68, 0.68),
		"desc": "Very light buggy with a huge rear wheel. Fast, but gets shoved around.",
		"durability": 180.0, "mass": 7.0,
		"origin": Vector2(394, 302), "com": Vector2(-30, -30), "chin": Vector2(385, 112), "face": 110.0,
		"wheels": [[Vector2(228, 287), 101.0], [Vector2(560, 317), 69.0]],
		"mounts": {"front": Vector2(598, 245), "top": Vector2(527, 185), "gadget": Vector2(205, 160)},
	},
	"ram": {
		"name": "Ram", "driver": "dash", "paint": Color(0.95, 0.7, 0.15),
		"desc": "Long and heavy with big wheels and a low wedge front.",
		"durability": 240.0, "mass": 12.0,
		"origin": Vector2(288, 332), "com": Vector2(0, -25), "chin": Vector2(300, 192), "face": 105.0,
		"wheels": [[Vector2(121, 328), 106.0], [Vector2(455, 337), 95.0]],
		"mounts": {"front": Vector2(548, 300), "top": Vector2(405, 190), "gadget": Vector2(20, 255)},
	},
}

# "chin" anchor (in chassis.chin) is the default driver's chin; "face" its face width in pixels.
const DRIVERS := {
	"bolt": "Bolt", "nova": "Nova", "tank": "Tank", "patch": "Patch", "dash": "Dash", "spark": "Spark",
}

# Seated driver art (res://art/seat_<id>.png): chin pixel and face width, used to fit any driver
# into any cockpit at the size of that car's original driver.
const SEATS := {
	"bolt": {"chin": Vector2(285, 250), "face": 195.0},
	"nova": {"chin": Vector2(245, 255), "face": 215.0},
	"tank": {"chin": Vector2(325, 232), "face": 220.0},
	"patch": {"chin": Vector2(265, 262), "face": 220.0},
	"dash": {"chin": Vector2(300, 262), "face": 230.0},
	"spark": {"chin": Vector2(275, 272), "face": 225.0},
}

# size: multiplier on the drawn wheel. speed: top speed in world units/s. torque: motor strength.
const WHEELS := {
	"wood_small": {"name": "Small wood", "desc": "Light, fragile wooden wheel.", "size": 0.72, "durability": 45.0, "mass": 0.65, "speed": 550.0, "torque": 240000.0, "friction": 0.85, "material": "wood"},
	"wood_medium": {"name": "Medium wood", "desc": "Light, fragile wooden wheel.", "size": 1.0, "durability": 55.0, "mass": 0.9, "speed": 520.0, "torque": 260000.0, "friction": 0.85, "material": "wood"},
	"wood_large": {"name": "Large wood", "desc": "High clearance, low durability.", "size": 1.28, "durability": 65.0, "mass": 1.2, "speed": 490.0, "torque": 300000.0, "friction": 0.85, "material": "wood"},
	"rubber_small": {"name": "Small rubber", "desc": "Low ride height with strong grip.", "size": 0.72, "durability": 80.0, "mass": 0.8, "speed": 550.0, "torque": 280000.0, "friction": 1.4, "material": "rubber"},
	"rubber_medium": {"name": "Medium rubber", "desc": "Balanced clearance and strong grip.", "size": 1.0, "durability": 100.0, "mass": 1.2, "speed": 510.0, "torque": 340000.0, "friction": 1.4, "material": "rubber"},
	"rubber_large": {"name": "Large rubber", "desc": "High clearance, grip and a higher centre of gravity.", "size": 1.28, "durability": 120.0, "mass": 1.6, "speed": 480.0, "torque": 400000.0, "friction": 1.4, "material": "rubber"},
	"metal_small": {"name": "Small metal", "desc": "Durable and heavy; moderate grip.", "size": 0.72, "durability": 130.0, "mass": 1.6, "speed": 500.0, "torque": 300000.0, "friction": 0.7, "material": "metal"},
	"metal_medium": {"name": "Medium metal", "desc": "Durable and heavy; moderate grip.", "size": 1.0, "durability": 160.0, "mass": 2.2, "speed": 470.0, "torque": 380000.0, "friction": 0.7, "material": "metal"},
	"metal_large": {"name": "Large metal", "desc": "Maximum durability and weight, modest traction.", "size": 1.28, "durability": 190.0, "mass": 2.9, "speed": 440.0, "torque": 440000.0, "friction": 0.7, "material": "metal"},
	"sprint": {
		"name": "Sprint", "desc": "Slightly smaller, faster wheels.",
		"size": 0.9, "durability": 70.0, "mass": 0.9, "speed": 520.0, "torque": 260000.0, "friction": 1.0,
	},
	"grip": {
		"name": "Grip", "desc": "Full-size wheels with more grip and pushing torque.",
		"size": 1.0, "durability": 100.0, "mass": 1.3, "speed": 420.0, "torque": 380000.0, "friction": 1.35,
	},
}

# attack rating: damage per impact or per second of continuous blade contact.
# Durability is local part strength; body, tyres and defences also contribute to total health.
# kind "impact": exact rated damage on a qualifying contact, with a per-enemy cooldown.
# kind "continuous": exact rated damage per second while touching.
# Weapons with "arm" are separate swinging bodies; the rest are fixed to the chassis.
# anchor: sprite pixel that sits on the mount. tip: hitbox centre (px, relative to anchor).
static var WEAPONS := {
	"short_sword": {"name": "Short sword", "desc": "Fixed horizontal blade. Attack rating is damage per second of contact.", "kind": "continuous", "durability": 90.0, "attack": 30.0, "mass": 0.8, "procedural": "sword", "length": 85.0},
	"long_sword": {"name": "Long sword", "desc": "Long, heavy horizontal blade. Attack rating is damage per second of contact.", "kind": "continuous", "durability": 110.0, "attack": 45.0, "mass": 1.5, "procedural": "sword", "length": 140.0},
	"cannon": {"name": "Cannon", "desc": "Heavy shells and strong recoil. Attack rating is damage per impact.", "kind": "ranged", "durability": 100.0, "attack": 60.0, "mass": 2.2, "procedural": "gun", "cooldown": 1.2, "projectile_speed": 850.0, "recoil": 1200.0, "knock": 350.0},
	"blaster": {"name": "Blaster", "desc": "Fast bolts. Attack rating is damage per impact.", "kind": "ranged", "durability": 75.0, "attack": 20.0, "mass": 1.0, "procedural": "gun", "cooldown": 0.4, "projectile_speed": 1300.0, "recoil": 260.0, "knock": 280.0},
	"hook": {"name": "Grappling hook", "desc": "Pulls on impact, no attack damage. Cable releases after 3 seconds or beyond 700 units.", "kind": "ranged", "durability": 85.0, "attack": 0.0, "mass": 1.0, "procedural": "gun", "cooldown": 4.0, "projectile_speed": 1000.0, "recoil": 150.0, "knock": 0.0},
	"lance": {
		"name": "Lance", "desc": "Long reach. Attack rating is damage per second of blade contact.",
		"kind": "continuous", "durability": 80.0, "attack": 35.0, "mass": 0.8,
		"angles": {"front": 0.0, "top": -28.0},
		"sprite": "weapon_lance", "anchor": Vector2(6, 43),
		"tip": Vector2(226, 0), "tip_radius": 28.0,
	},
	"saw": {
		"name": "Saw", "desc": "Short reach. Grinds continuously while touching.",
		"kind": "continuous", "durability": 95.0, "attack": 40.0, "mass": 1.4,
		"angles": {"front": 0.0, "top": -40.0},
		"sprite": "weapon_saw_arm", "anchor": Vector2(2, 35),
		"disc": "weapon_saw_disc", "disc_at": Vector2(190, 3), "disc_radius": 104.0,
		"tip": Vector2(190, 3), "tip_radius": 116.0,
	},
	"hammer": {
		"name": "Hammer", "desc": "Swings when close. Big hits that can flip enemies.",
		"kind": "impact", "durability": 110.0, "attack": 60.0, "mass": 1.8, "arm": true,
		"min_speed": 140.0, "cooldown": 0.5, "knock": 1100.0,
		"sprite": "weapon_hammer", "anchor": Vector2(22, 133), "sprite_angle": 19.5, "art_scale": 1.25,
		# [rest angle, strike angle] in degrees relative to the chassis facing direction.
		"arc": {"front": [12.0, -80.0], "top": [-100.0, 20.0]},
		"trigger_range": 330.0, "strike_speed": 14.0, "return_speed": 5.0, "rest_time": 0.6,
		"tip": Vector2(122, 0), "tip_radius": 62.0,
	},
}

static var GADGETS := {
	"booster": {
		"name": "Booster", "desc": "Rocket burst every few seconds.",
		"durability": 50.0, "mass": 0.6, "impulse": 1600.0, "interval": 2.4,
		"sprite": "gadget_booster", "anchor": Vector2(173, 55),
		"flame": "gadget_booster_flame", "flame_anchor": Vector2(70, 55),
	},
}


static func _static_init() -> void:
	CHASSIS.merge(Catalogue.bodies())
	WEAPONS.merge(Catalogue.weapons())
	GADGETS.merge(Catalogue.gadgets())
	for id in CHASSIS:
		if not CHASSIS[id].has("energy"): CHASSIS[id].energy = 20
	for id in WEAPONS:
		WEAPONS[id].attack = clampf(WEAPONS[id].attack, 40, 100) if WEAPONS[id].attack > 0 else 0.0
		WEAPONS[id].energy = 3 if WEAPONS[id].attack >= 80 else 2
	GADGETS.booster.energy = 2
	GADGETS.booster.desc = "One forward launch burst at the start of battle."
	GADGETS.merge(DEFENCES.duplicate(true))
	for id in DEFENCES: GADGETS[id].energy = 2
	for id in GADGETS: GADGETS[id].energy = mini(2, GADGETS[id].energy)

static func mount_slots(chassis_id: String, build: Dictionary = {}) -> Array:
	var tier := int(build.get("component_stats",{}).get("chassis",{}).get("level",1))
	var limits := Progression.slot_limits(tier)
	if not MOUNTS.has(chassis_id): return Catalogue.layout(chassis_id,int(build.get("layout_seed",hash(chassis_id))),tier)
	var sockets: Array=MOUNTS[chassis_id].duplicate(true)
	for id in ["attack3","attack4","gadget2","gadget3"]:
		var attack: bool=id.begins_with("attack")
		sockets.append({"id":id,"type":"attack" if attack else "gadget","label":"Hex · weapon" if attack else "Square · defence/gadget","point":CHASSIS[chassis_id].chin+Vector2(75 if attack else -35,55 if id.ends_with("3") else 0)})
	var counts := Vector2i.ZERO
	var result := []
	for socket in sockets:
		if socket.type=="attack":
			if counts.x>=limits.x: continue
			counts.x+=1
		else:
			# Legacy bodies have an additional rear utility mount outside this table.
			if counts.y>=limits.y-(1 if MOUNTS.has(chassis_id) else 0): continue
			counts.y+=1
		result.append(socket)
	return result


static func mount_type(chassis_id: String, slot: String, build: Dictionary = {}) -> String:
	if slot == "gadget" and MOUNTS.has(chassis_id):
		return "utility"
	for mount in mount_slots(chassis_id, build):
		if mount.id == slot:
			return mount.type
	return ""


static func options_for_mount(chassis_id: String, slot: String, build: Dictionary = {}) -> Array:
	match mount_type(chassis_id, slot, build):
		"attack": return [""] + WEAPONS.keys()
		"defence": return [""] + GADGETS.keys()
		"utility": return [""] + GADGETS.keys()
		"gadget": return [""] + GADGETS.keys()
	return [""]


static func mount_point(chassis_id: String, slot: String, build: Dictionary = {}) -> Vector2:
	if slot == "gadget" and MOUNTS.has(chassis_id):
		return CHASSIS[chassis_id].mounts.gadget
	for mount in mount_slots(chassis_id, build):
		if mount.id == slot:
			return mount.point
	return Vector2.ZERO


## One authoritative validation path for UI, saved builds, tests and physics construction.
static func normalize_build(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	if not CHASSIS.has(result.get("chassis", "")):
		result.chassis = "wedge"
	for slot in EQUIPMENT_SLOT_IDS:
		var id: String = result.get(slot, "")
		result[slot] = id if id in options_for_mount(result.chassis, slot, result) else ""
		if result[slot]=="":
			if result.has("component_stats"): result.component_stats.erase(slot)
			if result.has("equipped"): result.equipped.erase(slot)
	for slot in ["rear_wheel", "front_wheel"]:
		var id: String = result.get(slot, result.get("wheels", "grip"))
		result[slot] = id if id == "" or WHEELS.has(id) else "grip"
		if result[slot] == "":
			if result.has("component_stats"): result.component_stats.erase(slot)
			if result.has("equipped"): result.equipped.erase(slot)
	return result


## One resolver for item levels, permanent toolbox awards and matching affinity multipliers.
static func rated_data(base: Dictionary, build: Dictionary, slot: String) -> Dictionary:
	var result := base.duplicate(true)
	var bonuses: Dictionary = build.get("rating_upgrades", {}).get(slot, {})
	var item: Dictionary = build.get("component_stats", {}).get(slot, {})
	var tier := clampi(int(item.get("level", 1)), 1, Progression.MAX_PART_LEVEL)
	var multiplier := pow(2.0, tier - 1)
	for key in ["durability", "attack"]:
		var baseline: float = Progression.attack(base.get(key, 0.0), tier) if key == "attack" else base.get(key, 0.0) * multiplier
		result[key] = maxf(0.0, baseline + maxf(0.0, bonuses.get(key, 0.0)) + item.get(key + "_bonus", 0.0))
	result.energy = Progression.energy(int(base.get("energy", 0)), tier, slot == "chassis" or CHASSIS.has(item.get("id", "")), slot in ["rear_wheel", "front_wheel"] or WHEELS.has(item.get("id", "")))
	if WEAPONS.has(item.get("id","")) and base.get("attack",0)==0 and base.has("cooldown"):
		var base_hp: float=maxf(1,float(base.get("durability",1))*multiplier)
		result.cooldown=float(base.cooldown)/(1+.1*(tier-1)+.15*minf(2,float(item.get("durability_bonus",0))/base_hp))
	var seen := {}
	for source in build.get("component_stats", {}).values():
		var uid: String = str(source.get("uid", ""))
		if uid != "" and seen.has(uid): continue
		if uid != "": seen[uid] = true
		for bonus in source.get("affinities", []):
			var matches_body: bool = bonus.get("chassis", "") == build.get("chassis", "")
			var matches_weapon: bool = bonus.get("weapon", "") == build.get(slot, "")
			if bonus.stat == "health" and matches_body: result.durability *= 1.0 + bonus.percent
			if bonus.stat == "attack" and matches_weapon: result.attack *= 1.0 + bonus.percent
	if base.get("attack", 0.0) > 0:
		result.attack = minf(result.attack, Progression.attack(base.get("attack",0),tier)*3)
	return result


static func health_breakdown(source: Dictionary) -> Dictionary:
	var b := normalize_build(source)
	var body: float = rated_data(CHASSIS[b.chassis], b, "chassis").durability
	var tyres := 0.0
	for slot in ["rear_wheel", "front_wheel"]:
		if WHEELS.has(b[slot]): tyres += rated_data(WHEELS[b[slot]], b, slot).durability
	var defence := 0.0
	for mount in equipment_slots(b):
		if mount.type != "attack" and b.get(mount.id, "") != "":
			defence += rated_data(GADGETS[b[mount.id]], b, mount.id).durability
	return {"body": body, "tyres": tyres, "defence": defence, "total": body + tyres + defence}

static func equipment_slots(build: Dictionary) -> Array:
	var sockets := mount_slots(build.chassis, build).duplicate(true)
	if MOUNTS.has(build.chassis): sockets.append({"id":"gadget","label":"Square · gadget","type":"utility","point":CHASSIS[build.chassis].mounts.gadget})
	return sockets

static func base_for(id: String) -> Dictionary:
	for table in [CHASSIS,WEAPONS,GADGETS,WHEELS]:
		if table.has(id): return table[id]
	return {}

static func energy_report(build: Dictionary) -> Dictionary:
	var b := normalize_build(build)
	var item: Dictionary = b.get("component_stats", {}).get("chassis", {})
	var capacity: int = rated_data(CHASSIS[b.chassis], b, "chassis").energy + int(item.get("energy_bonus",0))
	var used := 0
	for socket in equipment_slots(b):
		used += int(rated_data(base_for(b.get(socket.id, "")), b, socket.id).energy) if b.get(socket.id, "") != "" else 0
	return {"used":used,"capacity":capacity,"valid":used<=capacity}




