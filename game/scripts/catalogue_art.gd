class_name CatalogueArt
extends RefCounted
## Sprite anchors measured in trimmed asset pixels; physics dimensions are world units.
const HULLS := {
	"classic": [233.0,Vector2(186,186),Vector2(230,111),Vector2(50,178),Vector2(323,194)],
	"sneaky": [167.0,Vector2(205,137),Vector2(215,77),Vector2(72,111),Vector2(344,153)],
	"boulder": [152.0,Vector2(161,259),Vector2(170,135),Vector2(60,210),Vector2(259,231)],
	"surfer": [303.0,Vector2(237,151),Vector2(250,81),Vector2(50,150),Vector2(438,166)],
	"titan": [175.0,Vector2(161,389),Vector2(193,178),Vector2(57,389),Vector2(280,387)],
	"whale": [253.0,Vector2(224,219),Vector2(280,139),Vector2(65,221),Vector2(357,229)],
	"pyramid": [220.0,Vector2(223,336),Vector2(288,206),Vector2(84,336),Vector2(347,336)],
	"diamond": [190.0,Vector2(178,376),Vector2(190,218),Vector2(32,247),Vector2(324,254)]
}

static func hull(id: String, data: Dictionary) -> void:
	var spec: Array=HULLS[id]
	var texture := Sprites.tex("catalogue_chassis_"+id)
	var scale: float=spec[0]/texture.get_width()
	data.catalogue_sprite="catalogue_chassis_"+id
	data.sprite_anchor=spec[1]
	data.sprite_scale=scale
	data.chin=(spec[2]-spec[1])*scale/Parts.SCALE
	data.face=90.0 if id in ["sneaky","boulder","diamond"] else 100.0
	for i in 2: data.wheels[i][0]=(spec[3+i]-spec[1])*scale/Parts.SCALE
	# Preserve slopes and broad hull edges; omit small rivet notches that snag.
	var points := PackedVector2Array()
	for p in Sprites.outlines(data.catalogue_sprite)[0]: points.append((p-spec[1])*scale)
	data.polygon=points
	data.com=Vector2(0,-texture.get_height()*scale*.3)/Parts.SCALE
	data.art_sockets={"front":Vector2(spec[0]*.32,-35)/Parts.SCALE,"top":Vector2(-spec[0]*.3,-texture.get_height()*scale*.6)/Parts.SCALE,"gadget":Vector2(spec[0]*.28,-8)/Parts.SCALE,"gadget2":Vector2(-spec[0]*.32,-30)/Parts.SCALE}
	if id=="titan":
		data.art_sockets = {"front":Vector2(55,-115)/Parts.SCALE,"top":Vector2(50,-170)/Parts.SCALE,"attack3":Vector2(60,-65)/Parts.SCALE,"attack4":Vector2(-45,-100)/Parts.SCALE,"defence_front":Vector2(65,-10)/Parts.SCALE,"gadget":Vector2(-45,-155)/Parts.SCALE,"gadget2":Vector2(-45,-60)/Parts.SCALE}
	if id=="diamond":
		data.art_sockets.front=Vector2(40,-65)/Parts.SCALE
		data.art_sockets.gadget=Vector2(55,-30)/Parts.SCALE
	if id=="boulder": data.art_sockets.front=Vector2(25,-43)/Parts.SCALE
	for slot in ["attack3","attack4","defence_front","gadget3"]:
		if data.art_sockets.has(slot): continue
		var offset: Vector2={"attack3":Vector2(75,20),"attack4":Vector2(-70,-20),"defence_front":Vector2(50,55),"gadget3":Vector2(-30,-80)}[slot]
		data.art_sockets[slot]=data.com+offset
	# Keep every fixed socket on the hull rather than in transparent atlas padding.
	for slot in data.art_sockets:
		var position: Vector2=data.art_sockets[slot]*Parts.SCALE
		var toward := position.direction_to(data.com*Parts.SCALE)
		for step in 100:
			if Geometry2D.is_point_in_polygon(position,data.polygon): break
			position+=toward*2
		data.art_sockets[slot]=position/Parts.SCALE

static func equipment(id: String) -> Dictionary:
	# These launchers reuse modular housings with dedicated visible ammunition.
	if id=="balloon_launcher": id="laser"
	if id in ["net_launcher","flipper_net"]: id="minigun"
	var group := "weapons" if id in Catalogue.weapons() else "gadgets"
	if id=="shield": id="armour_plate"
	var name := "catalogue_%s_%s"%[group,id]
	var size := Sprites.tex(name).get_size()
	var anchor := Vector2(size.x*.11,size.y*.55)
	var width: float = 105.0
	if group=="weapons":
		width={"rocket":110.0,"double_rocket":145.0,"laser":110.0,"minigun":120.0,"blade":115.0,"drill":120.0,"stinger":145.0,"chainsaw":115.0}.get(id,105.0)
		if id=="double_rocket": anchor=Vector2(size.x*.47,size.y*.48)
	else:
		width={"booster":65.0,"backpedal":65.0,"forklift":130.0,"repulse":85.0,"harpoon":105.0,"lifter":95.0,"first_aid":70.0,"armour_plate":42.0}.get(id,65.0)
		if id=="booster": anchor=Vector2(size.x*.93,size.y*.55)
		if id=="forklift": anchor=Vector2(size.x*.12,size.y*.7)
	return {"sprite":name,"anchor":anchor,"scale":width/size.x,"size":size,"active_from":{"drill":.55,"stinger":.52,"chainsaw":.53}.get(id,0.0)}
