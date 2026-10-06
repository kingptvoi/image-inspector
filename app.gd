extends Control

@onready var centerButton = $CenterContainer/Button
@onready var loadDialog = $loadDialog

var last_window_position

func _ready() -> void:
	set_screen()
	expand_button()
	
	last_window_position = Vector2i.ZERO
	
func _process(_delta: float) -> void:
	expand_button()
	
	check_window_move()

func _button_pressed(value: String):
	if value == "load":
		loadDialog.visible = true

func _on_load_dialog_file_selected(path: String) -> void:
	Global.image = path
	get_tree().change_scene_to_file("res://imageDisplay.tscn")

func set_screen():
	
	DisplayServer.window_set_size(Vector2i(DisplayServer.screen_get_size() / 1.25))
	DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_size() / 10))

func expand_button() -> void:
	centerButton.custom_minimum_size = Vector2(DisplayServer.window_get_size())

func _on_resized() -> void:
	
	var window_position: Vector2i
	var window_size: Vector2i
	window_size = DisplayServer.window_get_size()
	window_position = DisplayServer.window_get_position()
	Global.window_size = window_size
	Global.window_position = window_position

func check_window_move() -> void:
	var current_window_position = DisplayServer.window_get_position()
	
	if current_window_position != last_window_position:
		last_window_position = current_window_position
		Global.window_position = DisplayServer.window_get_position()
