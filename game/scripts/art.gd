class_name Art
extends RefCounted
## Procedural "cartoon metal" drawing for cars, arena and effects.
## Every function draws onto a CanvasItem (usually a DrawNode) in that item's local space.

const INK := Color(0.06, 0.05, 0.09)
const STEEL := Color(0.68, 0.71, 0.77)
const DARK_STEEL := Color(0.3, 0.32, 0.37)
const HAZARD := Color(0.98, 0.76, 0.12)
const FUR := [Color(0.96, 0.6, 0.24), Color(0.6, 0.6, 0.66)]

static var _dot: GradientTexture2D
static var _streak: GradientTexture2D
static var _add_mat: CanvasItemMaterial


# --- Geometry helpers ---------------------------------------------------------------

static func bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func grow(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var res := Geometry2D.offset_polygon(pts, d, Geometry2D.JOIN_ROUND)
	return res[0] if res.size() > 0 else PackedVector2Array()


static func clip_rect(pts: PackedVector2Array, rect: Rect2) -> Array:
	var rp := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	return Geometry2D.intersect_polygons(pts, rp)


static func circle(center: Vector2, r: float, n := 24, squash := Vector2.ONE) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(center + Vector2.from_angle(TAU * i / n) * r * squash)
	return out


# --- Building blocks ------------------------------------------------------------------

## Vertical gradient fill.
static func gradient_poly(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var r := bounds(pts)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)


## Thick ink outline, gradient body, glossy top band, shaded bottom band, optional rivets.
static func shaded(ci: CanvasItem, pts: PackedVector2Array, base: Color, outline := 3.5, gloss := 0.22, rivet_gap := 0.0) -> void:
	if pts.size() < 3:
		return
	var o := grow(pts, outline)
	if o.size() >= 3:
		ci.draw_colored_polygon(o, INK)
	gradient_poly(ci, pts, base.lightened(0.22), base.darkened(0.3))
	var inner := grow(pts, -3.5)
	if inner.size() < 3:
		return
	var r := bounds(inner)
	for band in clip_rect(inner, Rect2(r.position.x - 1, r.position.y - 1, r.size.x + 2, r.size.y * 0.3 + 1)):
		ci.draw_colored_polygon(band, Color(1, 1, 1, gloss))
	for band in clip_rect(inner, Rect2(r.position.x - 1, r.end.y - r.size.y * 0.2, r.size.x + 2, r.size.y * 0.2 + 1)):
		ci.draw_colored_polygon(band, Color(0, 0, 0, 0.16))
	if rivet_gap > 0.0:
		rivets(ci, grow(pts, -7.0), rivet_gap, base)


static func rivets(ci: CanvasItem, path: PackedVector2Array, gap: float, base: Color) -> void:
	if path.size() < 3:
		return
	var carry := gap * 0.5
	for i in path.size():
		var a := path[i]
		var b := path[(i + 1) % path.size()]
		var length := a.distance_to(b)
		var t := carry
		while t < length:
			var p := a.lerp(b, t / length)
			ci.draw_circle(p, 2.4, base.darkened(0.5))
			ci.draw_circle(p + Vector2(-0.7, -0.7), 1.1, base.lightened(0.5))
			t += gap
		carry = t - length


static func hazard_stripes(ci: CanvasItem, area: PackedVector2Array, width := 8.0) -> void:
	if area.size() < 3:
		return
	ci.draw_colored_polygon(area, INK)
	var r := bounds(area)
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var s := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + width, r.position.y),
				Vector2(x + width + r.size.y, r.end.y), Vector2(x + r.size.y, r.end.y)])
		for piece in Geometry2D.intersect_polygons(area, s):
			ci.draw_colored_polygon(piece, HAZARD)
		x += width * 2.0


# --- Car parts --------------------------------------------------------------------------

