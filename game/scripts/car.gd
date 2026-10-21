class_name Car
extends Node2D
## A battle car assembled from a build dictionary:
## {"chassis": id, "wheels": id, "front": weapon id or "", "top": weapon id or "", "gadget": id or ""}
## The car node itself stays at the origin; its physics bodies move in world space.
## Legacy sprites use traced outlines; new hulls and equipment share authored art/collision shapes.

const LAYER_WORLD := 1
const BODY_LAYERS := [2, 4]
const HURT_LAYERS := [8, 16]
const WEAPON_LAYERS := [32, 64]
const METAL := Art.STEEL
## Driving backwards (to push an enemy that got behind us) is a little slower.
const REVERSE_FACTOR := 0.85


class Part:
	var kind := ""          # chassis, wheel, weapon, gadget
	var id := ""
	var label := ""
	var slot := ""
	var data := {}
	var hp := 0.0
	var max_hp := 0.0
	var attack_rating := 0.0
	var body: RigidBody2D
	var joint: Joint2D
	var nodes: Array = []    # shapes, sprites and areas owned by this part
	var visuals: Array = []  # sprites that flash when hit
	var alive := true
	var damage_dealt := 0.0
	var damage_taken := 0.0
	var hit_times := {}
	var last_flash := -1.0
	var state := {}


var team := 0
var restrained := false
var control_immunity := 0.0
var dir := 1.0
var color := Color.WHITE
var build := {}
var battle: Node
var enemy: Car
var alive := true
var health := 0.0
var max_health := 0.0
var chassis: RigidBody2D
var chassis_part: Part
var parts: Array = []
var wheels: Array = []
var hitboxes: Array = []
var flipped_time := 0.0
var reversing_time := 0.0
var last_hit_by := ""
var last_hit_rating := 0.0
var _elapsed := 0.0
var _spinners: Array = []
var _flames: Array = []
var _boost_flash := 0.0
var _origin_px := Vector2.ZERO
var driver_actor: DriverActor
var driver_ejected := false


func setup(p_build: Dictionary, p_team: int, spawn: Vector2, p_color: Color, p_battle: Node) -> void:
	build = Parts.normalize_build(p_build)
	max_health = Parts.health_breakdown(build).total
	health = max_health
	team = p_team
	dir = 1.0 if team == 0 else -1.0
	color = p_color
	battle = p_battle
	var cdata: Dictionary = Parts.rated_data(Parts.CHASSIS[build.chassis], build, "chassis")
	_origin_px = cdata.origin
	# Lift the chassis so the lowest wheel rests on the ground at spawn.y.
	var lowest := 0.0
	for i in cdata.wheels.size():
		if wheel_id(i) == "": continue
		var w = cdata.wheels[i]
		var wd: Dictionary = Parts.WHEELS[wheel_id(i)]
		lowest = maxf(lowest, _px(w[0]).y + w[1] * Parts.SCALE * wd.size)
	if cdata.has("catalogue_sprite"):
		for point in cdata.polygon: lowest=maxf(lowest,point.y)
	var origin := spawn - Vector2(0, lowest + 2.0)

	var mass: float = cdata.mass
	var weighted: Vector2 = cdata.com * Parts.SCALE * mass
	for socket in Parts.equipment_slots(build):
		var wid: String = build.get(socket.id, "")
		var item := Parts.base_for(wid)
		if not item.is_empty() and not item.has("arm") and not item.get("separate",false):
			mass += item.mass
			weighted += _px(socket.point) * item.mass

	chassis = _make_body(origin, 0.0, mass, cdata.get("friction",0.5))
	chassis.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	chassis.center_of_mass = _m(weighted / mass)
	chassis_part = _new_part("chassis", build.chassis, cdata, cdata.name, chassis)
	# Driver first so the body sprite hides everything below the cockpit rim.
	var seat: Dictionary = Parts.SEATS[driver_id()]
	driver_actor = DriverActor.new()
	driver_actor.setup(driver_id(), seat.chin, Parts.SCALE * cdata.face / seat.face, dir)
	driver_actor.position = _m(_px(cdata.chin))
	if cdata.has("catalogue_sprite"):
		# Foreground head over the painted cockpit; crop the torso at its rim.
		driver_actor.z_index=1
		var shader := Shader.new()
		shader.code="shader_type canvas_item; uniform float rim; void fragment(){ if(UV.y>rim) discard; }"
		var material := ShaderMaterial.new()
		material.shader=shader
		material.set_shader_parameter("rim",(seat.chin.y+12)/driver_actor.sprite.texture.get_height())
		driver_actor.sprite.material=material
	chassis.add_child(driver_actor)
	chassis_part.nodes.append(driver_actor)
	var body_art: String = "body_" + build.chassis
	if cdata.get("procedural",false):
		_build_hull(cdata)
	else:
		_add_sprite_part(chassis_part, chassis, body_art, cdata.origin, Parts.SCALE, 0.0, Vector2.ZERO)

	for i in cdata.wheels.size():
		if wheel_id(i) == "": continue
		var wdata: Dictionary = Parts.rated_data(Parts.WHEELS[wheel_id(i)], build, "rear_wheel" if i == 0 else "front_wheel")
		var hub: Vector2 = cdata.wheels[i][0]
		var r: float = cdata.wheels[i][1] * Parts.SCALE * wdata.size
		var wb := _make_body(origin + _m(_px(hub)), 0.0, wdata.mass, wdata.friction)
		wb.z_index = 2
		var wheel := _new_part("wheel", wheel_id(i), wdata, wdata.name + " wheel", wb)
		wheel.slot = "rear_wheel" if i == 0 else "front_wheel"
		wheel.state = {"radius": r}
		_add_shape_circle(wheel, wb, Vector2.ZERO, r)
		var spr := Sprite2D.new()
		spr.texture = Sprites.tex("wheel_%s_%d" % [cdata.get("art_id",build.chassis), i])
		if cdata.get("procedural",false): spr.scale = Vector2.ONE
		spr.scale = Vector2(dir, 1.0) * Parts.SCALE * wdata.size
		if cdata.get("procedural",false): spr.scale *= cdata.wheels[i][1] / Parts.CHASSIS.wedge.wheels[i][1]
		wb.add_child(spr)
		wheel.nodes.append(spr)
		wheel.visuals.append(spr)
		if wdata.has("material"):
			var tint: Color = Color(0.65, 0.37, 0.15) if wdata.material == "wood" else (Color(0.75, 0.85, 1.0) if wdata.material == "metal" else Color(0.3, 0.32, 0.36))
			spr.modulate = tint
			var trim := DrawNode.new(func(ci):
				ci.draw_arc(Vector2.ZERO, r * 0.78, 0, TAU, 32, tint, 4.0)
				for spoke in 6:
					var v := Vector2.from_angle(spoke * TAU / 6.0)
					ci.draw_line(v * r * 0.2, v * r * 0.73, tint, 3.0))
			wb.add_child(trim)
			wheel.nodes.append(trim)
		wheel.joint = _suspension(chassis, wb, wb.position, wheel) if cdata.get("procedural",false) else _pin(chassis, wb, wb.position)
		wheels.append(wheel)

	for socket in Parts.equipment_slots(build):
		var slot: String = socket.id
		var wid: String = build.get(slot, "")
		if wid == "":
			continue
		var mount := _px(socket.point)
		if socket.type in ["gadget","utility"]:
			_build_gadget(wid, Parts.rated_data(Parts.GADGETS[wid],build,slot),slot,mount)
			continue
		if socket.type == "defence":
			_build_gadget(wid, Parts.rated_data(Parts.GADGETS[wid], build, slot), slot, mount)
			continue
		var data: Dictionary = Parts.rated_data(Parts.WEAPONS[wid], build, slot)
		if data.has("procedural"):
			_build_modular_weapon(wid, data, slot, origin, mount)
		elif data.has("arm"):
			_build_swinger(wid, data, slot, origin, mount)
		else:
			_build_fixed_weapon(wid, data, slot, mount)
	for part in parts:
		var level: int=int(build.get("component_stats",{}).get(part.slot,{}).get("level",1))
		for visual in part.visuals: visual.self_modulate=Progression.tier_color(level)


