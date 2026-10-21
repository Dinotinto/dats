class_name ParachuteEscape
extends Node2D
## A cosmetic escape actor: ballistic seat launch, canopy deployment and soft landing.
## It has no physics collision layers, so it can never be hit by weapons or spike walls.

const DEPLOY_AT := 0.5
const OPEN_TIME := 0.25
const DESCENT_SPEED := 58.0

var actor: DriverActor
var team_color := Color.WHITE
var clock := 0.0
var velocity := Vector2.ZERO
var canopy_open := 0.0
var landed := false
var facing := 1.0

func setup(car: Car) -> void:
	position = car.driver_world_position()
	facing = car.dir
	team_color = car.color
	velocity = Vector2(signf(-position.x) * 90.0, -540.0)
	if absf(position.x) < 10:
		velocity.x = car.dir * 90.0
	actor = DriverActor.new()
	var seat: Dictionary = Parts.SEATS[car.driver_id()]
	actor.setup(car.driver_id(), seat.chin, 62.0 / seat.face, car.dir)
	actor.show_full_body()
	actor.set_fear(2)
	add_child(actor)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	clock += delta
	canopy_open = clampf((clock - DEPLOY_AT) / OPEN_TIME, 0.0, 1.0)
	if not landed:
		if canopy_open < 1.0:
			velocity.y += 720.0 * delta
		else:
			velocity.y = move_toward(velocity.y, DESCENT_SPEED, 650.0 * delta)
			velocity.x = move_toward(velocity.x, facing * 30.0, 120.0 * delta)
		position += velocity * delta
		if clock > 1.0 and position.y >= -88.0:
			position.y = -88.0
			velocity = Vector2.ZERO
			landed = true
			actor.set_fear(0)
			actor.legs.landed = true
		actor.position.x = sin(clock * 3.0) * 4.0 * canopy_open
		if clock >= 1.6:
			actor.set_fear(0)
	queue_redraw()

func _draw() -> void:
	# Ejection seat stays with the driver, while a short rocket plume launches it.
	var seat := PackedVector2Array([Vector2(-17, -5), Vector2(17, -5), Vector2(20, 13), Vector2(-20, 13)])
	Art.shaded(self, seat, Art.STEEL, 2.0, 0.2)
	if clock < DEPLOY_AT:
		var flame := PackedVector2Array([Vector2(-8, 13), Vector2(0, 39 + sin(clock * 45) * 9), Vector2(8, 13)])
		draw_colored_polygon(flame, Color(1, 0.55, 0.1))
		draw_line(Vector2(0, 14), Vector2(0, 29), Color(1, 0.95, 0.6), 4)
	if canopy_open <= 0:
		return
	var sway := sin(clock * 3.0) * 8.0
	var center := Vector2(sway, -118)
	var radius := Vector2(77, 51) * canopy_open
	var rim_y := center.y + 12
	for x in [-1.0, -0.5, 0.5, 1.0]:
		draw_line(Vector2(center.x + radius.x * x, rim_y), Vector2(actor.position.x + x * 13, -27), Color(0.9, 0.86, 0.7), 1.5)
	var pts := PackedVector2Array()
	for i in 25:
		var angle := PI + PI * i / 24.0
		pts.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	pts.append(Vector2(center.x + radius.x, rim_y))
	pts.append(Vector2(center.x - radius.x, rim_y))
	draw_colored_polygon(pts, team_color.lightened(0.25))
	draw_polyline(pts, Art.INK, 3.0, true)
	for x in [-0.5, 0.0, 0.5]:
		draw_line(center + Vector2(x * radius.x * 0.3, -radius.y * sqrt(1.0 - x * x * 0.09)), Vector2(center.x + x * radius.x, rim_y), team_color.darkened(0.3), 2.0)
	draw_line(Vector2(center.x - radius.x, rim_y), Vector2(center.x + radius.x, rim_y), Art.INK, 3.0)
