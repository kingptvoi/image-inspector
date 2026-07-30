extends Control

@onready var loadDialog = $loadDialog

func _ready() -> void:
	set_screen()

func _button_pressed(value: String):
	if value == "load":
		loadDialog.visible = true

func _on_load_dialog_file_selected(path: String) -> void:
	Global.image = path
	get_tree().change_scene_to_file("res://imageDisplay.tscn")

func set_screen():
	DisplayServer.window_set_size(Vector2i(DisplayServer.screen_get_size() / 2))
	DisplayServer.window_set_position(Vector2i(DisplayServer.screen_get_size() / 4))
