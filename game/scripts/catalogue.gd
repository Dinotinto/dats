class_name Catalogue
extends RefCounted
## Authored shapes in chassis-local world coordinates. Rendering and physics share these.

static func bodies() -> Dictionary:
	var specs := {
		"classic": ["Classic", 210, 9.0, 15, Vector2(8,-12), [Vector2(-108,-36),Vector2(-65,-75),Vector2(15,-72),Vector2(125,3),Vector2(-105,3)], "Stable wedge that slips beneath other cars.", "bolt"],
		"sneaky": ["Sneaky", 140, 5.5, 12, Vector2(-10,-8), [Vector2(-80,-35),Vector2(-40,-49),Vector2(45,-41),Vector2(87,-5),Vector2(-80,0)], "Small, light and low; suited to airborne builds.", "nova"],
		"boulder": ["Boulder", 230, 10.0, 14, Vector2(0,-48), [], "Round hull rolls naturally over obstacles.", "tank"],
		"surfer": ["Surfer", 330, 17.0, 18, Vector2(0,-16), [Vector2(-150,-40),Vector2(-125,-65),Vector2(110,-65),Vector2(153,-30),Vector2(135,0),Vector2(-145,0)], "Long wheelbase, low centre of gravity and high stability.", "dash"],
		"titan": ["Titan", 360, 18.0, 20, Vector2(-8,-85), [Vector2(-85,0),Vector2(-82,-150),Vector2(60,-150),Vector2(90,-105),Vector2(88,0)], "Mounts expand with chassis tier. Tall and strong but prone to tipping backward.", "tank"],
		"whale": ["Whale", 300, 15.0, 17, Vector2(0,-22), [Vector2(-125,-28),Vector2(-115,-64),Vector2(-60,-80),Vector2(68,-77),Vector2(128,-42),Vector2(118,-6),Vector2(70,4),Vector2(-80,4)], "Smooth integrated hull and widely spaced wheels.", "spark"],
		"pyramid": ["Pyramid", 250, 11.0, 16, Vector2(0,-40), [Vector2(-110,0),Vector2(-5,-140),Vector2(110,0)], "Tall triangular hull with angled weapon and utility positions.", "patch"],
		"diamond": ["Diamond", 220, 8.0, 13, Vector2(0,-34), [Vector2(-140,-42),Vector2(0,-105),Vector2(140,-42),Vector2(0,15)], "Narrow lower hull; unstable without small wheels.", "nova"],
	}
	var out := {}
	for id in specs:
		var s: Array = specs[id]
		var pts := PackedVector2Array(s[5])
		if id == "boulder":
			pts = Art.circle(Vector2(0,-55), 76.0, 48)
		var width := 88.0 if id in ["surfer","whale"] else (48.0 if id == "sneaky" else 65.0)
		if id == "diamond": width = 48.0
		var top := 0.0
		for point in pts: top=minf(top,point.y)
		var radius := 115.0 if id=="titan" else 70.0
		out[id] = {"name":s[0],"durability":float(s[1]),"mass":s[2],"energy":s[3],"com":s[4]/0.42,"polygon":pts,"origin":Vector2.ZERO,"chin":Vector2(-15,top-6)/0.42,"face":100.0,"driver":s[7],"paint":Color(0.28,0.55,0.7),"desc":s[6],"art_id":"wedge","friction":0.95 if id=="boulder" else 0.35,"wheels":[[Vector2(-width,0)/0.42,radius],[Vector2(width,0)/0.42,radius]],"mounts":{"gadget":Vector2(-width,-30)/0.42},"procedural":true}
	for id in out: CatalogueArt.hull(id,out[id])
	return out

static func layout(id: String, _roll: int, tier := 1) -> Array:
	var body: Dictionary=bodies()[id]
	var limits := Progression.slot_limits(tier)
	var ids := ["front","top","attack3","attack4","gadget","gadget2","defence_front","gadget3"]
	if id=="titan": ids=["front","top","attack3","attack4","defence_front","gadget2","gadget","gadget3"]
	var counts := Vector2i.ZERO
	var result := []
	for slot in ids:
		var attack: bool=slot in ["front","top","attack3","attack4"]
		if attack:
			if counts.x>=limits.x: continue
			counts.x+=1
		else:
			if counts.y>=limits.y: continue
			counts.y+=1
		result.append({"id":slot,"type":"attack" if attack else "gadget","label":"Hex · weapon" if attack else "Square · defence/gadget","point":body.art_sockets[slot]})
	return result

