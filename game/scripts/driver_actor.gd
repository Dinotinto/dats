class_name DriverActor
extends Node2D

var driver_id := "bolt"
var fear := 0
var expression: DriverExpression
var sprite: Sprite2D
var _clock := 0.0
var legs: DriverLegs

func show_full_body() -> void:
	legs = DriverLegs.new()
	legs.driver_id = driver_id
	legs.face_width = Parts.SEATS[driver_id].face
	add_child(legs)
	move_child(legs,0)

func setup(id: String, anchor: Vector2, size: float, facing: float) -> void:
	driver_id = id
	scale = Vector2(size * facing, size)
	sprite = Sprite2D.new()
	sprite.texture = Sprites.tex("seat_" + id)
	sprite.centered = false
	sprite.offset = -anchor
	add_child(sprite)
	expression = DriverExpression.new()
	expression.driver_id = id
	expression.position = -anchor
	add_child(expression)

func set_fear(level: int) -> void:
	fear = level
	expression.level = level
	expression.queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	sprite.position.x = sin(_clock * 35.0) * (2.0 if fear == 2 else 0.7) if fear > 0 else 0.0
	expression.position.x = sprite.offset.x + sprite.position.x
	rotation = sin(_clock * 18.0) * (0.035 if fear == 2 else 0.012) if fear > 0 else 0.0
