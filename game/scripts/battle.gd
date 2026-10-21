class_name Battle
extends Node2D
## One automatic fight between two cars: arena, crusher walls, camera, effects, HUD and summary.

signal finished(result: Dictionary)
signal rematch_requested
signal garage_requested

const TIME_LIMIT := 45.0
const SPAWN_X := 330.0
## Inner faces of the crusher walls start here and close in to WALL_MIN after WALL_START seconds.
const WALL_X := 1450.0
const WALL_MIN := 40.0
const WALL_START := 20.0
const WALL_SPEED := 115.0
const WALL_WIDTH := 300.0
## Background art placement: image pixel row the cars drive on, and scale.
const BG_SIZE := Vector2(1672, 941)
const BG_FLOOR_PX := 598.0
const BG_SCALE := 1.28
const CAM_Y := -165.0
const TEAM_COLORS := [Color(0.24, 0.55, 0.97), Color(0.96, 0.32, 0.28)]
const SIDE_NAMES := ["Left", "Right"]
const VIGNETTE := "shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.42, 0.9, length(uv * vec2(1.0, 1.25)));
	COLOR = vec4(0.12, 0.05, 0.0, v * 0.45);
}"

var cars: Array = []
var running := false
var time_left := TIME_LIMIT
var show_end_panel := true
var trace := false
var remote_view := false
var sound_events: Array = []
var sound_sequence := 0
var sound_times := {}

func emit_sound(key: String) -> void:
	var now := Time.get_ticks_msec()
	var gap := 60 if key=="minigun" else (180 if key in ["impact","blade","drill","chainsaw"] else 80)
	if now-int(sound_times.get(key,-10000))<gap: return
	sound_times[key] = now
	sound_sequence += 1
	sound_events.append([sound_sequence,key])
	if sound_events.size()>32: sound_events.pop_front()
	if not remote_view: DatsAudio.instance().effect(key)

var _camera: Camera2D
var _fx: Node2D
var _shake := 0.0
var _punch := 0.0
var _base_zoom := 0.62
var _focus = null
var _ending := false
var _bg_rect := Rect2()
var _walls: Array = []
var _wall_x := WALL_X
var _walls_warned := false
var _crusher: Car.Part
var _crush_fx_t := 0.0
var _shadows: Array = []
var _smokes: Array = []
var _markers: Array = []
var _hud: CanvasLayer
var _bars: Array = []
var _chips: Array = []
var _health_labels: Array = []
var _timer_label: Label
var _banner: Label
var _flash_rect: ColorRect
var _pending_numbers := {}
var _trace_t := 0.0
var damage_events: Array = []
var _projectiles: Array = []
var _cables: Array = []
var escapes: Array = []
var _escape_layer: Node2D
var _balloons: Array = []
var _nets: Array = []
var collision_debug: CollisionDebug


func start(builds: Array) -> void:
	DatsAudio.instance().play_music("music_battle")
	for blueprint in builds:
		if not Parts.energy_report(blueprint).valid:
			push_error("Battle rejected: chassis energy capacity exceeded.")
			return
	_build_arena()
	for i in 2:
		var shadow := Polygon2D.new()
		shadow.polygon = Art.circle(Vector2.ZERO, 1.0, 28, Vector2(110, 9))
		shadow.color = Color(0.15, 0.07, 0.0, 0.35)
		add_child(shadow)
		_shadows.append(shadow)
	for i in 2:
		var car := Car.new()
		add_child(car)
		car.setup(builds[i], i, Vector2(-SPAWN_X if i == 0 else SPAWN_X, 0.0), TEAM_COLORS[i], self)
		cars.append(car)
		_smokes.append(_damage_smoke(car))
	collision_debug=CollisionDebug.new()
	collision_debug.cars=cars
	collision_debug.z_index=25
	collision_debug.visible=false
	add_child(collision_debug)
	cars[0].enemy = cars[1]
	cars[1].enemy = cars[0]
	_build_walls()
	_fx = Node2D.new()
	_fx.z_index = 10
	add_child(_fx)
	_escape_layer = Node2D.new()
	_escape_layer.z_index = 30
	add_child(_escape_layer)
	for i in 2:
		_markers.append(_marker(i))
	_camera = Camera2D.new()
	_camera.position = Vector2(0, CAM_Y)
	add_child(_camera)
	_camera.make_current()
	_build_hud()
	_banner_text("READY", 0.8)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_banner_text("FIGHT!", 0.7, Color(1, 0.85, 0.3))
	running = not remote_view


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
		collision_debug.visible=not collision_debug.visible

var player_names: Array = []

func driver_name(i: int) -> String:
	if i < player_names.size() and not str(player_names[i]).is_empty():
		return str(player_names[i])
	var n: String = Parts.DRIVERS[cars[i].driver_id()]
	if cars[0].driver_id() == cars[1].driver_id():
		n += " (%s)" % SIDE_NAMES[i]
	return n


func _physics_process(delta: float) -> void:
	if remote_view: return
	if not running:
		return
	var hits := []
	_run_projectiles(delta)
	_run_nets(delta)
	_run_cables(delta)
	_run_balloons(delta)
	for c in cars:
		if c.alive:
			c.step(delta)
	for c in cars:
		if c.alive:
			hits.append_array(c.collect_hits(delta))
	for h in hits:
		h[0].apply_damage(h[1], h[2], h[3], h[4], h[5])
	_run_walls(delta)
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		var diff: float = cars[0].hp_ratio() - cars[1].hp_ratio()
		_finish(-1 if absf(diff) < 0.01 else (0 if diff > 0.0 else 1), "time")
	if trace:
		_trace_t += delta
		if _trace_t >= 2.0:
			_trace_t = 0.0
			var line := "  t=%.0f wall=%d" % [TIME_LIMIT - time_left, _wall_x]
			for c in cars:
				line += "  %s pos=(%d,%d) rot=%d hp=%d" % [SIDE_NAMES[c.team], c.chassis.global_position.x,
						c.chassis.global_position.y, rad_to_deg(c.chassis.rotation), c.health]
			print(line)