func _build_hull(data: Dictionary) -> void:
	if data.has("catalogue_sprite"):
		var sprite := _sprite(chassis,data.catalogue_sprite,data.sprite_anchor,data.sprite_scale,0,Vector2.ZERO)
		chassis_part.nodes.append(sprite)
		chassis_part.visuals.append(sprite)
		var outline: PackedVector2Array=data.polygon.duplicate()
		for i in outline.size(): outline[i]=_m(outline[i])
		if dir<0: outline.reverse()
		_add_shape_poly(chassis_part,chassis,outline)
		return
	var pts: PackedVector2Array = data.polygon.duplicate()
	for i in pts.size(): pts[i] = _m(pts[i])
	if dir<0: pts.reverse()
	if build.chassis=="boulder": _add_shape_circle(chassis_part,chassis,_m(Vector2(0,-55)),76)
	else: _add_shape_poly(chassis_part,chassis,pts)
	var art := DrawNode.new(func(ci):
		Art.shaded(ci,pts,color.darkened(.15),3.5,.25)
		for y in [-110.0,-75.0,-40.0]:
			for x in [-65.0,-25.0,25.0,65.0]:
				var point := _m(Vector2(x,y))
				if Geometry2D.is_point_in_polygon(point,pts):
					ci.draw_circle(point,2.5,Art.INK)
					ci.draw_circle(point+Vector2(-.5,-.5),1,color.lightened(.4))
		for x in [-45.0,45.0]:
			ci.draw_circle(_m(Vector2(x,-22)),5,Art.INK)
			ci.draw_circle(_m(Vector2(x,-22)),2,Art.STEEL)
		ci.draw_line(_m(Vector2(-40,-45)),_m(Vector2(40,-45)),color.lightened(.3),3))
	chassis.add_child(art)
	chassis_part.nodes.append(art)
	chassis_part.visuals.append(art)

func _build_gadget(id: String, data: Dictionary, slot: String, mount: Vector2) -> void:
	if id in Parts.DEFENCES:
		_build_defence(id,data,slot,mount)
		return
	if id=="harpoon":
		_build_modular_weapon(id,data,slot,chassis.position,mount)
		parts.back().kind = "gadget"
		# Fire while there is still a gap to reel closed, rather than waiting
		# half a four-second cooldown until the bumpers have already met.
		parts.back().state.timer = .15
		return
	if id in Catalogue.gadgets() or id=="booster":
		_build_catalogue_gadget(id,data,slot,mount)
		return
	var p := _new_part("gadget",id,data,data.name,chassis)
	p.slot = slot
	var center := _m(mount)
	p.state = {"timer":0.15,"used":false,"nozzle":center}
	var pts := PackedVector2Array([Vector2(-16,-15),Vector2(16,-15),Vector2(16,15),Vector2(-16,15)])
	if id=="forklift": pts = PackedVector2Array([Vector2(-10,-8),Vector2(65,-8),Vector2(75,0),Vector2(-10,4)])
	for i in pts.size(): pts[i] = center+_m(pts[i])
	if dir<0: pts.reverse()
	_add_shape_poly(p,chassis,pts)
	var visual := DrawNode.new(func(ci):
		Art.shaded(ci,pts,Color(.8,.22,.2) if id=="first_aid" else Color(.9,.65,.2),2,.25)
		if id=="first_aid":
			ci.draw_line(center+Vector2(-9,0),center+Vector2(9,0),Color.WHITE,5)
			ci.draw_line(center+Vector2(0,-9),center+Vector2(0,9),Color.WHITE,5)
		else: ci.draw_circle(center,6,Art.STEEL))
	chassis.add_child(visual)
	p.nodes.append(visual)
	p.visuals.append(visual)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = HURT_LAYERS[1-team]
	area.monitorable = false
	var shape := CollisionPolygon2D.new()
	shape.polygon = pts
	area.add_child(shape)
	chassis.add_child(area)
	p.nodes.append(area)
	p.state.area = area

