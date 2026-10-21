class_name InventoryDropZone
extends PanelContainer
var garage

func _can_drop_data(_position: Vector2,data) -> bool:
	return data is Dictionary and data.get("origin","")=="equipped"

func _drop_data(_position: Vector2,data) -> void:
	garage.remove_part(data.slot)