func _process(delta: float) -> void:
	if not DatsAudio.instance().screen_shake: _shake = 0; _punch = 0
	if cars.size() < 2:
		return
	var target := Vector2(0, CAM_Y)
	var zoom := 0.62
	if cars.size()==2 and _focus == null:
		var first: Vector2 = cars[0].chassis.global_position
		var second: Vector2 = cars[1].chassis.global_position
		target = (first+second)*0.5 + Vector2(0,-100)
		var span := (first-second).abs()+Vector2(650,560)
		zoom = clampf(minf(get_viewport_rect().size.x/span.x,get_viewport_rect().size.y/span.y),0.5,1.05)
	if _focus != null:
		target = _focus
		if not escapes.is_empty():
			target = escapes[0].position + Vector2(0, -75)
		zoom = 0.95
	_base_zoom = lerpf(_base_zoom, zoom, 1.0 - exp(-delta * 3.0))
	_punch = maxf(_punch - delta * 0.5, 0.0)
	var z := _base_zoom * (1.0 + _punch * 0.3)
	_camera.zoom = Vector2(z, z)
	# Keep the view inside the background art.
	var half := get_viewport_rect().size * 0.5 / z
	var lo := _bg_rect.position + half
	var hi := _bg_rect.end - half
	target = Vector2(clampf(target.x, lo.x, maxf(lo.x, hi.x)), clampf(target.y, lo.y, maxf(lo.y, hi.y)))
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-delta * 6.0))
	_shake = maxf(_shake - delta * 2.2, 0.0)
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 22.0

	for i in 2:
		var car: Car = cars[i]
		var cpos := car.chassis.global_position
		var s: Polygon2D = _shadows[i]
		var height := clampf(-cpos.y - 40.0, 0.0, 500.0)
		s.position = Vector2(cpos.x, 4)
		s.scale = Vector2.ONE * (1.0 - height / 600.0)
		s.modulate.a = 1.0 - height / 500.0
		_markers[i].position = cpos + Vector2(0, -150)
		var hp := car.hp_ratio()
		_smokes[i][0].emitting = car.alive and hp < 0.55
		_smokes[i][1].emitting = car.alive and hp < 0.25
		_bars[i].value = hp * 100.0
		_health_labels[i].text = "%d / %d HEALTH" % [ceili(car.health), car.max_health]
		_chips[i].value = move_toward(_chips[i].value, _bars[i].value, delta * 35.0)
	_timer_label.text = str(ceili(time_left))

	# Continuous damage is shown as one number every ~0.4 s instead of one per frame.
	for part in _pending_numbers.keys():
		var p: Dictionary = _pending_numbers[part]
		p.t += delta
		if p.t >= 0.4:
			if p.amount >= 1.0:
				_damage_number(p.pos, p.amount, false)
			_pending_numbers.erase(part)


# --- Crusher walls --------------------------------------------------------------

func _run_walls(delta: float) -> void:
	var elapsed := TIME_LIMIT - time_left
	if not _walls_warned and elapsed >= WALL_START - 3.0:
		_walls_warned = true
		_banner_text("WALLS CLOSING IN!", 1.6, Color(1, 0.45, 0.25))
	if elapsed >= WALL_START:
		_wall_x = maxf(WALL_MIN, _wall_x - WALL_SPEED * delta)
	_crush_fx_t -= delta
	for w in _walls:
		w.body.position.x = w.side * _wall_x
		# Overlap lists are refreshed on the next physics frame. Query the spike
		# shapes at their new position so a visible touch and damage agree now.
		for spike in w.spikes:
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = spike
			query.transform = Transform2D(0.0, w.body.global_position)
			query.collision_mask = Car.HURT_LAYERS[0] | Car.HURT_LAYERS[1]
			query.collide_with_areas = true
			query.collide_with_bodies = false
			for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
				var other: Object = hit.collider
				if not other.has_meta("part"):
					continue
				var part: Car.Part = other.get_meta("part")
				var car: Car = other.get_meta("car")
				if not part.alive or not car.alive:
					continue
				var pos: Vector2 = w.body.to_global(spike.points[1])
				car.apply_damage(car.chassis_part, car.health, pos, _crusher, false)
				if _crush_fx_t <= 0.0:
					_sparks(pos, 6)
					_shake = minf(_shake + 0.12, 0.6)
	if _crush_fx_t <= 0.0:
		_crush_fx_t = 0.06


func _build_walls() -> void:
	_crusher = Car.Part.new()
	_crusher.label = "Crusher walls"
	for side in [-1.0, 1.0]:
		var spikes: Array[ConvexPolygonShape2D] = []
		var body := AnimatableBody2D.new()
		# Walls move inside our physics step; apply that transform immediately
		# so drawing, solid spikes and lethal queries use the same position.
		body.sync_to_physics = false
		body.collision_layer = Car.LAYER_WORLD
		body.collision_mask = 0
		body.position = Vector2(side * WALL_X, 0)
		add_child(body)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(WALL_WIDTH, 1400)
		cs.shape = rect
		cs.position = Vector2(side * WALL_WIDTH * 0.5, -700)
		body.add_child(cs)
		# Lethal and solid shapes match the drawn spikes, including their gaps.
		var sy := -24.0
		while sy > -620.0:
			var points := PackedVector2Array([Vector2(0, sy - 13), Vector2(-side * 28, sy), Vector2(0, sy + 13)])
			var query_shape := ConvexPolygonShape2D.new()
			query_shape.points = points
			spikes.append(query_shape)
			var solid := CollisionPolygon2D.new()
			solid.polygon = points
			body.add_child(solid)
			sy -= 40.0
		var s: float = side
		var lamps := []
		body.add_child(DrawNode.new(func(ci): _paint_wall(ci, s)))
		for ly in [-330.0, -170.0]:
			var lamp := Sprite2D.new()
			lamp.texture = Art.soft_dot()
			lamp.material = Art.additive()
			lamp.position = Vector2(side * 60, ly)
			lamp.scale = Vector2(1.6, 1.6)
			lamp.modulate = Color(1, 0.2, 0.1, 0.0)
			body.add_child(lamp)
			lamps.append(lamp)
		_walls.append({"body": body, "side": side, "lamps": lamps, "spikes": spikes})
	# Blink the warning lamps once the walls start moving.
	var t := create_tween().set_loops()
	t.tween_interval(0.35)
	t.tween_callback(func():
		var on := TIME_LIMIT - time_left >= WALL_START - 3.0 and running
		for w in _walls:
			for lamp in w.lamps:
				lamp.modulate.a = (0.0 if lamp.modulate.a > 0.3 else 0.9) if on else 0.0)


