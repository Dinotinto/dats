class_name SwipePartsShelf
extends ScrollContainer
## Touch swipes pan the cards; vertical drags still use normal part drag-and-drop.

var _finger := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _panning := false
var _suppress_tap_until := 0

func swipe_suppresses_click() -> bool:
	return _panning or Time.get_ticks_msec() < _suppress_tap_until

func _input(event: InputEvent) -> void:
	# The shelf's raw input handler must respect the same cloud lock as the garage.
	for node in get_tree().get_nodes_in_group("dats_cloud_input_lock"):
		if node.busy: return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
			_finger = event.index
			_start = event.position
			_last = event.position
			_panning = false
		elif not event.pressed and event.index == _finger:
			if _panning:
				_suppress_tap_until = Time.get_ticks_msec() + 180
			_finger = -1
			_panning = false
	elif event is InputEventScreenDrag and event.index == _finger:
		var travel: Vector2 = event.position - _start
		if not _panning and absf(travel.x) > 6.0 and absf(travel.x) > absf(travel.y) * 1.2:
			_panning = true
		if _panning:
			var max_scroll := int(maxf(0.0, get_h_scroll_bar().max_value - get_h_scroll_bar().page))
			scroll_horizontal = clampi(scroll_horizontal - roundi(event.position.x - _last.x), 0, max_scroll)
			get_viewport().set_input_as_handled()
		_last = event.position