static func weapons() -> Dictionary:
	return {
		"balloon_launcher":{"name":"Balloon Launcher","desc":"First shot after 0.7 seconds; fires every 4 seconds. A real hit lifts the struck end for 5 seconds. Shots can miss; no direct damage.","kind":"ranged","attack":0.0,"energy":3,"first_delay":.7,"cooldown":4.0,"projectile_speed":850.0,"recoil":65.0,"knock":0.0,"mass":1.6,"durability":80.0,"procedural":"gun"},
		"net_launcher":{"name":"Net Launcher","desc":"A net impact restrains movement and attacks for five seconds, then releases.","kind":"ranged","attack":0.0,"energy":3,"cooldown":8.0,"projectile_speed":650.0,"recoil":100.0,"knock":0.0,"mass":1.7,"durability":80.0,"procedural":"gun"},
		"flipper_net":{"name":"Flipper Net","desc":"A hit flips and restrains the enemy for five seconds, then lifts and rights it.","kind":"ranged","attack":0.0,"energy":3,"cooldown":9.0,"projectile_speed":600.0,"recoil":100.0,"knock":0.0,"mass":2.0,"durability":80.0,"procedural":"gun"},
		"rocket":{"name":"Rocket","desc":"One explosive rocket each second.","kind":"ranged","attack":65.0,"energy":6,"cooldown":1.0,"projectile_speed":700.0,"recoil":700.0,"knock":750.0,"mass":1.6,"durability":80.0,"procedural":"gun"},
		"double_rocket":{"name":"Double Rocket","desc":"Simultaneous forward and backward rockets.","kind":"ranged","attack":60.0,"energy":7,"cooldown":1.0,"projectile_speed":700.0,"recoil":500.0,"knock":650.0,"mass":2.0,"durability":90.0,"procedural":"gun"},
		"laser":{"name":"Laser","desc":"A collision-tested 100-rated level-one beam every 2.5 seconds.","kind":"ranged","attack":100.0,"energy":3,"cooldown":2.5,"projectile_speed":2400.0,"recoil":150.0,"knock":100.0,"mass":2.0,"durability":90.0,"procedural":"gun"},
		"minigun":{"name":"Minigun","desc":"Attack is maximum DPS. Rounds ramp from four to ten per second, each dealing 10% of the rating.","kind":"ranged","attack":50.0,"energy":2,"cooldown":0.25,"projectile_speed":1400.0,"recoil":80.0,"knock":90.0,"mass":1.8,"durability":90.0,"procedural":"gun"},
		"blade":{"name":"Blade","desc":"A full rotating blade; damage requires edge contact.","kind":"continuous","attack":45.0,"energy":4,"mass":1.5,"durability":90.0,"procedural":"rotor","separate":true},
		"drill":{"name":"Drill","desc":"Heavy continuous damage along its tapered metal bit.","kind":"continuous","attack":60.0,"energy":5,"mass":1.6,"durability":90.0,"procedural":"sword","length":94.0},
		"stinger":{"name":"Stinger","desc":"Long front spike with direct-contact damage.","kind":"continuous","attack":50.0,"energy":4,"mass":1.0,"durability":85.0,"procedural":"sword","length":125.0},
		"chainsaw":{"name":"Chainsaw","desc":"Spools from 25% to full attack over two seconds of contact.","kind":"continuous","attack":100.0,"energy":6,"mass":1.9,"durability":100.0,"procedural":"sword","length":70.0},
	}

static func gadgets() -> Dictionary:
	return {
		"backpedal":{"name":"Backpedal","desc":"Rearward thrust and reversing wheels open a gap from melee opponents.","energy":3,"durability":60.0,"mass":0.8},
		"forklift":{"name":"Forklift","desc":"Contact forks lift and tip. Heavy cars resist; six-second recharge. Front Repulse can interrupt it.","energy":4,"durability":90.0,"mass":2.0,"separate":true},
		"repulse":{"name":"Repulse","desc":"Contact shockwave pushes enemies away and interrupts touching forklifts when charged. Four-second recharge.","energy":4,"durability":80.0,"mass":1.4},
		"harpoon":{"name":"Harpoon","desc":"Must hit before its tensioned cable pulls the enemy closer.","energy":4,"durability":75.0,"mass":1.2,"kind":"ranged","attack":0.0,"cooldown":4.0,"projectile_speed":1000.0,"recoil":150.0,"knock":0.0,"procedural":"gun"},
		"lifter":{"name":"Lifter","desc":"Physical contact attaches a balloon, lifting the enemy machine for 3.5 seconds.","energy":5,"durability":70.0,"mass":1.2},
		"first_aid":{"name":"First Aid Kit","desc":"Once per battle, restores 25% max health below 50% HP.","energy":3,"durability":80.0,"mass":1.0},
	}