func _paint_wall(ci: CanvasItem, side: float) -> void:
	var x0 := 0.0
	var x1 := side * WALL_WIDTH
	var slab := PackedVector2Array([Vector2(x0, -1400), Vector2(x1, -1400), Vector2(x1, 0), Vector2(x0, 0)])
	if side < 0:
		slab.reverse()
	Art.shaded(ci, slab, Color(0.24, 0.52, 0.52), 5.0, 0.12, 34.0)
	# Rust streaks and a yellow edge strip.
	var strip := PackedVector2Array([Vector2(x0, -1400), Vector2(side * 26, -1400), Vector2(side * 26, 0), Vector2(x0, 0)])
	Art.shaded(ci, strip, Color(0.95, 0.72, 0.15), 3.0, 0.2)
	var band := PackedVector2Array([Vector2(side * 30, -110), Vector2(x1, -110), Vector2(x1, -60), Vector2(side * 30, -60)])
	Art.hazard_stripes(ci, band, 14.0)
	for ly in [-330.0, -170.0]:
		ci.draw_circle(Vector2(side * 60, ly), 13, Art.INK)
		ci.draw_circle(Vector2(side * 60, ly), 9, Color(0.55, 0.12, 0.08))
	# Spikes along the inner face.
	var y := -24.0
	while y > -620.0:
		var spike := PackedVector2Array([Vector2(0, y - 13), Vector2(-side * 28, y), Vector2(0, y + 13)])
		Art.shaded(ci, spike, Art.STEEL, 2.5, 0.35)
		y -= 40.0


# --- Events from cars -----------------------------------------------------------

func on_damage(car: Car, part, amount: float, pos: Vector2, heavy: bool) -> void:
	var source: String = car.last_hit_by.to_lower()
	emit_sound(("explosion" if source.contains("rocket") or source.contains("cannon") else "impact") if heavy else ("chainsaw" if source.contains("chainsaw") else ("drill" if source.contains("drill") else "blade")))
	damage_events.append({"time": TIME_LIMIT - time_left, "team": car.team, "part": part.label, "source": car.last_hit_by, "attack_rating": car.last_hit_rating, "amount": amount, "health_remaining": car.health, "part_durability_remaining": part.hp, "position": pos})
	if damage_events.size() > 512:
		damage_events.pop_front()
	if heavy:
		_sparks(pos, clampi(int(amount * 0.9), 10, 40))
		_impact_flash(pos, clampf(amount / 30.0, 0.8, 2.2))
		_damage_number(pos, amount, true)
		_shake = minf(_shake + clampf(amount / 70.0, 0.2, 0.6), 1.0)
		_punch = minf(_punch + 0.1, 0.2)
		# Keep simulation at real time; particles and camera give impact feedback.
	else:
		if randf() < 0.45:
			_sparks(pos, 4)
		_shake = minf(_shake + 0.01, 0.35)
		var p: Dictionary = _pending_numbers.get(part, {"amount": 0.0, "t": 0.0, "pos": pos})
		p.amount += amount
		p.pos = pos
		_pending_numbers[part] = p


func on_car_died(car: Car, pos: Vector2) -> void:
	emit_sound("explosion")
	for net in _nets.duplicate():
		if net.car==car: _release_net(net)
	# Fight simulation pauses for the escape animation; release cables immediately.
	for cable in _cables.duplicate():
		if cable.owner==car or cable.car==car:
			cable.weapon.state.hooked=false
			cable.line.queue_free()
			_cables.erase(cable)
	for projectile in _projectiles.duplicate():
		if projectile.owner==car:
			projectile.visual.queue_free()
			if is_instance_valid(projectile.rope): projectile.rope.queue_free()
			_projectiles.erase(projectile)
	if car.driver_ejected:
		return
	car.driver_ejected = true
	var escape := ParachuteEscape.new()
	escape.setup(car)
	_escape_layer.add_child(escape)
	escapes.append(escape)
	_explosion(pos)
	_debris(pos, _paint(car), 16)
	_screen_flash(0.45)
	_shake = 1.0
	_punch = 0.3
	if _ending:
		return
	_ending = true
	_focus = pos + Vector2(0, -40)
	running = false
	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	_focus = null
	running = true
	_finish(-1 if not cars[0].alive and not cars[1].alive else 1 - car.team, "destroyed")


func fx_boost(pos: Vector2, back: Vector2) -> void:
	emit_sound("boost")
	var p := _particles(pos, 24, 0.35, Color(1.0, 0.55, 0.15), Art.soft_dot(), true)
	p.direction = back
	p.spread = 14.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 300.0
	p.initial_velocity_max = 600.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var smoke := _particles(pos, 10, 0.9, Color(0.5, 0.48, 0.5, 0.5), Art.soft_dot(), false)
	smoke.direction = back
	smoke.spread = 30.0
	smoke.gravity = Vector2(0, -60)
	smoke.initial_velocity_min = 80.0
	smoke.initial_velocity_max = 200.0
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 0.8
	_shake = minf(_shake + 0.15, 1.0)


