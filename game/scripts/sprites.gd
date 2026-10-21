class_name Sprites
extends RefCounted
## Loads game art and traces collision outlines from sprite alpha (cached).

static var _textures := {}
static var _outlines := {}
static var _baked_loaded := false


static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://art/%s.png" % name)
	return _textures[name]


## Outline polygons (sprite pixels) of the opaque parts of a sprite.
static func outlines(name: String) -> Array:
	if not _baked_loaded:
		_baked_loaded = true
		if FileAccess.file_exists("res://art/collision_outlines.json"):
			var stored = JSON.parse_string(FileAccess.get_file_as_string("res://art/collision_outlines.json"))
			if stored is Dictionary:
				for key in stored:
					var polygons := []
					for points in stored[key]:
						var polygon := PackedVector2Array()
						for point in points: polygon.append(Vector2(point[0],point[1]))
						polygons.append(polygon)
					_outlines[key] = polygons
	if not _outlines.has(name):
		if DisplayServer.get_name() == "headless":
			push_error("Missing baked collision outline: " + name)
			return []
		var img := tex(name).get_image()
		if img.is_compressed():
			img.decompress()
		var bm := BitMap.new()
		bm.create_from_image_alpha(img, 0.4)
		var polys := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 2.5)
		# Drop tiny specks; the big shapes are what matter for physics.
		_outlines[name] = polys.filter(func(p): return p.size() >= 3 and absf(_area(p)) > 400.0)
	return _outlines[name]


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5
