extends Node

## Zoom level for the full map view — tune until the whole level fits.
@export var fullmap_zoom: Vector2 = Vector2(0.16, 0.16)

@onready var minimap_camera: Camera2D = $SubViewport/MinimapCamera

var _map_overlay: Control = null
var _is_open := false
var _level_center := Vector2.ZERO

func _ready() -> void:
	($SubViewport as SubViewport).world_2d = get_viewport().world_2d
	call_deferred("_find_nodes")

func _find_nodes() -> void:
	_map_overlay = get_tree().current_scene.get_node("UIManager/MapOverlay") as Control
	_level_center = Vector2(
		(minimap_camera.limit_left + minimap_camera.limit_right) / 2.0,
		(minimap_camera.limit_top + minimap_camera.limit_bottom) / 2.0
	)
	minimap_camera.zoom = fullmap_zoom
	minimap_camera.position = _level_center
	if _map_overlay:
		_map_overlay.hide()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggleMap"):
		_is_open = not _is_open
		if _map_overlay:
			_map_overlay.visible = _is_open