func launch_projectile(car: Car, weapon: Car.Part, pos: Vector2, velocity: Vector2) -> void:
	emit_sound({"double_rocket":"rocket","hook":"harpoon","balloon_launcher":"balloon_launch","net_launcher":"net","flipper_net":"net"}.get(weapon.id,weapon.id if weapon.id in ["rocket","minigun","cannon","blaster","harpoon"] else "cannon"))
	var visual := DrawNode.new(func(ci):
		if weapon.id=="balloon_launcher":
			ci.draw_colored_polygon(Art.circle(Vector2.ZERO,1,20,Vector2(12,16)),Color(1,.65,.2))
			ci.draw_line(Vector2(-15,0),Vector2(-28,0),Color(.8,.7,.5),2)
		if weapon.id in ["net_launcher","flipper_net"]:
			ci.draw_circle(Vector2.ZERO,18,Color(.2,.5,.65,.25))
			for i in range(-12,13,6):
				ci.draw_line(Vector2(i,-14),Vector2(i,14),Color(.6,.9,1),2)
				ci.draw_line(Vector2(-14,i),Vector2(14,i),Color(.6,.9,1),2)
		ci.draw_circle(Vector2.ZERO, 5.0 if weapon.id == "cannon" else 3.0, Color(0.3, 0.85, 1.0) if weapon.id == "blaster" else Art.STEEL)
		if weapon.id in ["rocket","double_rocket"]:
			Art.shaded(ci,PackedVector2Array([Vector2(-12,-5),Vector2(5,-5),Vector2(12,0),Vector2(5,5),Vector2(-12,5)]),Color(.9,.45,.2),1,.25)
			ci.draw_line(Vector2(-12,0),Vector2(-22,0),Color(1,.85,.3),4)
		if weapon.id in ["hook","harpoon"]:
			Art.shaded(ci,PackedVector2Array([Vector2(-16,-3),Vector2(5,-3),Vector2(4,-8),Vector2(20,0),Vector2(4,8),Vector2(5,3),Vector2(-16,3)]),Art.STEEL,1,.3))
	visual.position = pos
	visual.rotation = velocity.angle()
	_fx.add_child(visual)
	var rope: Line2D=null
	if weapon.id in ["hook","harpoon"]:
		rope=Line2D.new()
		rope.width=2.5
		rope.default_color=Color(.8,.73,.55)
		_fx.add_child(rope)
	_projectiles.append({"owner": car, "weapon": weapon, "pos": pos, "velocity": velocity, "life": 2.0, "visual": visual,"rope":rope})


## Swept impact query prevents fast bolts passing through a part between ticks.
func _run_projectiles(delta: float) -> void:
	for p in _projectiles.duplicate():
		p.life -= delta
		if is_instance_valid(p.rope):
			var from: Vector2=p.owner.chassis.to_global(p.weapon.state.muzzle)
			p.rope.points=PackedVector2Array([from,p.pos])
			if from.distance_to(p.pos)>700: p.life=0
		var end: Vector2 = p.pos + p.velocity * delta
		var ray := PhysicsRayQueryParameters2D.create(p.pos, end, Car.LAYER_WORLD | Car.HURT_LAYERS[1 - p.owner.team])
		ray.collide_with_areas = true
		ray.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			if hit.collider.has_meta("part"):
				var target: Car.Part = hit.collider.get_meta("part")
				var car: Car = hit.collider.get_meta("car")
				if car.alive and target.alive and p.owner.alive and p.weapon.alive:
					if p.weapon.id in ["hook","harpoon"]:
						_attach_cable(p.owner, p.weapon, car, target, hit.position)
					elif p.weapon.id=="balloon_launcher": attach_balloon(car,target.body,hit.position,true)
					elif p.weapon.id in ["net_launcher","flipper_net"]: attach_net(car,p.weapon.id=="flipper_net")
					else:
						var damage: float = p.weapon.attack_rating * (0.1 if p.weapon.id == "minigun" else 1.0)
						car.apply_damage(target, damage, hit.position, p.weapon, true)
						target.body.apply_impulse(p.velocity.normalized() * p.weapon.data.knock, hit.position - target.body.global_position)
			_sparks(hit.position, 6)
		if not hit.is_empty() or p.life <= 0 or not p.owner.alive or not p.weapon.alive:
			p.visual.queue_free()
			if is_instance_valid(p.rope): p.rope.queue_free()
			_projectiles.erase(p)
		else:
			p.pos = end
			p.visual.position = end
			if is_instance_valid(p.rope): p.rope.points=PackedVector2Array([p.owner.chassis.to_global(p.weapon.state.muzzle),end])


func fire_laser(owner: Car, weapon: Car.Part, from: Vector2, direction: Vector2) -> void:
	emit_sound("laser")
	var end := from+direction*2200.0
	var ray := PhysicsRayQueryParameters2D.create(from,end,Car.LAYER_WORLD|Car.HURT_LAYERS[1-owner.team])
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		end = hit.position
		if hit.collider.has_meta("part"):
			var car: Car = hit.collider.get_meta("car")
			car.apply_damage(hit.collider.get_meta("part"),weapon.attack_rating,end,weapon,true)
	var beam := Line2D.new()
	beam.points = PackedVector2Array([from,end])
	beam.width = 7
	beam.default_color = Color(1,.3,.2)
	_fx.add_child(beam)
	fade_out(beam,0.1)

func heal_effect(pos: Vector2) -> void:
	emit_sound("heal")
	var label := UI.label("+ FIRST AID",20,Color(.3,1,.4))
	label.position = pos+Vector2(-60,-100)
	_fx.add_child(label)
	fade_out(label,0.5)

func repulse_effect(pos: Vector2) -> void:
	emit_sound("repulse")
	var ring := DrawNode.new(func(ci): ci.draw_arc(Vector2.ZERO,55,0,TAU,32,Color(.4,.9,1),5))
	ring.position = pos
	_fx.add_child(ring)
	fade_out(ring,.2)