func _build_rotor(id: String,data: Dictionary,slot: String,mount: Vector2) -> void:
	var rotor := _make_body(chassis.position+_m(mount),0,data.mass,.3)
	var p := _new_part("weapon",id,data,data.name,rotor)
	p.joint = _pin(chassis,rotor,rotor.position)
	p.slot = slot
	var pts := PackedVector2Array([Vector2(-62,-6),Vector2(53,-9),Vector2(65,0),Vector2(53,9),Vector2(-62,6)])
	var visual := DrawNode.new(func(ci):
		Art.shaded(ci,pts,METAL,2,.35)
		ci.draw_circle(Vector2.ZERO,9,color))
	rotor.add_child(visual)
	p.visuals.append(visual)
	_add_shape_poly(p,rotor,pts)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = HURT_LAYERS[1-team]
	area.monitorable = false
	var shape := CollisionPolygon2D.new()
	shape.polygon = pts
	area.add_child(shape)
	rotor.add_child(area)
	p.nodes.append(rotor)
	hitboxes.append({"area":area,"part":p,"body":rotor})
	p.state.rotor = rotor

func _build_fixed_weapon(wid: String, data: Dictionary, slot: String, mount: Vector2) -> void:
	var angle := deg_to_rad(data.angles.get(slot,0.0))
	var part := _new_part("weapon", wid, data, data.name, chassis)
	part.slot = slot
	var s: float = Parts.SCALE * data.get("art_scale", 1.0)
	_add_sprite_part(part, chassis, data.sprite, data.anchor, s, angle, mount)
	if data.has("disc"):
		var center: Vector2 = mount + (data.disc_at * s).rotated(angle)
		_add_shape_circle(part, chassis, _m(center), data.disc_radius * s)
		var spinner := Sprite2D.new()
		spinner.texture = Sprites.tex(data.disc)
		spinner.position = _m(center)
		spinner.scale = Vector2(dir, 1.0) * s
		chassis.add_child(spinner)
		part.nodes.append(spinner)
		part.visuals.append(spinner)
		_spinners.append(spinner)
	_add_weapon_hitbox(part, chassis, data.disc if data.has("disc") else data.sprite, Sprites.tex(data.disc).get_size() * 0.5 if data.has("disc") else data.anchor, s, angle, mount + (data.disc_at * s).rotated(angle) if data.has("disc") else mount)


func _build_swinger(wid: String, data: Dictionary, slot: String, origin: Vector2, mount: Vector2) -> void:
	var arc: Array = data.arc[slot]
	var rest := deg_to_rad(arc[0]) * dir
	var pivot := origin + _m(mount)
	var body := _make_body(pivot, rest, data.mass, 0.4)
	body.z_index = 1
	var part := _new_part("weapon", wid, data, data.name, body)
	part.slot = slot
	var s: float = Parts.SCALE * data.get("art_scale", 1.0)
	_add_sprite_part(part, body, data.sprite, data.anchor, s, deg_to_rad(data.sprite_angle), Vector2.ZERO)
	_add_weapon_hitbox(part, body, data.sprite, data.anchor, s, deg_to_rad(data.sprite_angle), Vector2.ZERO)
	part.joint = _pin(chassis, body, pivot)
	part.state = {"phase": "rest", "timer": data.rest_time, "since": 0.0,
			"rest": rest, "strike": deg_to_rad(arc[1]) * dir}


## Stops all physics (used for the garage preview).
func freeze_all() -> void:
	for b in _bodies():
		b.freeze = true


# --- Simulation -------------------------------------------------------------

## Called by the battle each physics tick (movement, weapons, gadgets).
func step(delta: float) -> void:
	control_immunity=maxf(0,control_immunity-delta)
	if not alive or restrained:
		return
	_elapsed += delta
	pose_gadgets(delta)
	for p in parts:
		if p.state.has("rotor"): p.state.rotor.angular_velocity = chassis.angular_velocity+9.0*dir
	_drive(delta)
	_run_swingers(delta)
	_run_gadget(delta)
	_run_launchers(delta)
	if chassis.global_transform.y.y < -0.3:
		flipped_time += delta


func _process(delta: float) -> void:
	if not alive:
		return
	driver_actor.set_fear(fear_level())
	if restrained: return
	for s in _spinners:
		if is_instance_valid(s):
			s.rotation += 24.0 * delta * dir
	_boost_flash = maxf(_boost_flash - delta * 3.0, 0.0)
	for f in _flames:
		if is_instance_valid(f):
			var boost := 1.0 + _boost_flash * 1.6
			f.scale = Vector2(randf_range(0.7, 1.05) * boost, randf_range(0.85, 1.1) * (1.0 + _boost_flash * 0.4))


## Wheel motors: always drive toward the enemy. If the enemy ends up behind us (it went over
## the top, or we got flipped past it), reverse to push it back toward the wall.
func _drive(delta: float) -> void:
	var toward := dir
	var approach := 1.0
	if enemy and enemy.alive:
		var dx := enemy.chassis.global_position.x - chassis.global_position.x
		# Keep the wheels turning when cars meet. A near-zero target speed
		# made contact fights feel stalled even with high motor torque.
		approach = lerpf(0.72, 1.0, clampf((absf(dx) - 220.0) / 300.0, 0.0, 1.0))
		if absf(dx) > 8.0:
			toward = signf(dx)
		# Backpedal keeps a useful ranged gap; the wheel motor must not cancel it.
		for gadget in parts:
			if gadget.id=="backpedal" and gadget.alive:
				var wall: float=battle._wall_x if battle is Battle else Battle.WALL_X
				var rear_clearance := wall+chassis.position.x*dir
				var speed_away := maxf(0,-chassis.linear_velocity.x*dir)
				var stopping_room := 220+speed_away*speed_away/600
				if rear_clearance>stopping_room and (absf(dx)<400 or gadget.state.get("thrust_left",0.0)>0):
					toward=-dir
					approach=.8
	var reverse := toward != dir
	if reverse:
		reversing_time += delta
	for w in wheels:
		if not w.alive:
			continue
		var r: float = w.state.radius
		var target: float = toward * w.data.speed * 1.25 * approach * (REVERSE_FACTOR if reverse else 1.0) / r
		var inertia: float = 0.5 * w.body.mass * r * r
		var torque := clampf((target - w.body.angular_velocity) * inertia / delta, -w.data.torque, w.data.torque)
		w.body.apply_torque(torque)


