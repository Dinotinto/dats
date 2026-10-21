class_name DriverLegs
extends Node2D
## Animated lower body in the same source-pixel scale as the seated driver.
var driver_id := "bolt"
var face_width := 200.0
var clock := 0.0
var landed := false

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var f := face_width
	var trousers := Color(0.19,0.23,0.3)
	var fur: Color = {"bolt":Color(0.85,0.46,0.18),"nova":Color(0.32,0.29,0.38),"tank":Color(0.75,0.68,0.55),"patch":Color(0.9,0.74,0.48),"dash":Color(0.45,0.48,0.53),"spark":Color(0.46,0.3,0.18)}[driver_id]
	var hips := f*0.55
	var length := f*0.8
	var tail := PackedVector2Array([Vector2(-f*.18,hips),Vector2(-f*.5,hips+f*.1),Vector2(-f*.62,hips-f*.15),Vector2(-f*.7,hips-f*.2)])
	draw_polyline(tail,Art.INK,f*.11,true)
	draw_polyline(tail,fur,f*.08,true)
	for side in [-1.0,1.0]:
		var hip := Vector2(side*f*.18,hips)
		var knee := hip+Vector2(side*f*.06,length*.5)
		var foot := hip+Vector2(side*f*.1+sin(clock*4+side)*f*.05*(0 if landed else 1),length)
		var leg := PackedVector2Array([hip,knee,foot])
		draw_polyline(leg,Art.INK,f*.27,true)
		draw_polyline(leg,trousers,f*.23,true)
		var boot := Art.circle(foot+Vector2(f*.04,0),1,20,Vector2(f*.15,f*.075))
		draw_colored_polygon(boot,Art.INK)
		draw_line(foot+Vector2(-f*.06,-f*.02),foot+Vector2(f*.13,-f*.02),trousers.lightened(.18),f*.05,true)
	Art.shaded(self,PackedVector2Array([Vector2(-f*.24,hips-f*.25),Vector2(f*.23,hips-f*.25),Vector2(f*.23,hips+f*.08),Vector2(-f*.23,hips+f*.08)]),trousers,3,.15)
	draw_line(Vector2(-f*.23,hips-f*.12),Vector2(f*.23,hips-f*.12),Color(.36,.25,.18),f*.06)