static func chassis(ci: CanvasItem, pts: PackedVector2Array, color: Color, cockpit: Vector2, dir: float, team: int) -> void:
	cat_driver(ci, cockpit + Vector2(0, -13), dir, color, team)
	shaded(ci, pts, color, 4.0, 0.26, 26.0)
	var inner := grow(pts, -9.0)
	if inner.size() < 3:
		return
	var r := bounds(inner)
	# Racing stripe and panel seams.
	for band in clip_rect(inner, Rect2(r.position.x - 1, r.position.y + r.size.y * 0.42, r.size.x + 2, r.size.y * 0.16)):
		ci.draw_colored_polygon(band, color.darkened(0.42))
	for f in [0.3, 0.7]:
		var x: float = r.position.x + r.size.x * f
		for seam in clip_rect(inner, Rect2(x - 1, r.position.y, 2, r.size.y)):
			ci.draw_colored_polygon(seam, Color(0, 0, 0, 0.3))
	# Paw emblem.
	var e := Vector2(r.get_center().x - r.size.x * 0.15 * dir, r.position.y + r.size.y * 0.72)
	ci.draw_circle(e, 9.0, Color(0, 0, 0, 0.25))
	ci.draw_circle(e + Vector2(0, 2), 3.6, Color(1, 1, 1, 0.75))
	for k in [-1, 0, 1]:
		ci.draw_circle(e + Vector2(k * 3.6, -3.2 + absf(k) * 1.2), 1.6, Color(1, 1, 1, 0.75))
	# Windshield in front of the driver.
	var glass := PackedVector2Array()
	for p in [Vector2(17, 0), Vector2(23, -20), Vector2(29, -20), Vector2(34, 0)]:
		glass.append(cockpit + Vector2(p.x * dir, p.y))
	ci.draw_colored_polygon(grow(glass, 2.5), INK)
	ci.draw_colored_polygon(glass, Color(0.62, 0.86, 1.0, 0.75))
	ci.draw_line(glass[0].lerp(glass[1], 0.2) + Vector2(4 * dir, 0), glass[0].lerp(glass[1], 0.8) + Vector2(4 * dir, 0), Color(1, 1, 1, 0.8), 2.0)


static func cat_driver(ci: CanvasItem, h: Vector2, dir: float, team_color: Color, team: int) -> void:
	var fur: Color = FUR[team]
	for s in [-1.0, 1.0]:
		var ear := PackedVector2Array([h + Vector2(s * 3, -12), h + Vector2(s * 12, -25), h + Vector2(s * 15, -6)])
		ci.draw_colored_polygon(grow(ear, 2.5), INK)
		ci.draw_colored_polygon(ear, fur)
		var c := (ear[0] + ear[1] + ear[2]) / 3.0
		var inner := PackedVector2Array([ear[0].lerp(c, 0.45), ear[1].lerp(c, 0.45), ear[2].lerp(c, 0.45)])
		ci.draw_colored_polygon(inner, Color(1.0, 0.65, 0.7))
	ci.draw_circle(h, 16.5, INK)
	ci.draw_circle(h, 14.5, fur)
	ci.draw_circle(h + Vector2(-3 * dir, -5), 9.0, fur.lightened(0.12))
	# Tabby stripes.
	for k in [-4.0, 0.0, 4.0]:
		ci.draw_line(h + Vector2(k, -14), h + Vector2(k * 0.8, -9), fur.darkened(0.3), 2.0)
	ci.draw_circle(h + Vector2(7 * dir, 6), 7.0, fur.lightened(0.35))
	# Goggles strap and lens.
	ci.draw_line(h + Vector2(-14.5, -3), h + Vector2(14.5, -3), team_color.darkened(0.25), 5.0)
	var eye := h + Vector2(6 * dir, -3)
	ci.draw_circle(eye, 7.0, INK)
	ci.draw_circle(eye, 5.4, Color(0.86, 0.96, 1.0))
	ci.draw_circle(eye + Vector2(1.6 * dir, 0.5), 2.4, INK)
	ci.draw_circle(eye + Vector2(-1.5, -2), 1.3, Color.WHITE)
	# Nose and whiskers.
	var nose := h + Vector2(13 * dir, 3)
	ci.draw_colored_polygon(PackedVector2Array([nose + Vector2(-2.5, -1.5), nose + Vector2(2.5, -1.5), nose + Vector2(0, 2)]), Color(0.95, 0.45, 0.55))
	for y in [5.0, 9.0]:
		ci.draw_line(h + Vector2(11 * dir, 6), h + Vector2(24 * dir, y - 2), Color(INK, 0.75), 1.2)


