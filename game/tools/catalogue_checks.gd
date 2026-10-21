extends SceneTree
var failures := 0
func _initialize() -> void: checks.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func settle() -> void:
	for i in 4: await physics_frame
func checks() -> void:
	for team in 2:
		for id in ["drill","stinger","chainsaw"]:
			var attacker := Car.new()
			root.add_child(attacker)
			attacker.setup({"chassis":"classic","front":id,"wheels":"rubber_medium"},team,Vector2(-2000,0),Color.WHITE,null)
			attacker.freeze_all()
			var target := Car.new()
			root.add_child(target)
			target.setup({"chassis":"classic","wheels":"rubber_medium"},1-team,Vector2(2000,0),Color.WHITE,null)
			target.freeze_all()
			var hurt := Area2D.new()
			hurt.collision_layer=Car.HURT_LAYERS[1-team]
			hurt.collision_mask=0
			hurt.set_meta("car",target)
			hurt.set_meta("part",target.chassis_part)
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius=1
			shape.shape=circle
			hurt.add_child(shape)
			root.add_child(hurt)
			var art := CatalogueArt.equipment(id)
			var mount := attacker._px(Parts.mount_point("classic","front",attacker.build))
			hurt.position=attacker.chassis.to_global(attacker._m(mount))
			await settle()
			check(attacker.collect_hits(1.0/60).is_empty(),id+" mounting socket deals no damage, facing "+str(team))
			var tip := Vector2(art.size.x*.8,art.size.y*.55)
			hurt.position=attacker.chassis.to_global(attacker._m(mount+(tip-art.anchor)*art.scale))
			await settle()
			var hits := attacker.collect_hits(1.0/60)
			check(hits.size()==1 and hits[0][2]>0,id+" active cutting edge deals contact damage, facing "+str(team))
			check(attacker.weapon_parts()[0].attack_rating==Catalogue.weapons()[id].attack,id+" artwork preserves attack rating")
			hurt.queue_free()
			attacker.queue_free()
			target.queue_free()
			await process_frame
	for id in CatalogueArt.HULLS:
		var data: Dictionary=Parts.CHASSIS[id]
		var texture := Sprites.tex(data.catalogue_sprite)
		check(texture!=null and data.polygon.size()>=3,id+" has imported art and matching hull silhouette")
	print("CATALOGUE CHECKS: %d failures"%failures)
	quit(1 if failures else 0)
