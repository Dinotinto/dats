class_name GarageMechanic
extends Node2D
## The chosen driver works beside the preview car, outside its physics assembly.

var actor: DriverActor
var driver_id := ""
var full_body: Sprite2D
var facing := 1.0
var clock := 0.0
var tune_time := 1.1
var tool: DrawNode

func setup(id: String, direction: float) -> void:
	driver_id = id
	facing = direction
	if id in Parts.DRIVERS:
		full_body = Sprite2D.new()
		full_body.texture = load("res://art/driver_" + id + "_full.png")
		full_body.centered = false
		var height := 210.0
		var fit := height / float(full_body.texture.get_height())
		full_body.scale = Vector2.ONE * fit
		full_body.position = Vector2(-float(full_body.texture.get_width()) * fit * 0.5, 84.0 - height)
		add_child(full_body)
		return
	var seat: Dictionary = Parts.SEATS[id]
	actor = DriverActor.new()
	actor.setup(id, seat.chin, 62.0 / seat.face, facing)
	actor.show_full_body()
	actor.legs.landed = true
	add_child(actor)
	tool = DrawNode.new(func(ci): _paint_tool(ci))
	add_child(tool)

func _process(delta: float) -> void:
	clock += delta
	tune_time = maxf(0.0, tune_time - delta)
	if is_instance_valid(full_body):
		full_body.position.y = -126.0 + sin(clock * (8.0 if tune_time > 0.0 else 2.0)) * (2.0 if tune_time > 0.0 else 0.7)
	if is_instance_valid(tool): tool.queue_redraw()
	queue_redraw()

func tune() -> void:
	tune_time = 1.1

func _draw() -> void:
	draw_colored_polygon(Art.circle(Vector2(0, 83), 1.0, 24, Vector2(75, 9)), Color(0.08, 0.05, 0.03, 0.35))

func _paint_tool(ci: CanvasItem) -> void:
	var working := tune_time > 0.0
	var hand := Vector2(facing * 40.0, -38.0 + (sin(clock * 16.0) * 7.0 if working else sin(clock * 2.0) * 1.5))
	ci.draw_line(Vector2(facing * 12.0, -55.0), hand, Color(0.17, 0.22, 0.29), 15.0, true)
	ci.draw_line(Vector2(facing * 12.0, -55.0), hand, Color(0.64, 0.45, 0.27), 10.0, true)
	ci.draw_circle(hand, 10.0, Art.INK)
	ci.draw_circle(hand, 7.0, Color(0.87, 0.56, 0.3))
	var tip := hand + Vector2(facing * 23.0, -20.0)
	ci.draw_line(hand, tip, Art.INK, 11.0, true)
	ci.draw_line(hand, tip, Color(0.64, 0.77, 0.83), 7.0, true)
	ci.draw_arc(tip + Vector2(facing * 5.0, -4.0), 10.0, -PI * 0.65, PI * 0.65, 16, Art.INK, 5.0)
	ci.draw_arc(tip + Vector2(facing * 5.0, -4.0), 10.0, -PI * 0.65, PI * 0.65, 16, Color(0.85, 0.94, 0.95), 2.5)
	if working:
		for i in 4:
			var pulse := fmod(clock * 5.0 + i * 0.29, 1.0)
			var spark := tip + Vector2(facing * (12.0 + pulse * 20.0), -pulse * 26.0 + i * 6.0)
			ci.draw_line(spark, spark + Vector2(facing * 5.0, -5.0), Color(1.0, 0.74, 0.24, 1.0 - pulse), 2.0)
