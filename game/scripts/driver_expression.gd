class_name DriverExpression
extends Node2D
## Expressions are drawn over the user's seated driver art in source-pixel coordinates.
## They are cosmetic and never alter the car's collision or damage shapes.

const FACES := {
	"bolt": {"eyes": [Vector2(253, 160), Vector2(333, 190)], "radii": [Vector2(29, 29), Vector2(20, 24)], "mouth": Vector2(271, 227), "muzzle": Color(0.95, 0.84, 0.65), "iris": Color(0.45, 0.63, 0.14)},
	"nova": {"eyes": [Vector2(191, 193), Vector2(283, 221)], "radii": [Vector2(29, 24), Vector2(19, 21)], "mouth": Vector2(248, 254), "muzzle": Color(0.72, 0.64, 0.57), "iris": Color(0.67, 0.35, 0.83)},
	"tank": {"eyes": [Vector2(273, 136), Vector2(358, 156)], "radii": [Vector2(22, 22), Vector2(17, 20)], "mouth": Vector2(315, 195), "muzzle": Color(0.89, 0.82, 0.68), "iris": Color(0.26, 0.6, 0.8)},
	"patch": {"eyes": [Vector2(223, 175), Vector2(321, 209)], "radii": [Vector2(31, 28), Vector2(22, 24)], "mouth": Vector2(251, 244), "muzzle": Color(0.93, 0.83, 0.66), "iris": Color(0.36, 0.63, 0.23)},
	"dash": {"eyes": [Vector2(268, 198), Vector2(356, 215)], "radii": [Vector2(25, 24), Vector2(15, 20)], "mouth": Vector2(301, 260), "muzzle": Color(0.74, 0.73, 0.69), "iris": Color(0.94, 0.64, 0.12)},
	"spark": {"eyes": [Vector2(239, 174), Vector2(325, 199)], "radii": [Vector2(29, 28), Vector2(23, 25)], "mouth": Vector2(268, 252), "muzzle": Color(0.7, 0.5, 0.3), "iris": Color(0.95, 0.62, 0.15)},
}

var driver_id := "bolt"
var level := 0
var clock := 0.0

func _process(delta: float) -> void:
	if level > 0:
		clock += delta
		queue_redraw()

func ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_colored_polygon(Art.circle(center, 1.0, 28, radius), color)

func _draw() -> void:
	if level == 0:
		return
	var face: Dictionary = FACES[driver_id]
	for i in 2:
		var eye: Vector2 = face.eyes[i]
		var radius: Vector2 = face.radii[i] * (1.05 if level == 1 else 1.12)
		ellipse(eye, radius + Vector2(2, 2), Art.INK)
		ellipse(eye, radius, Color(1.0, 0.98, 0.9))
		var pupil := eye + Vector2(4 if i == 0 else -3, 1)
		ellipse(pupil, radius * 0.36, face.iris)
		ellipse(pupil, radius * 0.18, Color(0.08, 0.05, 0.07))
		ellipse(pupil + Vector2(-2, -3), Vector2(2.5, 3.5), Color.WHITE)
		# Inner brow ends rise: worried, rather than the normal confident expression.
		var direction := 1.0 if i == 0 else -1.0
		var brow := PackedVector2Array([eye + Vector2(-direction * radius.x, -radius.y - 7), eye + Vector2(0, -radius.y - 12), eye + Vector2(direction * radius.x, -radius.y - 17)])
		draw_polyline(brow, Art.INK, 5.0, true)
	if level == 2:
		var mouth: Vector2 = face.mouth
		ellipse(mouth, Vector2(34, 26), face.muzzle)
		ellipse(mouth, Vector2(17, 24), Art.INK)
		ellipse(mouth + Vector2(0, 9), Vector2(11, 9), Color(0.85, 0.3, 0.33))
		draw_line(mouth + Vector2(-10, -15), mouth + Vector2(10, -15), Color(1, 0.94, 0.8), 4.0)
	var sweat_origin: Vector2 = face.eyes[1] + Vector2(35, -18)
	var drop := sweat_origin + Vector2(0, fmod(clock * 45.0, 34.0))
	var pts := PackedVector2Array([drop + Vector2(0, -10), drop + Vector2(-5, 2), drop + Vector2(-4, 6), drop + Vector2(4, 6), drop + Vector2(6, 1)])
	draw_colored_polygon(pts, Color(0.38, 0.86, 1.0))
	draw_polyline(pts, Color(0.1, 0.4, 0.65), 1.5, true)
