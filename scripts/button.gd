class_name GameButton

extends Area2D

signal button_pressed(channel: int)
signal button_released(channel: int)

@export var channel: int = 0
## Atlas offset from the "off" tile to its "on/glow" counterpart in the spritesheet.
@export var glow_atlas_offset: Vector2i = Vector2i(0, -2)

@onready var button_anim: AnimationPlayer = $AnimationPlayer

var is_pressed := false
var _wiring_layer: TileMapLayer = null
var _source_ids: Dictionary[Vector2i, int] = {}
var _atlas_coords: Dictionary[Vector2i, Vector2i] = {}
var _alt_tiles: Dictionary[Vector2i, int] = {}

func _ready() -> void:
	add_to_group("buttons")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_find_wiring_layer")

func _find_wiring_layer() -> void:
	var layer_name := "WiringChannel%d" % channel
	var wiring_root := get_tree().current_scene.find_child("Wiring", true, false)
	var search_root: Node = wiring_root if wiring_root else get_tree().current_scene
	_wiring_layer = search_root.find_child(layer_name, true, false) as TileMapLayer
	if not _wiring_layer:
		return
	for cell: Vector2i in _wiring_layer.get_used_cells():
		_source_ids[cell] = _wiring_layer.get_cell_source_id(cell)
		_atlas_coords[cell] = _wiring_layer.get_cell_atlas_coords(cell)
		_alt_tiles[cell] = _wiring_layer.get_cell_alternative_tile(cell)

func _set_wire_state(activate: bool) -> void:
	if not _wiring_layer:
		return
	for cell: Vector2i in _source_ids:
		var base: Vector2i = _atlas_coords[cell]
		var new_atlas: Vector2i = base + glow_atlas_offset if activate else base
		_wiring_layer.set_cell(cell, _source_ids[cell], new_atlas, _alt_tiles[cell])

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		if not is_pressed:
			is_pressed = true
			button_anim.play("press_down")
			_set_wire_state(true)
			button_pressed.emit(channel)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		if get_overlapping_bodies().filter(func(b: Node2D) -> bool: return b.is_in_group("players") and b != body).is_empty():
			is_pressed = false
			button_anim.play_backwards("press_down")
			_set_wire_state(false)
			button_released.emit(channel)
