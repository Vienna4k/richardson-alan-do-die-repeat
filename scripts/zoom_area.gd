extends Area2D
class_name ZoomArea

signal area_clicked(rect: Rect2)

@export var hover_border_width: float = 8.0

var _hovered := false

func _ready() -> void:
	add_to_group("zoom_areas")
	collision_layer = 0
	collision_mask = 0
	input_pickable = false
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton: return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			var size := (cs.shape as RectangleShape2D).size
			area_clicked.emit(Rect2(to_global(cs.position) - size / 2.0, size))
			get_viewport().set_input_as_handled()

func _draw() -> void:
	if not _hovered: return
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not cs or not cs.shape is RectangleShape2D: return
	var size := (cs.shape as RectangleShape2D).size
	var half := size / 2.0
	var offset := cs.position
	draw_rect(Rect2(offset - half, size), Color(1.0, 1.0, 0.2, 0.15), true)
	draw_rect(Rect2(offset - half, size), Color(1.0, 1.0, 0.2, 1.0), false, hover_border_width)
