extends Camera2D
class_name Map

@export var mapCam: Camera2D
@export var bg: Node2D
@export var tilesets: Node2D
@export var wiring: Node2D
@export var interactables: Node2D
@export var hider : Node2D

const CHANNEL_COLORS: Array[Color] = [
	Color(0.2, 0.6, 1.0),   # blue
	Color(1.0, 0.55, 0.1),  # orange
	Color(0.2, 0.85, 0.3),  # green
	Color(0.85, 0.2, 0.85), # purple
	Color(1.0, 0.9, 0.15),  # yellow
	Color(0.9, 0.2, 0.2),   # red
	Color(0.2, 0.9, 0.9),   # cyan
	Color(1.0, 0.4, 0.7),   # pink
	Color(0.5, 0.2, 1.0),   # violet
	Color(0.15, 0.75, 0.55),# teal
	Color(1.0, 0.75, 0.3),  # gold
	Color(0.6, 0.9, 0.2),   # lime
	Color(1.0, 0.3, 0.2),   # coral
	Color(0.3, 0.5, 1.0),   # periwinkle
	Color(0.8, 0.5, 0.2),   # brown
	Color(0.9, 0.9, 0.9),   # white
	Color(0.5, 0.85, 1.0),  # sky
	Color(0.7, 0.2, 0.35),  # crimson
	Color(0.4, 1.0, 0.8),   # mint
	Color(1.0, 0.6, 0.9),   # rose
]

var is_map_open: bool = false
var is_wiring_mode: bool = false
var _is_zoomed: bool = false
var _zoom_areas: Array[ZoomArea] = []
var _wiring_shader: Shader = preload("res://assets/shaders/solid_fill.gdshader")
var _initial_map_zoom: Vector2
var _initial_map_position: Vector2

func _ready() -> void:
	if mapCam:
		_initial_map_zoom = mapCam.zoom
		_initial_map_position = mapCam.position

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggleMap"):
		toggle_map_view()
	#if is_map_open and Input.is_action_just_pressed("toggleWiring"):
		#toggle_wiring_mode()

func _input(event: InputEvent) -> void:
	if not is_map_open: return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _is_zoomed and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_zoom_to_overview()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos := _mouse_to_world()
			for za in _zoom_areas:
				if not is_instance_valid(za): continue
				var rect := _get_za_rect(za)
				if rect.has_point(world_pos):
					_zoom_to_area(rect)
					get_viewport().set_input_as_handled()
					return
	elif event is InputEventMouseMotion:
		var world_pos := _mouse_to_world()
		for za in _zoom_areas:
			if not is_instance_valid(za): continue
			var hovered := _get_za_rect(za).has_point(world_pos)
			if za._hovered != hovered:
				za._hovered = hovered
				za.queue_redraw()

func toggle_map_view() -> void:
	is_map_open = !is_map_open
	if is_map_open:
		mapCam.make_current()
		_collect_zoom_areas()
		toggle_wiring_mode()
	else:
		if is_wiring_mode:
			is_wiring_mode = false
			_apply_wiring_modulates(false)
		if _is_zoomed:
			if mapCam:
				mapCam.zoom = _initial_map_zoom
				mapCam.position = _initial_map_position
			_is_zoomed = false
		for za in _zoom_areas:
			if is_instance_valid(za) and za._hovered:
				za._hovered = false
				za.queue_redraw()
		make_current()

func toggle_wiring_mode() -> void:
	is_wiring_mode = !is_wiring_mode
	_apply_wiring_modulates(is_wiring_mode)

func _apply_wiring_modulates(active: bool) -> void:
	if active:
		if bg: bg.modulate = Color(0.15, 0.15, 0.15)
		if tilesets: tilesets.modulate = Color(0.7, 0.7, 0.7)
		if interactables: interactables.modulate = Color.WHITE
		if wiring:
			wiring.modulate = Color.WHITE
			var idx := 0
			for child in wiring.get_children():
				if child is TileMapLayer:
					var mat := ShaderMaterial.new()
					mat.shader = _wiring_shader
					mat.set_shader_parameter("fill_color", CHANNEL_COLORS[idx % CHANNEL_COLORS.size()])
					(child as TileMapLayer).material = mat
					idx += 1
				
				var nodeChild : Node2D = child
				nodeChild.z_index = 2
		if hider != null: hider.visible = true

	else:
		if bg: bg.modulate = Color.WHITE
		if tilesets: tilesets.modulate = Color.WHITE
		if interactables: interactables.modulate = Color.WHITE
		if wiring:
			wiring.modulate = Color.WHITE
			for child in wiring.get_children():
				if child is TileMapLayer:
					(child as TileMapLayer).material = null
				
				var nodeChild : Node2D = child
				nodeChild.z_index = 0
		
		
		if hider != null: hider.visible = false

func _collect_zoom_areas() -> void:
	_zoom_areas.clear()
	for node in get_tree().get_nodes_in_group("zoom_areas"):
		var za := node as ZoomArea
		if za:
			_zoom_areas.append(za)

func _mouse_to_world() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()

func _get_za_rect(za: ZoomArea) -> Rect2:
	var cs := za.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not cs or not cs.shape is RectangleShape2D: return Rect2()
	var size := (cs.shape as RectangleShape2D).size
	return Rect2(za.to_global(cs.position) - size / 2.0, size)

func _zoom_to_area(rect: Rect2) -> void:
	if not mapCam: return
	var vp_size := get_viewport().get_visible_rect().size
	var zoom_scale: float = min(vp_size.x / rect.size.x, vp_size.y / rect.size.y) * 0.85
	mapCam.zoom = Vector2.ONE * zoom_scale
	mapCam.position = rect.get_center()
	mapCam.reset_physics_interpolation()
	_is_zoomed = true

func _zoom_to_overview() -> void:
	if not mapCam: return
	mapCam.zoom = _initial_map_zoom
	mapCam.position = _initial_map_position
	mapCam.reset_physics_interpolation()
	_is_zoomed = false
