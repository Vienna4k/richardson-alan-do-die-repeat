class_name GameManager
extends Node

@export var max_deaths: int = 3
var current_deaths: int

# Drag and drop your UI nodes into these slots in the inspector!
@export var death_label: Label
@export var game_over_screen: Control
@export var restart_button: Button

func _ready() -> void:
	current_deaths = max_deaths
	
	# Ensure the game over screen is hidden when the level starts
	if game_over_screen:
		game_over_screen.hide()
		
	update_ui()
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func register_death() -> void:
	current_deaths -= 1
	update_ui()
	
	if current_deaths <= 0:
		_trigger_game_over()

func update_ui() -> void:
	if death_label:
		death_label.text = str(current_deaths)

func _trigger_game_over() -> void:
	if game_over_screen:
		game_over_screen.show()
	
	# Optional: Pause the background game physics so dead bodies stop falling
	get_tree().paused = true

func _on_restart_pressed() -> void:
	# Unpause the game before reloading, otherwise the next level starts frozen!
	get_tree().paused = false
	get_tree().reload_current_scene()