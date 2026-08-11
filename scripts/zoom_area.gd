extends Area2D
class_name ZoomArea

@export var hover_border_width: float = 24.0

var _hovered := false

func _ready() -> void:
	add_to_group("zoom_areas")
	collision_layer = 0
	collision_mask = 0

func _draw() -> void:
	if not _hovered: return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not cs or not cs.shape is RectangleShape2D: return
	var size := (cs.shape as RectangleShape2D).size
	var half := size / 2.0
	var offset := cs.position
	draw_rect(Rect2(offset - half, size), Color(1.0, 1.0, 0.2, 0.15), true)
	draw_rect(Rect2(offset - half, size), Color(1.0, 1.0, 0.2, 1.0), false, hover_border_width)