static func wheel(ci: CanvasItem, r: float, team_color: Color) -> void:
	ci.draw_circle(Vector2.ZERO, r + 2.5, INK)
	ci.draw_circle(Vector2.ZERO, r, Color(0.13, 0.13, 0.15))
	var n := int(r * 0.75)
	for i in n:
		var a := TAU * i / n
		var q := PackedVector2Array([Vector2.from_angle(a - 0.1) * (r - 5), Vector2.from_angle(a - 0.1) * (r + 1.5),
				Vector2.from_angle(a + 0.1) * (r + 1.5), Vector2.from_angle(a + 0.1) * (r - 5)])
		ci.draw_colored_polygon(q, Color(0.24, 0.24, 0.27))
	ci.draw_arc(Vector2.ZERO, r * 0.76, 0, TAU, 32, Color(0.22, 0.22, 0.25), 2.0)
	var rim := r * 0.58
	ci.draw_circle(Vector2.ZERO, rim + 2.0, INK)
	ci.draw_circle(Vector2.ZERO, rim, STEEL)
	for i in 5:
		ci.draw_circle(Vector2.from_angle(TAU * i / 5) * rim * 0.6, rim * 0.22, DARK_STEEL)
	ci.draw_circle(Vector2.ZERO, rim * 0.34, INK)
	ci.draw_circle(Vector2.ZERO, rim * 0.28, team_color)
	ci.draw_circle(Vector2(-1, -1), rim * 0.1, Color(1, 1, 1, 0.7))


static func saw(ci: CanvasItem, r: float) -> void:
	var teeth := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * i / n
		teeth.append(Vector2.from_angle(a) * (r - 2))
		teeth.append(Vector2.from_angle(a + TAU / n * 0.7) * (r + 5))
	ci.draw_colored_polygon(grow(teeth, 2.5), INK)
	ci.draw_colored_polygon(teeth, STEEL.lightened(0.15))
	ci.draw_circle(Vector2.ZERO, r * 0.8, STEEL.darkened(0.12))
	ci.draw_arc(Vector2.ZERO, r * 0.8, 0, TAU, 32, Color(1, 1, 1, 0.3), 1.5)
	for i in 4:
		ci.draw_circle(Vector2.from_angle(TAU * i / 4 + 0.4) * r * 0.5, r * 0.13, Color(INK, 0.85))
	ci.draw_circle(Vector2.ZERO, r * 0.27, INK)
	ci.draw_circle(Vector2.ZERO, r * 0.21, DARK_STEEL)
	ci.draw_circle(Vector2.ZERO, r * 0.08, STEEL)


static func hammer(ci: CanvasItem, shaft: PackedVector2Array, head: PackedVector2Array) -> void:
	shaded(ci, shaft, Color(0.52, 0.35, 0.2), 3.0, 0.2)
	shaded(ci, head, STEEL, 3.5, 0.32, 13.0)
	var inner := grow(head, -6.0)
	if inner.size() >= 3:
		var r := bounds(inner)
		for band in clip_rect(inner, Rect2(r.position.x, r.position.y + r.size.y * 0.3, r.size.x, r.size.y * 0.4)):
			hazard_stripes(ci, band, 6.0)
	ci.draw_circle(Vector2.ZERO, 9.0, INK)
	ci.draw_circle(Vector2.ZERO, 7.0, DARK_STEEL)
	ci.draw_circle(Vector2.ZERO, 3.0, STEEL)


static func booster(ci: CanvasItem, pts: PackedVector2Array, nozzle: Vector2) -> void:
	shaded(ci, pts, Color(0.95, 0.55, 0.18), 3.0, 0.3)
	ci.draw_colored_polygon(circle(nozzle, 9.0, 16, Vector2(0.45, 1.0)), INK)
	ci.draw_colored_polygon(circle(nozzle, 6.0, 16, Vector2(0.4, 1.0)), Color(0.35, 0.1, 0.05))


## Teardrop flame pointing -x. Scale the node to flicker it.
static func flame(ci: CanvasItem) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(-14, -7), Vector2(-36, 0), Vector2(-14, 7), Vector2(0, 8)]), Color(1.0, 0.45, 0.1, 0.85))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -4.5), Vector2(-10, -4), Vector2(-22, 0), Vector2(-10, 4), Vector2(0, 4.5)]), Color(1.0, 0.92, 0.6))


# --- Effects resources ----------------------------------------------------------------------

static func soft_dot() -> Texture2D:
	if _dot == null:
		_dot = _radial(64, 64)
	return _dot


static func streak() -> Texture2D:
	if _streak == null:
		_streak = _radial(8, 40)
	return _streak


static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func _radial(w: int, h: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.65))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = w
	t.height = h
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	return t