func attach_balloon(car: Car, contact_body: RigidBody2D, impact := Vector2.ZERO, point_lift := false) -> void:
	if not car or not car.alive: return
	if car.restrained: return
	for balloon in _balloons:
		if balloon.car==car: return
	emit_sound("balloon_inflate")
	var visual := DrawNode.new(func(ci):
		var neck := Vector2(0,-120)
		var centre := Vector2(0,-162)
		ci.draw_line(Vector2.ZERO,neck,Color(.18,.14,.10),4)
		ci.draw_line(Vector2.ZERO,neck,Color(.9,.8,.6),2)
		var envelope := Art.circle(centre,1,32,Vector2(32,42))
		ci.draw_colored_polygon(envelope,Color(1,.63,.16))
		ci.draw_colored_polygon(Art.circle(centre,1,32,Vector2(15,42)),Color(1,.87,.57))
		ci.draw_polyline(envelope+PackedVector2Array([envelope[0]]),Color(.2,.16,.12),2)
		ci.draw_line(centre+Vector2(-23,28),neck,Color(.35,.25,.15),2)
		ci.draw_line(centre+Vector2(23,28),neck,Color(.35,.25,.15),2)
		ci.draw_rect(Rect2(neck-Vector2(5,0),Vector2(10,7)),Art.STEEL)
		ci.draw_circle(centre+Vector2(-10,-20),4,Color(1,.95,.76)))
	visual.position=impact if point_lift else contact_body.global_position
	_fx.add_child(visual)
	# Launch all linked bodies together so suspension and heavy wheels cannot pin
	# the hull to the ground. Subsequent buoyancy holds it above its launch height.
	if point_lift:
		car.chassis.apply_impulse(Vector2(0,-car.chassis.mass*160),impact-car.chassis.global_position)
	else:
		for body in car._bodies(): body.apply_central_impulse(Vector2(0,-260*body.mass))
	_balloons.append({"car":car,"body":car.chassis if point_lift else contact_body,"anchor":car.chassis.to_local(impact) if point_lift else Vector2.ZERO,"point_lift":point_lift,"height":impact.y-180 if point_lift else car.chassis.global_position.y-180,"time":5.0 if point_lift else 3.5,"visual":visual})

func _run_balloons(delta: float) -> void:
	for b in _balloons.duplicate():
		b.time -= delta
		if b.time<=0 or not b.car.alive or b.car.restrained:
			emit_sound("balloon_pop")
			b.visual.queue_free()
			_balloons.erase(b)
			continue
		var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity"))
		if b.point_lift:
			var anchor: Vector2=b.body.to_global(b.anchor)
			var total_mass := 0.0
			for body in b.car._bodies(): total_mass+=body.mass
			var lift := clampf((b.height-anchor.y)*8-Car._vel_at(b.body,anchor).y*5,-600,600)
			b.body.apply_force(Vector2(0,-total_mass*(gravity-lift)),anchor-b.body.global_position)
			b.visual.position=anchor
			continue
		var lift := clampf((b.height-b.car.chassis.global_position.y)*8.0-b.car.chassis.linear_velocity.y*5.0,-600,600)
		for body in b.car._bodies():
			body.apply_central_force(Vector2(0,body.mass*(lift-gravity*body.gravity_scale)))
		b.visual.position = b.body.global_position

func _attach_cable(owner: Car, weapon: Car.Part, car: Car, target: Car.Part, pos: Vector2) -> void:
	if weapon.state.get("hooked",false): return
	emit_sound("cable")
	weapon.state.hooked=true
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.8, 0.75, 0.55)
	_fx.add_child(line)
	var from: Vector2 = owner.chassis.to_global(weapon.state.muzzle)
	_cables.append({"owner": owner, "weapon": weapon, "car": car, "target": target, "anchor": target.body.to_local(pos), "length": from.distance_to(pos), "life": 3.0, "line": line})

func attach_net(car: Car, flip: bool) -> void:
	emit_sound("net")
	if not car.alive or car.restrained or car.control_immunity>0: return
	car.restrained=true
	var nodes := []
	var bodies := car._bodies()
	for body in bodies:
		nodes.append({"node":body,"position":body.global_position,"rotation":body.global_rotation,"frozen":body.freeze})
		body.linear_velocity=Vector2.ZERO
		body.angular_velocity=0
		body.freeze=true
	for child in car.get_children():
		if child is Joint2D: nodes.append({"node":child,"position":child.global_position,"rotation":child.global_rotation})
	var visual := DrawNode.new(func(ci):
		var tint := Color(1,.67,.25,.8) if flip else Color(.5,.9,1,.8)
		for x in range(-140,141,20):
			var reach := 100*sqrt(maxf(0,1-pow(x/145.0,2)))
			ci.draw_line(Vector2(x,-35-reach),Vector2(x,-35+reach),Color(.15,.12,.1,.8),4)
			ci.draw_line(Vector2(x,-35-reach),Vector2(x,-35+reach),tint,2)
		for y in range(-90,91,20):
			var reach := 145*sqrt(maxf(0,1-pow(y/100.0,2)))
			ci.draw_line(Vector2(-reach,y-35),Vector2(reach,y-35),tint,2)
		var rim := Art.circle(Vector2(0,-35),1,40,Vector2(145,100))
		ci.draw_polyline(rim+PackedVector2Array([rim[0]]),tint,4)
		for point in [Vector2(-140,-35),Vector2(140,-35),Vector2(0,65)]:
			ci.draw_circle(point,7,Art.STEEL)
			ci.draw_circle(point,3,Art.INK))
	visual.position=car.chassis.global_position
	visual.rotation=car.chassis.global_rotation
	_fx.add_child(visual)
	var label := UI.label("NET · 5.0s",18,Color(1,.9,.65))
	label.position=car.chassis.global_position+Vector2(-45,-150)
	_fx.add_child(label)
	_nets.append({"car":car,"time":0.0,"flip":flip,"nodes":nodes,"origin":car.chassis.global_position,"rotation":car.chassis.rotation,"visual":visual,"label":label})

func _net_pose(net: Dictionary, angle: float, lift: float) -> void:
	for pose in net.nodes:
		pose.node.global_position=net.origin+(pose.position-net.origin).rotated(angle)
		pose.node.global_rotation=pose.rotation+angle
	# Place the complete flipped silhouette above the floor, including its wheels.
	var bottom := -INF
	for body in net.car._bodies():
		for shape in body.get_children():
			if shape is CollisionPolygon2D:
				for point in shape.polygon: bottom=maxf(bottom,shape.to_global(point).y)
			elif shape is CollisionShape2D and shape.shape is CircleShape2D:
				bottom=maxf(bottom,shape.global_position.y+shape.shape.radius)
	if is_finite(bottom):
		for pose in net.nodes: pose.node.global_position.y+=-2-bottom-lift