func _run_swingers(delta: float) -> void:
	for p in parts:
		if p.kind != "weapon" or not p.alive or not p.data.has("arm"):
			continue
		var s: Dictionary = p.state
		var rel := angle_difference(chassis.rotation, p.body.rotation)
		var target: float = s.rest
		var speed: float = p.data.return_speed
		match s.phase:
			"rest":
				s.timer -= delta
				if s.timer <= 0.0 and enemy and enemy.alive \
						and enemy.chassis.global_position.distance_to(chassis.global_position) < p.data.trigger_range:
					s.phase = "strike"
					s.since = _elapsed
			"strike":
				target = s.strike
				speed = p.data.strike_speed
				if absf(angle_difference(rel, target)) < 0.12 or _elapsed - s.since > 0.7:
					s.phase = "return"
			"return":
				if absf(angle_difference(rel, s.rest)) < 0.1:
					s.phase = "rest"
					s.timer = p.data.rest_time
		var err := angle_difference(rel, target)
		p.body.angular_velocity = chassis.angular_velocity + clampf(err * 18.0, -speed, speed)


func _run_gadget(delta: float) -> void:
	for p in parts:
		if p.kind != "gadget" or not p.alive:
			continue
		if p.id=="harpoon": continue
		p.state.timer -= delta
		if p.id=="backpedal" and p.state.get("thrust_left",0.0)>0:
			p.state.thrust_left=maxf(0,p.state.thrust_left-delta)
			var backward := Vector2(-dir,0).rotated(chassis.rotation)
			var wall: float=battle._wall_x if battle is Battle else Battle.WALL_X
			var speed_away := maxf(0,-chassis.linear_velocity.x*dir)
			if wall+chassis.position.x*dir>220+speed_away*speed_away/600:
				chassis.apply_force(backward*chassis.mass*100,p.state.nozzle.rotated(chassis.rotation))
			else: p.state.thrust_left=0.0
		if p.id=="first_aid":
			if not p.state.used and health<max_health*0.5:
				p.state.used = true
				health = minf(max_health,health+max_health*0.25)
				battle.heal_effect(chassis.position)
			continue
		if p.id in ["booster","backpedal"] and not p.state.used and p.state.timer<=0:
			p.state.used = true
			if p.id=="backpedal": p.state.thrust_left=.9
			var fwd := Vector2(dir * (-1.0 if p.id=="backpedal" else 1.0), 0).rotated(chassis.rotation)
			chassis.apply_impulse(fwd * (chassis.mass*100 if p.id=="backpedal" else 1800.0), p.state.nozzle.rotated(chassis.rotation))
			_boost_flash = 1.0
			battle.fx_boost(chassis.to_global(p.state.nozzle), -fwd)
		if not p.id in ["forklift","repulse","lifter"] or p.state.timer>0: continue
		var contact = gadget_contact(p)
		if contact==null: continue
		p.state.timer = 3.0
		match p.id:
			"forklift":
				var victim: Car=p.state.contact_car
				var countered := false
				for counter in victim.parts:
					if counter.id!="repulse" or counter.state.timer>0: continue
					var touching = victim.gadget_contact(counter)
					if touching!=null and counter.state.contact_car==self:
						counter.state.timer = 4.0
						victim.activate_repulse(counter,self)
						countered = true
						break
				p.state.timer = 6.0
				if countered:
					p.state.phase = "return"
					continue
				battle.emit_sound("forklift")
				p.state.phase="lift"
				p.state.phase_time=0.0
				# Heavier targets resist the lifter; it is not a mass-independent launch.
				var ratio := clampf(chassis.mass/victim.chassis.mass,.35,1.15)
				for body in victim._bodies(): body.apply_central_impulse(Vector2(0,-90*ratio*body.mass))
				var tip: Vector2=p.body.to_global(p.state.contact_at)
				victim.chassis.apply_impulse(Vector2(0,-victim.chassis.mass*25*ratio),tip-victim.chassis.global_position)
				victim.chassis.apply_torque_impulse(dir*victim.chassis.mass*450*ratio)
			"repulse":
				p.state.timer = 4.0
				activate_repulse(p,p.state.contact_car)
			"lifter": battle.attach_balloon(p.state.contact_car,contact.body)

func activate_repulse(p: Part, victim: Car) -> void:
	var away := Vector2(dir,0).rotated(chassis.rotation)
	for body in victim._bodies(): body.apply_central_impulse((away*350+Vector2(0,-45))*body.mass)
	for body in _bodies(): body.apply_central_impulse(-away*55*body.mass)
	battle.repulse_effect(chassis.to_global(p.state.nozzle))

func gadget_contact(p: Part):
	for area in p.state.area.get_overlapping_areas():
		if area.has_meta("part") and area.get_meta("car").alive:
			p.state.contact_car=area.get_meta("car")
			return area.get_meta("part")
	# Solid faces are separated by the physics solver before Area2D overlap.
	# Query the same visible polygons with a two-unit contact tolerance.
	if not p.state.has("contact_queries"):
		p.state.contact_queries=[]
		for shape in p.state.area.get_children():
			if not shape is CollisionPolygon2D: continue
			for polygon in Geometry2D.decompose_polygon_in_convex(shape.polygon):
				var convex := ConvexPolygonShape2D.new()
				convex.points=polygon
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape=convex
				query.margin=2.0
				query.collision_mask=HURT_LAYERS[1-team]
				query.collide_with_areas=true
				query.collide_with_bodies=false
				p.state.contact_queries.append({"shape":shape,"query":query})
	for probe in p.state.contact_queries:
		probe.query.transform=probe.shape.global_transform
		for hit in chassis.get_world_2d().direct_space_state.intersect_shape(probe.query,16):
			if hit.collider.has_meta("part") and hit.collider.get_meta("car").alive:
				p.state.contact_car=hit.collider.get_meta("car")
				return hit.collider.get_meta("part")
	return null

