extends Camera2D

@export var mapCam: Camera2D
@export var bg: Node2D
@export var tilesets: Node2D
@export var wiring: Node2D
@export var interactables: Node2D

const CHANNEL_COLORS: Array[Color] = [
	Color(0.2, 0.6, 1.0),   # blue
	Color(1.0, 0.55, 0.1),  # orange
	Color(0.2, 0.85, 0.3),  # green
	Color(0.85, 0.2, 0.85), # purple
	Color(1.0, 0.9, 0.15),  # yellow
	Color(0.9, 0.2, 0.2),   # red
	Color(0.2, 0.9, 0.9),   # cyan
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
	if is_map_open and Input.is_action_just_pressed("toggleWiring"):
		toggle_wiring_mode()

func _input(event: InputEvent) -> void:
	if not is_map_open or not _is_zoomed: return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_zoom_to_overview()

func toggle_map_view() -> void:
	is_map_open = !is_map_open
	if is_map_open:
		mapCam.make_current()
		_collect_zoom_areas()
		_set_zoom_areas_pickable(true)
	else:
		if is_wiring_mode:
			is_wiring_mode = false
			_apply_wiring_modulates(false)
		if _is_zoomed:
			if mapCam:
				mapCam.zoom = _initial_map_zoom
				mapCam.position = _initial_map_position
			_is_zoomed = false
		_set_zoom_areas_pickable(false)
		make_current()

func toggle_wiring_mode() -> void:
	is_wiring_mode = !is_wiring_mode
	_apply_wiring_modulates(is_wiring_mode)

func _apply_wiring_modulates(active: bool) -> void:
	if active:
		if bg: bg.modulate = Color(0.15, 0.15, 0.15)
		if tilesets: tilesets.modulate = Color(0.04, 0.04, 0.04)
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
	else:
		if bg: bg.modulate = Color.WHITE
		if tilesets: tilesets.modulate = Color.WHITE
		if interactables: interactables.modulate = Color.WHITE
		if wiring:
			wiring.modulate = Color.WHITE
			for child in wiring.get_children():
				if child is TileMapLayer:
					(child as TileMapLayer).material = null

func _collect_zoom_areas() -> void:
	_zoom_areas.clear()
	for node in get_tree().get_nodes_in_group("zoom_areas"):
		var za := node as ZoomArea
		if za and not za.area_clicked.is_connected(_on_area_clicked):
			za.area_clicked.connect(_on_area_clicked)
			_zoom_areas.append(za)

func _set_zoom_areas_pickable(enabled: bool) -> void:
	for za in _zoom_areas:
		if is_instance_valid(za):
			za.input_pickable = enabled

func _on_area_clicked(rect: Rect2) -> void:
	if not mapCam: return
	var vp_size := get_viewport().get_visible_rect().size
	var zoom_scale: float = min(vp_size.x / rect.size.x, vp_size.y / rect.size.y) * 0.85
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mapCam, "zoom", Vector2.ONE * zoom_scale, 0.35)
	tween.parallel().tween_property(mapCam, "position", rect.get_center(), 0.35)
	_is_zoomed = true

func _zoom_to_overview() -> void:
	if not mapCam: return
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mapCam, "zoom", _initial_map_zoom, 0.35)
	tween.parallel().tween_property(mapCam, "position", _initial_map_position, 0.35)
	_is_zoomed = false