func _release_net(net: Dictionary) -> void:
	for pose in net.nodes:
		if pose.node is RigidBody2D:
			pose.node.freeze=pose.frozen
			pose.node.linear_velocity=Vector2.ZERO
			pose.node.angular_velocity=0
	net.car.restrained=false
	net.car.control_immunity=1.0
	net.visual.queue_free()
	net.label.queue_free()
	_nets.erase(net)

func _run_nets(delta: float) -> void:
	for net in _nets.duplicate():
		net.time+=delta
		if not net.car.alive:
			_release_net(net)
			continue
		if net.flip:
			var flipped := angle_difference(net.rotation,PI)
			var upright := angle_difference(net.rotation,0)
			if net.time<5:
				_net_pose(net,flipped*smoothstep(0,.6,net.time),0)
			else:
				var t := clampf((net.time-5)/.8,0,1)
				_net_pose(net,lerpf(flipped,upright,smoothstep(0,1,t)),sin(t*PI)*100)
		if net.time>=5.8 if net.flip else net.time>=5:
			_release_net(net)
			continue
		net.visual.position=net.car.chassis.global_position
		net.visual.rotation=net.car.chassis.global_rotation
		net.label.position=net.car.chassis.global_position+Vector2(-45,-150)
		net.label.text="RECOVERING" if net.time>=5 else "NET · %.1fs" % (5-net.time)


func _run_cables(delta: float) -> void:
	for c in _cables.duplicate():
		c.life -= delta
		var from: Vector2 = c.owner.chassis.to_global(c.weapon.state.muzzle)
		var to: Vector2 = c.target.body.to_global(c.anchor)
		var distance := from.distance_to(to)
		if c.life <= 0 or distance > 700 or not c.owner.alive or not c.car.alive or not c.target.alive or not c.weapon.alive:
			c.weapon.state.hooked=false
			c.line.queue_free()
			_cables.erase(c)
			continue
		c.length = maxf(45.0, c.length - 240.0 * delta)
		var separating: float=(c.car.chassis.linear_velocity-c.owner.chassis.linear_velocity).dot(from.direction_to(to))
		var tension := clampf((distance - c.length) * 550.0+separating*80.0, 0.0, 26000.0) if distance>c.length else 0.0
		var force := from.direction_to(to) * tension
		c.owner.chassis.apply_force(force, from - c.owner.chassis.global_position)
		c.car.chassis.apply_force(-force, to - c.car.chassis.global_position)
		c.line.points = PackedVector2Array([from, to])


func fade_out(node: CanvasItem, delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(node, "modulate:a", 0.0, 0.6)
	t.tween_callback(node.queue_free)


func _paint(car: Car) -> Color:
	return Parts.CHASSIS[car.build.chassis].paint


# --- Ending and summary --------------------------------------------------------

func _finish(winner: int, reason: String) -> void:
	if not running:
		return
	running = false
	var result := _summary(winner, reason)
	if show_end_panel:
		_show_end_panel(result)
	finished.emit(result)


func _summary(w: int, reason: String) -> Dictionary:
	var info := []
	for c in cars:
		var weapons := {}
		for p in c.weapon_parts():
			weapons["%s (%s)" % [p.label, p.slot]] = roundi(p.damage_dealt)
		var lost := []
		for p in c.lost_parts():
			lost.append(p.label)
		info.append({"hp": roundi(maxf(c.health, 0.0)), "max_hp": roundi(c.max_health), "health_sources": Parts.health_breakdown(c.build),
				"dealt": roundi(c.total_dealt()), "weapons": weapons, "lost": lost,
				"flipped": snappedf(c.flipped_time, 0.1), "reversed": snappedf(c.reversing_time, 0.1),
				"killed_by": c.last_hit_by if not c.alive else ""})
	var result := {"winner": w, "reason": reason, "time": snappedf(TIME_LIMIT - time_left, 0.1), "cars": info, "why": [],
			"crushed": _crusher.damage_dealt, "damage_events": damage_events.duplicate(true)}
	if w < 0:
		result.why.append("Draw: neither car depleted the other's total health. Try more reach or a different mount.")
		return result
	var l := 1 - w
	var wn := driver_name(w)
	var ln := driver_name(l)
	var why := []
	if reason == "time":
		why.append("Time ran out. %s kept more total health (%d%% vs %d%%)." % [wn,
				roundi(cars[w].hp_ratio() * 100), roundi(cars[l].hp_ratio() * 100)])
	if not cars[l].alive and cars[l].last_hit_by == _crusher.label:
		why.append("%s touched the spike wall and was destroyed." % ln)
		if cars[w].reversing_time > 1.5:
			why.append("%s got behind and reversed, pushing %s back into the wall." % [wn, ln])
		elif cars[w].chassis.mass > cars[l].chassis.mass * 1.15:
			why.append("%s is heavier and won the pushing contest (%.0f vs %.0f mass)." % [wn,
					cars[w].chassis.mass, cars[l].chassis.mass])
	var best = null
	for p in cars[w].weapon_parts():
		if best == null or p.damage_dealt > best.damage_dealt:
			best = p
	if best != null and best.damage_dealt > 0.0:
		why.append("%s's %s (%s mount) did the most damage: %d." % [wn, best.label, best.slot, roundi(best.damage_dealt)])
	if cars[l].weapon_parts().is_empty():
		why.append("%s had no weapons." % ln)
	elif cars[l].total_dealt() < cars[w].total_dealt() * 0.4:
		why.append("%s's weapons rarely connected (%d dealt vs %d). Try more reach or another mount." % [ln,
				roundi(cars[l].total_dealt()), roundi(cars[w].total_dealt())])
	if cars[l].flipped_time > 2.0:
		why.append("%s spent %.1fs upside down. A lower or heavier chassis resists flips." % [ln, cars[l].flipped_time])
	var lost_wheels: int = cars[l].lost_parts().filter(func(p): return p.kind == "wheel").size()
	if lost_wheels > 0:
		why.append("%s lost %d wheel%s and slowed down." % [ln, lost_wheels, "" if lost_wheels == 1 else "s"])
	result.why = why
	return result


func _show_end_panel(result: Dictionary) -> void:
	var w: int = result.winner
	var accent: Color = TEAM_COLORS[w] if w >= 0 else Color(0.75, 0.75, 0.8)
	_banner_text("DRAW!" if w < 0 else "%s WINS!" % driver_name(w).to_upper(), 0.0, accent.lightened(0.2))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.09, 0.08, 0.14, 0.94), accent, 18, 4, 24))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	if w >= 0:
		head.add_child(UI.portrait(cars[w].driver_id(), TEAM_COLORS[w], 64))
	var title: String
	if w < 0:
		title = "Draw after %.1fs" % result.time
	else:
		title = "%s wins: %s in %.1fs" % [driver_name(w), "enemy destroyed" if result.reason == "destroyed" else "on time", result.time]
	var head_label := UI.label(title, 26)
	head_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(head_label)
	box.add_child(head)
	for line in result.why:
		var l := UI.label("•  " + line, 19, Color(0.88, 0.88, 0.94), 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 640
		box.add_child(l)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)
	var rematch := UI.button("Rematch", Color(0.95, 0.6, 0.15))
	rematch.pressed.connect(rematch_requested.emit)
	buttons.add_child(rematch)
	var garage := UI.button("Garage", Color(0.35, 0.36, 0.5))
	garage.pressed.connect(garage_requested.emit)
	buttons.add_child(garage)
	_hud.add_child(panel)
	var size := panel.get_combined_minimum_size()
	panel.position = (get_viewport_rect().size - size) * 0.5 + Vector2(0, 60)
	panel.pivot_offset = size * 0.5
	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)