func pose_gadgets(delta: float) -> void:
	for part in parts:
		if part.id!="forklift" or not part.alive or not part.state.has("phase"): continue
		part.state.phase_time+=delta
		if part.state.phase=="lift" and part.state.phase_time>.55:
			part.state.phase="return"
		var target: float=-dir*deg_to_rad(50) if part.state.phase=="lift" else 0.0
		var error := angle_difference(part.body.rotation-chassis.rotation,target)
		part.body.angular_velocity=chassis.angular_velocity+clampf(error*14,-6,6)
		if part.state.phase=="return" and absf(error)<.05: part.state.phase="ready"


## Returns this tick's hits as [target_car, part, amount, pos, weapon, heavy]. The battle applies
## both cars' hits together so neither side gets to strike first.
func collect_hits(delta: float) -> Array:
	if not alive or restrained:
		return []
	var hits := []
	var processed := {}
	for hb in hitboxes:
		var wp: Part = hb.part
		if not wp.alive or processed.has(wp):
			continue
		processed[wp] = true
		if wp.data.has("arm") and wp.state.phase != "strike":
			continue
		var contacts := {}
		var area: Area2D = hb.area
		for other in area.get_overlapping_areas():
			if not other.has_meta("part"):
				continue
			var target: Part = other.get_meta("part")
			var tcar: Car = other.get_meta("car")
			if not target.alive or not tcar.alive:
				continue
			# One weapon's contact does not multiply its rating across overlapping parts.
			if not contacts.has(tcar) or _contact_priority(target) < _contact_priority(contacts[tcar].part):
				contacts[tcar] = {"part": target, "area": other}
		for tcar in contacts:
			var target: Part = contacts[tcar].part
			var other: Area2D = contacts[tcar].area
			var pos := area.global_position.lerp(other.global_position, 0.25)
			if wp.data.kind == "continuous":
				var spool := 1.0
				if wp.id == "chainsaw":
					if wp.state.get("last_contact",-1.0) < _elapsed-delta*1.5: wp.state.spool = 0.0
					wp.state.spool = minf(2.0,wp.state.get("spool",0.0)+delta)
					wp.state.last_contact = _elapsed
					spool = lerpf(0.25,1.0,wp.state.spool/2.0)
				hits.append([tcar, target, wp.attack_rating * delta * spool, pos, wp, false])
				continue
			var rel_v := _vel_at(hb.body, pos) - _vel_at(target.body, pos)
			var key: int = tcar.get_instance_id()
			var ready: bool = _elapsed - wp.hit_times.get(key, -10.0) >= wp.data.cooldown
			if ready and rel_v.length() >= wp.data.min_speed:
				wp.hit_times[key] = _elapsed
				hits.append([tcar, target, wp.attack_rating, pos, wp, true])
				target.body.apply_impulse(rel_v.normalized() * wp.data.knock, pos - target.body.global_position)
	return hits


func _contact_priority(part: Part) -> int:
	return {"defence": 0, "wheel": 1, "weapon": 2, "gadget": 3, "chassis": 4}.get(part.kind, 5)


func apply_damage(part: Part, amount: float, pos: Vector2, weapon: Part, heavy: bool) -> void:
	if not part.alive or not alive:
		return
	amount = clampf(amount, 0.0, health)
	if amount <= 0.0:
		return
	health -= amount
	part.hp = maxf(0.0, part.hp - amount)
	part.damage_taken += amount
	weapon.damage_dealt += amount
	last_hit_by = weapon.label
	last_hit_rating = weapon.attack_rating
	battle.on_damage(self, part, amount, pos, heavy)
	_flash(part)
	if health <= 0.0:
		_die(pos)

func _die(pos: Vector2) -> void:
	if not alive:
		return
	alive = false
	driver_actor.hide()
	for p in parts:
		if is_instance_valid(p.joint):
			p.joint.queue_free()
		for n in p.nodes:
			if is_instance_valid(n) and (n is Area2D or n is Joint2D):
				n.queue_free()
		for v in p.visuals:
			if is_instance_valid(v):
				v.self_modulate = Color(0.35, 0.33, 0.35)
	for f in _flames:
		if is_instance_valid(f):
			f.hide()
	for b in _bodies():
		var away: Vector2 = (b.global_position - pos).normalized()
		b.apply_central_impulse((away * 450.0 + Vector2(0, -420)) * b.mass)
		b.apply_torque_impulse(randf_range(-1.0, 1.0) * 4000.0 * b.mass)
	battle.on_car_died(self, pos)


func _flash(part: Part) -> void:
	if _elapsed - part.last_flash < 0.08:
		return
	part.last_flash = _elapsed
	for v in part.visuals:
		if is_instance_valid(v):
			v.modulate = Color(2.2, 2.2, 2.2)
			create_tween().tween_property(v, "modulate", Color.WHITE, 0.15)


# --- Queries for the battle / summary ----------------------------------------

func hp_ratio() -> float:
	return maxf(health, 0.0) / max_health


func fear_level() -> int:
	if hp_ratio() <= 0.15:
		return 2
	if hp_ratio() <= 0.35:
		return 1
	return 0


func driver_world_position() -> Vector2:
	return driver_actor.global_position


func total_dealt() -> float:
	var total := 0.0
	for p in parts:
		total += p.damage_dealt
	return total


func weapon_parts() -> Array:
	return parts.filter(func(p): return p.kind == "weapon")


func lost_parts() -> Array:
	return parts.filter(func(p): return not p.alive and p.kind != "chassis")


func driver_id() -> String:
	return build.get("driver", Parts.CHASSIS[build.chassis].driver)


func wheel_id(i: int) -> String:
	return build.get("rear_wheel" if i == 0 else "front_wheel", build.get("wheels", "grip"))


