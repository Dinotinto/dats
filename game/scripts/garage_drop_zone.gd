class_name GarageDropZone
extends Control
var garage

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not get_viewport().gui_is_dragging():
		garage.select_part_at(event.position)

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary or not data.has("uid") or not data.has("id"): return false
	var pointer: Vector2 = garage.workspace_pointer if data.has("origin") else at_position
	var slot: String = garage.drop_slot(pointer,data)
	return slot != "" and garage.can_fit_payload(slot,data)

func _drop_data(at_position: Vector2, data) -> void:
	# Use the same touch/mouse point that drove the preview, rather than a stale cursor.
	var pointer: Vector2 = garage.workspace_pointer if data.has("origin") else at_position
	var slot: String = garage.drop_slot(pointer,data)
	if slot != "": garage.fit_item(slot,data.uid)