# --- Arena --------------------------------------------------------------------------

func _build_arena() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://art/arena.jpg")
	bg.centered = false
	var backdrop_scale := Vector2((WALL_X*2+500)/BG_SIZE.x,BG_SCALE)
	bg.scale = backdrop_scale
	bg.position = Vector2(-BG_SIZE.x * .5*backdrop_scale.x,-BG_FLOOR_PX*BG_SCALE)
	bg.z_index = -40
	add_child(bg)
	_bg_rect = Rect2(bg.position, BG_SIZE * backdrop_scale)

	var ground := StaticBody2D.new()
	ground.collision_layer = Car.LAYER_WORLD
	ground.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	ground.physics_material_override = mat
	add_child(ground)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 400)
	cs.shape = shape
	cs.position = Vector2(0, 200)
	ground.add_child(cs)

	# Warm dust drifting in the sunlight.
	var dust := CPUParticles2D.new()
	dust.texture = Art.soft_dot()
	dust.material = Art.additive()
	dust.position = Vector2(0, -330)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(800, 300)
	dust.amount = 36
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.gravity = Vector2(0, -4)
	dust.spread = 180.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 14.0
	dust.scale_amount_min = 0.05
	dust.scale_amount_max = 0.12
	dust.color = Color(1, 0.9, 0.7, 0.25)
	dust.z_index = 5
	add_child(dust)


## Floating name tag over a car for the first seconds, so players know which side is theirs.
func _marker(i: int) -> Node2D:
	var m := Node2D.new()
	m.z_index = 20
	add_child(m)
	var color: Color = TEAM_COLORS[i]
	m.add_child(DrawNode.new(func(ci):
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(0, 16)]), Art.INK)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, 2), Vector2(9, 2), Vector2(0, 12)]), color)))
	var l := UI.label(driver_name(i).to_upper(), 22, color.lightened(0.3), 8)
	l.position = Vector2(-80, -34)
	l.size = Vector2(160, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(l)
	var t := create_tween()
	t.tween_interval(3.5)
	t.tween_property(m, "modulate:a", 0.0, 0.6)
	return m


# --- HUD ------------------------------------------------------------------------------

func _build_hud() -> void:
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 1
	add_child(vignette_layer)
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	vignette_layer.add_child(vig)

	_hud = CanvasLayer.new()
	_hud.layer = 2
	add_child(_hud)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 0.95, 0.85, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flash_rect)

	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 12
	top.add_theme_constant_override("separation", 14)
	_hud.add_child(top)
	for i in 2:
		var side := HBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", 10)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var cname: String = Parts.CHASSIS[cars[i].build.chassis].name
		var name_label := UI.label("%s  ·  %s" % [driver_name(i).to_upper(), cname], 22)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(name_label)
		var health_label := UI.label("%d / %d HEALTH" % [cars[i].health, cars[i].max_health], 14, Color(0.9, 0.95, 1.0), 2)
		health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(health_label)
		_health_labels.append(health_label)
		var stack := Control.new()
		stack.custom_minimum_size.y = 26
		col.add_child(stack)
		var frame := Panel.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.04, 0.08, 0.85), Art.INK, 8, 3, 0))
		stack.add_child(frame)
		var chip := _hp_bar(i, Color(1, 0.95, 0.85))
		stack.add_child(chip)
		var bar := _hp_bar(i, TEAM_COLORS[i])
		stack.add_child(bar)
		_chips.append(chip)
		_bars.append(bar)
		var portrait := UI.portrait(cars[i].driver_id(), TEAM_COLORS[i], 70)
		if i == 0:
			side.add_child(portrait)
			side.add_child(col)
		else:
			side.add_child(col)
			side.add_child(portrait)
		top.add_child(side)
		if i == 0:
			var tbox := PanelContainer.new()
			tbox.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.06, 0.12, 0.9), Art.INK, 12, 3, 6))
			tbox.custom_minimum_size = Vector2(84, 0)
			tbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_timer_label = UI.label(str(int(TIME_LIMIT)), 36, Color(1, 0.9, 0.6))
			_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tbox.add_child(_timer_label)
			top.add_child(tbox)

	_banner = UI.label("", 76, Color.WHITE, 14)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 120
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.pivot_offset = Vector2(500, 50)
	_hud.add_child(_banner)