func _catalogue_area(part: Part, body: Node2D, art: Dictionary, mount: Vector2, active_only: bool) -> Area2D:
	var area := Area2D.new()
	area.collision_layer=0
	area.collision_mask=HURT_LAYERS[1-team]
	area.monitorable=false
	for outline in Sprites.outlines(art.sprite):
		var pieces: Array=[outline]
		if active_only and art.active_from>0:
			var x: float=art.size.x*art.active_from
			pieces=Geometry2D.intersect_polygons(outline,PackedVector2Array([Vector2(x,-1),Vector2(art.size.x+1,-1),Vector2(art.size.x+1,art.size.y+1),Vector2(x,art.size.y+1)]))
		for piece in pieces:
			var points := PackedVector2Array()
			for point in piece: points.append(_m(mount+(point-art.anchor)*art.scale))
			if dir<0: points.reverse()
			var shape := CollisionPolygon2D.new()
			shape.polygon=points
			area.add_child(shape)
	body.add_child(area)
	part.nodes.append(area)
	return area

func _build_catalogue_weapon(id: String, data: Dictionary, slot: String, mount: Vector2) -> void:
	var art := CatalogueArt.equipment(id)
	if id=="blade":
		_build_catalogue_blade(data,slot,mount,art)
		return
	var part := _new_part("weapon",id,data,data.name,chassis)
	part.slot=slot
	_add_sprite_part(part,chassis,art.sprite,art.anchor,art.scale,0,mount)
	if data.kind=="continuous":
		var area := _catalogue_area(part,chassis,art,mount,true)
		hitboxes.append({"area":area,"part":part,"body":chassis})
	else:
		part.state={"timer":data.get("first_delay",data.cooldown*.5),"muzzle":_m(mount+Vector2((art.size.x-art.anchor.x)*art.scale+2,0))}
		if id=="double_rocket": part.state.rear_muzzle=_m(mount+Vector2(-art.anchor.x*art.scale-2,0))

func _build_catalogue_blade(data: Dictionary, slot: String, mount: Vector2, art: Dictionary) -> void:
	var center: Vector2=mount+(Vector2(238,130)-art.anchor)*art.scale
	var radius: float=art.size.y*art.scale*.5
	var rotor := _make_body(chassis.position+_m(center),0,data.mass,.3)
	var part := _new_part("weapon","blade",data,data.name,rotor)
	part.slot=slot
	part.joint=_pin(chassis,rotor,rotor.position)
	# The mounting arm is fixed; only the separate cutting disc rotates.
	var arm := _sprite(chassis,art.sprite,art.anchor,art.scale,0,mount)
	var shader := Shader.new()
	shader.code="shader_type canvas_item; uniform vec2 extent; void fragment(){ vec2 p=UV*extent; bool arm=p.x<238.0 && abs(p.y-130.0)<17.0; if(length(p-vec2(238.0,130.0))<133.0 && !arm) discard; }"
	var material := ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("extent",art.size)
	arm.material=material
	arm.z_index=2
	part.nodes.append(arm)
	part.visuals.append(arm)
	# Passive mounting hardware can take damage but cannot inflict it.
	for outline in Sprites.outlines(art.sprite):
		var socket_rect := PackedVector2Array([Vector2(-1,-1),Vector2(105,-1),Vector2(105,art.size.y+1),Vector2(-1,art.size.y+1)])
		for piece in Geometry2D.intersect_polygons(outline,socket_rect):
			var points := PackedVector2Array()
			for point in piece: points.append(_m(mount+(point-art.anchor)*art.scale))
			if dir<0: points.reverse()
			_add_shape_poly(part,chassis,points)
	var disc := "catalogue_blade_disc"
	var texture := Sprites.tex(disc)
	var disc_scale := radius*2/texture.get_width()
	_add_sprite_part(part,rotor,disc,texture.get_size()*.5,disc_scale,0,Vector2.ZERO)
	_add_weapon_hitbox(part,rotor,disc,texture.get_size()*.5,disc_scale,0,Vector2.ZERO)
	part.state.rotor=rotor
	rotor.z_index=1

func _build_catalogue_gadget(id: String, data: Dictionary, slot: String, mount: Vector2) -> void:
	var body := chassis
	if id=="forklift": body=_make_body(chassis.position+_m(mount),chassis.rotation,data.mass,.3)
	var part := _new_part("gadget",id,data,data.name,body)
	part.slot=slot
	var art := CatalogueArt.equipment(id)
	var offset := Vector2.ZERO if id=="forklift" else mount
	_add_sprite_part(part,body,art.sprite,art.anchor,art.scale,0,offset)
	# Side-mounted gadgets sit over wheel hubs, rather than disappearing
	# behind tyres while their invisible collision shapes remain active.
	for visual in part.visuals: visual.z_index = 3
	if id=="forklift": art.active_from=.62
	var area := _catalogue_area(part,body,art,offset,id=="forklift")
	var nozzle := mount+Vector2((-art.anchor.x if id=="booster" else art.size.x-art.anchor.x)*art.scale,0)
	part.state={"timer":.15,"used":false,"nozzle":_m(nozzle),"area":area}
	if id=="forklift":
		part.joint=_pin(chassis,body,body.position)
		part.state.merge({"phase":"ready","phase_time":0.0,"contact_at":_m((Vector2(art.size.x*.9,art.size.y*.95)-art.anchor)*art.scale)})

