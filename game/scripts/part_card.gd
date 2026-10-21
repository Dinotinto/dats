class_name PartCard
extends Button
var item := {}
var garage
var caption := ""
var badge := ""

func _ready() -> void:
	caption = text
	text = ""
	var icon := PartIcon.new()
	icon.item = item
	icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	icon.offset_top=5
	icon.offset_bottom=60
	add_child(icon)
	var label := UI.label(caption,14,Color(.96,.9,.75),1)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top=-67
	label.offset_bottom=-7
	add_child(label)
	if badge != "":
		var tag := UI.label(badge,11,Color(1,.94,.73),1)
		tag.mouse_filter=Control.MOUSE_FILTER_IGNORE
		tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		tag.offset_top=2
		tag.offset_bottom=19
		tag.offset_right=-6
		add_child(tag)

func _can_drop_data(_position: Vector2,data) -> bool:
	return data is Dictionary and data.get("origin","")=="equipped"

func _drop_data(_position: Vector2,data) -> void:
	garage.remove_part(data.slot)

func _get_drag_data(_position: Vector2):
	if is_instance_valid(garage.parts_scroll) and garage.parts_scroll.swipe_suppresses_click(): return null
	var preview := PartIcon.new()
	preview.item = item
	preview.custom_minimum_size=Vector2(150,90)
	preview.size=Vector2(150,90)
	set_drag_preview(preview)
	return {"uid":item.uid,"id":item.id,"origin":"inventory","preview":weakref(preview)}
