class_name GaragePlacementPreview
extends Control
## The same art, mount anchor and transform as the assembled part.
var garage: GarageUI

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	if garage.drag_slot == "" or garage.drag_uid == "": return
	var item: Dictionary = garage.main.inventory.find_item(garage.drag_uid)
	if item.is_empty(): return
	var id: String = item.id
	var art := {}
	var mount := Vector2.ZERO
	if garage.drag_slot == "chassis":
		var data: Dictionary = Parts.CHASSIS[id]
		art = {"sprite":data.get("catalogue_sprite","body_"+id),"anchor":data.get("sprite_anchor",data.origin),"scale":data.get("sprite_scale",Parts.SCALE)}
	elif Parts.WHEELS.has(id):
		var index := 0 if garage.drag_slot=="rear_wheel" else 1
		var data: Dictionary = Parts.CHASSIS[garage.current_build().chassis]
		var sprite: String = "wheel_%s_%d" % [data.get("art_id",garage.current_build().chassis),index]
		var scale: float = Parts.SCALE * Parts.WHEELS[id].size
		if data.get("procedural",false): scale *= data.wheels[index][1]/Parts.CHASSIS.wedge.wheels[index][1]
		art = {"sprite":sprite,"anchor":Sprites.tex(sprite).get_size()*0.5,"scale":scale}
		mount = garage.car._m(garage.car._px(data.wheels[index][0]))
	elif id in Catalogue.weapons() or id in Catalogue.gadgets() or id in ["booster", "armour_plate", "shield"]:
		art = CatalogueArt.equipment(id)
		if id == "shield": art.scale *= 1.8
	else:
		var data: Dictionary = Parts.base_for(id)
		if not data.has("sprite"):
			mount = garage.car._m(garage.car._px(Parts.mount_point(garage.current_build().chassis,garage.drag_slot,garage.current_build())))
			var local_transform: Transform2D = garage.viewport.get_canvas_transform() * garage.car.chassis.global_transform * Transform2D(0,mount)
			draw_set_transform_matrix(local_transform.scaled_local(Vector2(garage.car.dir,1)))
			var points := PackedVector2Array([Vector2(-12,-12),Vector2(45,-12),Vector2(45,8),Vector2(-12,14)])
			if data.get("procedural","")=="sword":
				points = PackedVector2Array([Vector2(14,-7),Vector2(data.length-12,-5),Vector2(data.length,0),Vector2(14,7)])
			draw_colored_polygon(points,Color(.65,1,.72,.65) if garage.drag_affordable else Color(1,.4,.3,.65))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		art = {"sprite":data.sprite,"anchor":data.anchor,"scale":Parts.SCALE*data.get("art_scale",1.0)}
	if garage.drag_slot != "chassis" and not Parts.WHEELS.has(id):
		mount = garage.car._m(garage.car._px(Parts.mount_point(garage.current_build().chassis,garage.drag_slot,garage.current_build())))
	var transform: Transform2D = garage.viewport.get_canvas_transform() * garage.car.chassis.global_transform * Transform2D(0.0, mount)
	transform = transform.scaled_local(Vector2(garage.car.dir,1)*art.scale)
	draw_set_transform_matrix(transform)
	draw_texture(Sprites.tex(art.sprite),-art.anchor,Color(0.65,1,0.72,0.65) if garage.drag_affordable else Color(1,0.4,0.3,0.65))
	draw_set_transform_matrix(Transform2D.IDENTITY)