func _build_modular_weapon(wid: String, data: Dictionary, slot: String, origin: Vector2, mount: Vector2) -> void:
	if wid in Catalogue.weapons() or wid=="harpoon":
		_build_catalogue_weapon(wid,data,slot,mount)
		return
	if data.procedural == "rotor":
		_build_rotor(wid,data,slot,mount)
		return
	var sword: bool = data.procedural == "sword"
	var body: RigidBody2D = chassis
	var offset := _m(mount)
	var part := _new_part("weapon", wid, data, data.name, body)
	part.slot = slot
	var pts: PackedVector2Array
	if sword:
		pts = PackedVector2Array([Vector2(14, -7), Vector2(data.length - 12, -5), Vector2(data.length, 0), Vector2(data.length - 12, 5), Vector2(14, 7)])
	else:
		pts = PackedVector2Array([Vector2(-12, -12), Vector2(45, -12), Vector2(45, 8), Vector2(-12, 14)])
	for i in pts.size():
		pts[i] = _m(pts[i]) + offset
	if dir < 0:
		pts.reverse()
	_add_shape_poly(part, body, pts)
	var paint: Color = {"blaster":Color(.3,.8,1),"hook":Color(.9,.65,.15),"harpoon":Color(.9,.65,.15),"rocket":Color(.85,.4,.2),"double_rocket":Color(.85,.4,.2),"laser":Color(.9,.2,.3),"minigun":Color(.3,.35,.4),"drill":Color(.5,.65,.75),"chainsaw":Color(.9,.65,.18)}.get(wid,METAL)
	var visual := DrawNode.new(func(ci): Art.shaded(ci, pts, paint, 2.0, 0.3))
	body.add_child(visual)
	part.nodes.append(visual)
	part.visuals.append(visual)
	if not sword:
		var detail := DrawNode.new(func(ci):
			ci.draw_line(offset + _m(Vector2(8, -8)), offset + _m(Vector2(40, -8)), paint.lightened(0.3), 3.0)
			ci.draw_line(offset + _m(Vector2(40, -12)), offset + _m(Vector2(40, 8)), Art.INK, 4.0)
			ci.draw_circle(offset + _m(Vector2(0, 0)), 5.0, Art.INK)
			if wid == "hook":
				ci.draw_arc(offset + _m(Vector2(50, 0)), 8, -PI * 0.5, PI * 0.5, 10, METAL, 3.0)
			if wid=="minigun":
				for y in [-6,0,6]: ci.draw_line(offset+_m(Vector2(12,y)),offset+_m(Vector2(43,y)),METAL.lightened(.25),2)
			if wid in ["rocket","double_rocket"]:
				ci.draw_line(offset+_m(Vector2(0,-3)),offset+_m(Vector2(35,-3)),Color(1,.9,.6),4)
			if wid=="laser": ci.draw_circle(offset+_m(Vector2(40,-2)),5,Color(1,.8,.8)))
		body.add_child(detail)
		part.nodes.append(detail)
	if sword:
		if wid in ["drill","chainsaw"]:
			var detail := DrawNode.new(func(ci):
				for x in range(20,int(data.length)-12,9):
					ci.draw_line(offset+_m(Vector2(x,-4)),offset+_m(Vector2(x+5,4)),Art.INK,2))
			body.add_child(detail)
			part.nodes.append(detail)
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = HURT_LAYERS[1 - team]
		area.monitorable = false
		var poly := CollisionPolygon2D.new()
		poly.polygon = pts
		area.add_child(poly)
		body.add_child(area)
		part.nodes.append(area)
		hitboxes.append({"area": area, "part": part, "body": body})
	else:
		part.state = {"timer": data.get("first_delay",data.cooldown*.5), "muzzle": offset + _m(Vector2(48, -2))}


func _run_launchers(delta: float) -> void:
	if not alive or restrained:
		return
	for p in parts:
		if not p.alive or p.data.get("kind","") != "ranged":
			continue
		if p.state.get("hooked",false): continue
		p.state.timer -= delta
		if p.id=="laser" and p.state.timer>0 and p.state.timer<=.3 and not p.state.get("charging",false):
			p.state.charging = true
			battle.emit_sound("laser_charge")
		if p.state.timer > 0 or not enemy or not enemy.alive:
			continue
		p.state.timer = maxf(0.1,p.data.cooldown/(1.0+_elapsed*0.1)) if p.id=="minigun" else p.data.cooldown
		p.state.charging = false
		var forward := Vector2(dir, 0).rotated(chassis.rotation)
		var muzzle: Vector2 = chassis.to_global(p.state.muzzle)
		if p.id=="laser": battle.fire_laser(self,p,muzzle,forward)
		else: battle.launch_projectile(self, p, muzzle, forward * p.data.projectile_speed + chassis.linear_velocity)
		if p.id=="double_rocket": battle.launch_projectile(self,p,chassis.to_global(p.state.get("rear_muzzle",p.state.muzzle-_m(Vector2(65,0)))),-forward*p.data.projectile_speed+chassis.linear_velocity)
		chassis.apply_impulse(-forward * p.data.recoil, muzzle - chassis.global_position)


func _build_defence(id: String, data: Dictionary, slot: String, mount: Vector2) -> void:
	if id in ["armour_plate","shield"]:
		var part := _new_part("defence",id,data,data.name,chassis)
		part.slot=slot
		var art := CatalogueArt.equipment(id)
		if id=="shield": art.scale*=1.8
		_add_sprite_part(part,chassis,art.sprite,art.anchor,art.scale,0,mount)
		for visual in part.visuals: visual.z_index = 3
		return
	var part := _new_part("defence", id, data, data.name, chassis)
	part.slot = slot
	var height: float = data.half_height
	var pts := PackedVector2Array([Vector2(-4, -height), Vector2(12, -height + 8), Vector2(12, height - 8), Vector2(-4, height)])
	for i in pts.size():
		pts[i] = _m(mount + pts[i])
	if dir < 0:
		pts.reverse()
	_add_shape_poly(part, chassis, pts)
	var visual := DrawNode.new(func(ci):
		Art.shaded(ci, pts, Color(0.2, 0.55, 0.75) if id == "shield" else METAL, 2.0, 0.3)
		for y in [-height * 0.5, height * 0.5]:
			ci.draw_circle(_m(mount + Vector2(3, y)), 2.5, Art.INK))
	chassis.add_child(visual)
	part.nodes.append(visual)
	part.visuals.append(visual)


func show_mount_markers() -> void:
	for socket in Parts.equipment_slots(build):
		var marker := Node2D.new()
		marker.position = _m(_px(socket.point))
		marker.z_index = 8
		var shade := Color(1.0, 0.65, 0.15) if socket.type == "attack" else Color(0.25, 0.8, 1.0)
		marker.add_child(DrawNode.new(func(ci):
			var polygon := Art.circle(Vector2.ZERO,9.0,6) if socket.type=="attack" else PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)])
			ci.draw_colored_polygon(polygon, Art.INK)
			ci.draw_polyline(polygon,shade,2.5)))
		var label := UI.label(socket.label.split(" ")[0], 12, shade, 3)
		label.position = Vector2(-10, -24)
		marker.add_child(label)
		chassis.add_child(marker)


func _bodies() -> Array:
	var out := []
	for p in parts:
		if is_instance_valid(p.body) and not out.has(p.body):
			out.append(p.body)
	return out


