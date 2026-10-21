class_name DrawNode
extends Node2D
## A node whose look is drawn by a painter callable: painter(canvas_item).
## Lets parts be drawn procedurally now and swapped for sprite art later.

var painter: Callable


func _init(p_painter: Callable = Callable()) -> void:
	painter = p_painter


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