func _hp_bar(team: int, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 4
	bar.offset_right = -4
	bar.offset_top = 4
	bar.offset_bottom = -4
	bar.show_percentage = false
	bar.value = 100
	if team == 1:
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	fill.border_color = color.lightened(0.35)
	fill.border_width_top = 4
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _banner_text(text: String, hold: float, color := Color.WHITE) -> void:
	_banner.text = text
	_banner.modulate = color
	_banner.scale = Vector2(1.6, 1.6)
	var t := create_tween()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		t.tween_interval(hold)
		t.tween_property(_banner, "modulate:a", 0.0, 0.25)


# --- Effects ----------------------------------------------------------------------

func _particles(pos: Vector2, amount: int, lifetime: float, color: Color, tex: Texture2D, additive: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = tex
	if additive:
		p.material = Art.additive()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 520.0
	p.gravity = Vector2(0, 900)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 0.92, color.a) if additive else color)
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.3, color)
	p.color_ramp = ramp
	_fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.6).timeout.connect(p.queue_free)
	return p


func _sparks(pos: Vector2, amount: int) -> void:
	var p := _particles(pos, amount, 0.45, Color(1.0, 0.62, 0.2), Art.streak(), true)
	p.particle_flag_align_y = true
	p.direction = Vector2(0, -1)
	p.spread = 100.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 720.0
	p.gravity = Vector2(0, 1300)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9


func _impact_flash(pos: Vector2, size: float) -> void:
	var s := Sprite2D.new()
	s.texture = Art.soft_dot()
	s.material = Art.additive()
	s.position = pos
	s.scale = Vector2.ONE * size
	s.modulate = Color(1, 0.9, 0.7, 0.95)
	_fx.add_child(s)
	var t := create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2.ONE * size * 0.3, 0.16)
	t.tween_property(s, "modulate:a", 0.0, 0.16)
	t.chain().tween_callback(s.queue_free)


func _screen_flash(strength: float) -> void:
	_flash_rect.color.a = strength
	create_tween().tween_property(_flash_rect, "color:a", 0.0, 0.35)


func _damage_smoke(car: Car) -> Array:
	var out := []
	for fire in [false, true]:
		var p := CPUParticles2D.new()
		p.texture = Art.soft_dot()
		p.emitting = false
		p.amount = 14 if fire else 26
		p.lifetime = 0.6 if fire else 1.6
		p.direction = Vector2(0, -1)
		p.spread = 25.0
		p.gravity = Vector2(0, -90 if fire else -60)
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 90.0
		p.scale_amount_min = 0.25 if fire else 0.4
		p.scale_amount_max = 0.5 if fire else 0.9
		var ramp := Gradient.new()
		if fire:
			p.material = Art.additive()
			ramp.set_color(0, Color(1, 0.85, 0.4, 0.9))
			ramp.set_color(1, Color(1, 0.25, 0.05, 0.0))
		else:
			ramp.set_color(0, Color(0.25, 0.23, 0.26, 0.6))
			ramp.set_color(1, Color(0.4, 0.38, 0.4, 0.0))
		p.color_ramp = ramp
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.0 if fire else 1.6))
		p.scale_amount_curve = curve
		p.position = Vector2(-30 * car.dir, -45)
		p.z_index = 3
		car.chassis.add_child(p)
		out.append(p)
	return out


func _explosion(pos: Vector2) -> void:
	var fire := _particles(pos, 46, 0.75, Color(1.0, 0.45, 0.12), Art.soft_dot(), true)
	fire.initial_velocity_min = 60.0
	fire.initial_velocity_max = 420.0
	fire.scale_amount_min = 0.7
	fire.scale_amount_max = 1.8
	fire.gravity = Vector2(0, -160)
	var smoke := _particles(pos, 28, 1.9, Color(0.22, 0.2, 0.24, 0.8), Art.soft_dot(), false)
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 240.0
	smoke.scale_amount_min = 0.9
	smoke.scale_amount_max = 2.0
	smoke.gravity = Vector2(0, -110)
	var embers := _particles(pos, 40, 0.9, Color(1.0, 0.6, 0.2), Art.streak(), true)
	embers.particle_flag_align_y = true
	embers.initial_velocity_min = 350.0
	embers.initial_velocity_max = 950.0
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 0.8
	_impact_flash(pos, 6.0)
	var ring := DrawNode.new(func(ci): ci.draw_arc(Vector2.ZERO, 40.0, 0, TAU, 40, Color(1, 0.9, 0.65), 7.0))
	ring.position = pos
	ring.scale = Vector2(0.3, 0.3)
	_fx.add_child(ring)
	var t := create_tween().set_parallel()
	t.tween_property(ring, "scale", Vector2(5, 5), 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(ring.queue_free)


func _debris(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		var b := RigidBody2D.new()
		b.position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		b.collision_layer = 0
		b.collision_mask = Car.LAYER_WORLD
		b.mass = 0.2
		var s := randf_range(5, 11)
		var pts := PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s, -s * 0.3), Vector2(s * 0.3, s), Vector2(-s * 0.5, s * 0.7)])
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		b.add_child(cp)
		var shade := color.darkened(randf_range(0.0, 0.35))
		b.add_child(DrawNode.new(func(ci): Art.shaded(ci, pts, shade, 2.0, 0.25)))
		_fx.add_child(b)
		b.linear_velocity = Vector2(randf_range(-400, 400), randf_range(-650, -200))
		b.angular_velocity = randf_range(-18, 18)
		fade_out(b, randf_range(1.5, 2.5))


func _damage_number(pos: Vector2, amount: float, big: bool) -> void:
	var l := UI.label(str(roundi(amount)), 38 if big else 22, Color(1, 0.88, 0.3) if big else Color(1, 1, 1, 0.92), 8)
	l.position = pos + Vector2(randf_range(-18, 18) - 20, -40)
	l.pivot_offset = Vector2(20, 20)
	_fx.add_child(l)
	var t := create_tween().set_parallel()
	if big:
		l.scale = Vector2(1.7, 1.7)
		t.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y - 80, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	t.chain().tween_callback(l.queue_free)


func _popup(pos: Vector2, text: String, color: Color) -> void:
	var l := UI.label(text, 26, color, 8)
	l.position = pos - Vector2(120, 0)
	_fx.add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 50, 1.1)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	t.tween_callback(l.queue_free)