# --- Construction helpers -----------------------------------------------------

## Chassis sprite pixel -> body-local position (Blue space, not yet mirrored).
func _px(p: Vector2) -> Vector2:
	return (p - _origin_px) * Parts.SCALE


func _new_part(kind: String, id: String, data: Dictionary, label: String, body: RigidBody2D) -> Part:
	var p := Part.new()
	p.kind = kind
	p.id = id
	p.data = data
	p.label = label
	p.hp = data.durability
	p.max_hp = data.durability
	p.attack_rating = data.get("attack", 0.0)
	p.body = body
	if kind=="weapon" and body!=chassis:
		body.collision_layer=WEAPON_LAYERS[team]
		body.collision_mask=LAYER_WORLD
	parts.append(p)
	return p


func _make_body(pos: Vector2, rot: float, mass: float, friction: float) -> RigidBody2D:
	var b := RigidBody2D.new()
	b.position = pos
	b.rotation = rot
	b.mass = mass
	b.collision_layer = BODY_LAYERS[team]
	b.collision_mask = LAYER_WORLD | BODY_LAYERS[1 - team]
	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = 0.05
	b.physics_material_override = mat
	b.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	b.can_sleep = false
	add_child(b)
	return b


func _suspension(a: PhysicsBody2D, b: PhysicsBody2D, pos: Vector2, part: Part) -> Joint2D:
	var groove := GrooveJoint2D.new()
	groove.position = pos-Vector2(0,6)
	groove.length = 12
	groove.initial_offset = 6
	add_child(groove)
	groove.node_a = groove.get_path_to(a)
	groove.node_b = groove.get_path_to(b)
	part.nodes.append(groove)
	var spring := DampedSpringJoint2D.new()
	spring.position = pos-Vector2(0,6)
	spring.length = 6
	spring.rest_length = 6
	spring.stiffness = 1600
	spring.damping = 80
	add_child(spring)
	spring.node_a = spring.get_path_to(a)
	spring.node_b = spring.get_path_to(b)
	return spring

func _pin(a: PhysicsBody2D, b: PhysicsBody2D, pos: Vector2) -> PinJoint2D:
	var j := PinJoint2D.new()
	j.position = pos
	j.softness = 0.0
	add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	return j


## A sprite placed so its `anchor` pixel lands on `offset` (Blue space) rotated by `rot`, mirrored for Red.
func _sprite(parent: Node2D, art: String, anchor: Vector2, s: float, rot: float, offset: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = Sprites.tex(art)
	spr.centered = false
	spr.offset = -anchor
	spr.position = _m(offset)
	spr.rotation = rot * dir
	spr.scale = Vector2(s * dir, s)
	parent.add_child(spr)
	return spr


## Sprite plus collision + hurtbox shapes traced from the sprite's outline.
func _add_sprite_part(part: Part, body: Node2D, art: String, anchor: Vector2, s: float, rot: float, offset: Vector2) -> void:
	var spr := _sprite(body, art, anchor, s, rot, offset)
	part.nodes.append(spr)
	part.visuals.append(spr)
	for outline in Sprites.outlines(art):
		var pts := PackedVector2Array()
		for p in outline:
			pts.append(_m(offset + ((p - anchor) * s).rotated(rot)))
		if dir < 0.0:
			pts.reverse()
		_add_shape_poly(part, body, pts)


## Collision polygon plus a matching hurtbox.
func _add_shape_poly(part: Part, body: Node2D, pts: PackedVector2Array) -> void:
	# Fixed weapons use exact contact sensors, so opposing weapons can pass each other.
	if part.kind!="weapon" or body!=chassis:
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		body.add_child(cp)
		part.nodes.append(cp)
	var hurt := _make_hurtbox(part, body)
	var acp := CollisionPolygon2D.new()
	acp.polygon = pts
	hurt.add_child(acp)


## Collision circle plus a matching hurtbox.
func _add_shape_circle(part: Part, body: Node2D, center: Vector2, r: float) -> void:
	for target in [body, _make_hurtbox(part, body)]:
		if target==body and part.kind=="weapon" and body==chassis: continue
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = r
		cs.shape = circle
		cs.position = center
		target.add_child(cs)
		if target == body:
			part.nodes.append(cs)


func _make_hurtbox(part: Part, body: Node2D) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = HURT_LAYERS[team]
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = true
	a.set_meta("part", part)
	a.set_meta("car", self)
	body.add_child(a)
	part.nodes.append(a)
	return a


## Mirror a Blue-space point into this car's facing.
func _m(v: Vector2) -> Vector2:
	return Vector2(v.x * dir, v.y)


static func _vel_at(b: RigidBody2D, p: Vector2) -> Vector2:
	var r := p - b.global_position
	return b.linear_velocity + Vector2(-b.angular_velocity * r.y, b.angular_velocity * r.x)

## Damage follows the visible weapon outline, without oversized reach circles.
func _add_weapon_hitbox(part: Part, body: Node2D, art: String, anchor: Vector2, s: float, rot: float, offset: Vector2) -> void:
	var a := Area2D.new()
	a.collision_mask = HURT_LAYERS[1 - team]
	a.collision_layer = 0
	a.monitorable = false
	var outlines: Array = Sprites.outlines(art)
	# Only the metal head/blade can deal damage; mounting hardware is passive.
	if art == "weapon_hammer":
		outlines = [PackedVector2Array([Vector2(61, 52), Vector2(127, 14), Vector2(142, 22), Vector2(195, 136), Vector2(133, 170), Vector2(116, 166)])]
	elif art == "weapon_lance":
		outlines = [PackedVector2Array([Vector2(79, 42), Vector2(232, 68), Vector2(80, 88)])]
	for outline in outlines:
		var pts := PackedVector2Array()
		for p in outline:
			pts.append(_m(offset + ((p - anchor) * s).rotated(rot)))
		if dir < 0:
			pts.reverse()
		var shape := CollisionPolygon2D.new()
		shape.polygon = pts
		a.add_child(shape)
	body.add_child(a)
	part.nodes.append(a)
	hitboxes.append({"area": a, "part": part, "body": body})
