class_name PartIcon
extends Control
## Lightweight inventory art from the same catalogue and sprites as the fitted parts.
var item := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if item.is_empty(): return
	var id: String = item.id
	var center := size*.5
	if CatalogueArt.HULLS.has(id):
		texture_icon("catalogue_chassis_"+id)
		return
	if id in Catalogue.weapons() or id in Catalogue.gadgets() or id in ["booster","armour_plate","shield"]:
		texture_icon(CatalogueArt.equipment(id).sprite)
		return
	if Parts.CHASSIS.has(id):
		var body: Dictionary = Parts.CHASSIS[id]
		if body.get("procedural",false):
			var bounds := Rect2(body.polygon[0],Vector2.ZERO)
			for point in body.polygon: bounds=bounds.expand(point)
			var factor := minf((size.x-28)/bounds.size.x,(size.y-18)/(bounds.size.y+35))
			draw_set_transform(center-Vector2(0,3),0,Vector2.ONE*factor)
			var polygon: PackedVector2Array=body.polygon.duplicate()
			for i in polygon.size(): polygon[i]-=bounds.get_center()
			Art.shaded(self,polygon,Color(.65,.4,.2),2/factor,.2)
			for wheel in body.wheels:
				var position: Vector2=wheel[0]*Parts.SCALE-bounds.get_center()
				draw_circle(position,12,Color(.15,.12,.11))
				draw_circle(position,7,Color(.7,.43,.25))
				draw_circle(position,3,Art.INK)
			draw_set_transform(Vector2.ZERO)
		else: texture_icon("body_"+id)
	elif Parts.WHEELS.has(id):
		var wheel: Dictionary=Parts.WHEELS[id]
		var radius := minf(size.x,size.y)*.36
		var shade: Color = Color(.7,.4,.18) if wheel.get("material","")=="wood" else (Color(.55,.65,.7) if wheel.get("material","")=="metal" else Color(.2,.24,.28))
		draw_circle(center,radius,Art.INK)
		draw_arc(center,radius*.84,0,TAU,32,shade,5)
		for spoke in 6:
			var direction := Vector2.from_angle(spoke*TAU/6)
			draw_line(center+direction*radius*.18,center+direction*radius*.72,shade,4)
		draw_circle(center,5,Color(.78,.7,.57))
	elif Parts.WEAPONS.has(id):
		var weapon: Dictionary=Parts.WEAPONS[id]
		if weapon.has("sprite"):
			texture_icon(weapon.sprite)
			if weapon.has("disc"):
				var disc := Sprites.tex(weapon.disc)
				draw_texture_rect(disc,Rect2(center+Vector2(17,-21),Vector2(42,42)),false)
		else:
			draw_set_transform(center,0,Vector2.ONE)
			if weapon.procedural=="gun":
				var paint: Color = {"blaster":Color(.25,.7,.9),"hook":Color(.8,.6,.23),"rocket":Color(.8,.35,.18),"double_rocket":Color(.8,.35,.18),"laser":Color(.85,.23,.27),"minigun":Color(.28,.34,.38)}.get(id,Color(.43,.55,.6))
				Art.shaded(self,PackedVector2Array([Vector2(-30,-17),Vector2(28,-17),Vector2(37,-8),Vector2(37,8),Vector2(-30,17)]),paint,2,.2)
				draw_line(Vector2(-13,-9),Vector2(30,-9),Color(.8,.85,.8),3)
				draw_line(Vector2(30,-17),Vector2(30,8),Art.INK,4)
				draw_circle(Vector2(-16,0),6,Color(.18,.25,.3))
				if id=="hook": draw_arc(Vector2(43,0),7,-PI*.5,PI*.5,12,Art.STEEL,3)
			elif weapon.procedural=="rotor":
				Art.shaded(self,PackedVector2Array([Vector2(-40,-5),Vector2(34,-8),Vector2(44,0),Vector2(34,8),Vector2(-40,5)]),Art.STEEL,2,.3)
				draw_circle(Vector2.ZERO,8,Color(.7,.4,.2))
			else:
				var length := 45.0 if weapon.get("length",85.0)>100 else 30.0
				Art.shaded(self,PackedVector2Array([Vector2(-27,-5),Vector2(length-10,-4),Vector2(length,0),Vector2(length-10,4),Vector2(-27,5)]),Art.STEEL,2,.3)
				draw_line(Vector2(-28,-13),Vector2(-28,13),Color(.65,.35,.15),5)
				draw_line(Vector2(-40,0),Vector2(-28,0),Color(.3,.21,.16),6)
			draw_set_transform(Vector2.ZERO)
	else:
		var data: Dictionary = Parts.GADGETS[id]
		if data.has("sprite"): texture_icon(data.sprite)
		else:
			var rect := Rect2(center-Vector2(22,19),Vector2(44,38))
			draw_style_box(UI.box(Color(.6,.35,.19),Art.INK,4,2,2),rect)
			if id=="first_aid":
				draw_line(center-Vector2(10,0),center+Vector2(10,0),Color(.95,.9,.75),6)
				draw_line(center-Vector2(0,10),center+Vector2(0,10),Color(.95,.9,.75),6)
			elif id=="forklift":
				draw_line(center-Vector2(15,2),center+Vector2(45,2),Color(.75,.75,.65),5)
			else: draw_circle(center,9,Color(.45,.6,.65))

func texture_icon(id: String) -> void:
	var texture := Sprites.tex(id)
	var texture_size := texture.get_size()
	var factor := minf((size.x-16)/texture_size.x,(size.y-10)/texture_size.y)
	var rect := Rect2((size-texture_size*factor)*.5,texture_size*factor)
	draw_texture_rect(texture,Rect2(rect.position+Vector2(3,4),rect.size),false,Color(0,0,0,.25))
	draw_texture_rect(texture,rect,false)
