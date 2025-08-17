class_name OriginMarker
extends Node2D

@export var radius: float = 6.0
@export var outer: Color = Color(1,1,1,0.85)
@export var inner: Color = Color(0,0,0,0.85)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, outer)
	draw_circle(Vector2.ZERO, radius * 0.65, inner)
