extends Control

# welcome screen controller
# handles file selection, drag and drop, recent files, and scene transition

# node references
@onready var load_dialog: FileDialog = $loadDialog
@onready var open_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OpenButton
@onready var recent_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RecentContainer
@onready var recent_list: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RecentContainer/RecentList

func _ready() -> void:
	# initialize window, dialog, and drag and drop listener
	setup_window()
	setup_dialog()
	get_window().files_dropped.connect(_on_files_dropped)
	open_button.pressed.connect(_on_open_button_pressed)
	setup_recent_files()
	check_command_line_args()

func _unhandled_input(event: InputEvent) -> void:
	# keyboard shortcuts for welcome screen
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.keycode == KEY_O and (event.ctrl_pressed or event.meta_pressed)) or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_open_button_pressed()

func setup_recent_files() -> void:
	# populate recent files list if available
	for child in recent_list.get_children():
		child.queue_free()

	var recents: PackedStringArray = Global.recent_files
	if recents.is_empty():
		recent_container.visible = false
		return

	recent_container.visible = true
	var count: int = 0
	for path in recents:
		if count >= 4:
			break
		if FileAccess.file_exists(path):
			var btn: Button = Button.new()
			btn.text = path.get_file()
			btn.tooltip_text = path
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.flat = true
			btn.pressed.connect(func(): open_image_path(path))
			recent_list.add_child(btn)
			count += 1

	if count == 0:
		recent_container.visible = false

func check_command_line_args() -> void:
	# check for image passed via command line or open with
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		if Global.is_valid_image_path(arg) and FileAccess.file_exists(arg):
			open_image_path(arg)
			return

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in user_args:
		if Global.is_valid_image_path(arg) and FileAccess.file_exists(arg):
			open_image_path(arg)
			return

func _on_files_dropped(files: PackedStringArray) -> void:
	# handle os drag and drop files event
	if files.size() > 0:
		open_image_path(files[0])

func setup_window() -> void:
	# configure window size and position
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	# make window eighty-eight percent of screen size for generous workspace
	var target_w: int = int(screen_size.x * 0.88)
	var target_h: int = int(screen_size.y * 0.88)
	var target_size: Vector2i = Vector2i(target_w, target_h)
	var target_pos: Vector2i = (screen_size - target_size) / 2

	DisplayServer.window_set_size(target_size)
	DisplayServer.window_set_position(target_pos)
	Global.window_size = target_size
	Global.window_position = target_pos

func setup_dialog() -> void:
	# configure supported formats for the file dialog
	load_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.webp, *.svg, *.bmp, *.tga ; Supported Images",
		"*.png ; PNG Images",
		"*.jpg, *.jpeg ; JPEG Images",
		"*.webp ; WebP Images",
		"*.svg ; SVG Images",
		"*.bmp ; BMP Images",
		"*.tga ; Targa Images",
		"*.* ; All Files"
	])
	load_dialog.use_native_dialog = false
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM

func _on_open_button_pressed() -> void:
	# handle open file button pressed
	load_dialog.popup_centered(Vector2i(880, 560))

func _on_load_dialog_file_selected(path: String) -> void:
	# handle path returned from file dialog
	open_image_path(path)

func open_image_path(path: String) -> void:
	# validate path, record history, and switch to inspection scene
	if not Global.is_valid_image_path(path):
		return
	Global.add_recent_file(path)
	Global.image = path
	get_tree().change_scene_to_file("res://imageDisplay.tscn")

func _on_resized() -> void:
	# record window dimensions on resize without per frame polling
	Global.window_size = DisplayServer.window_get_size()
	Global.window_position = DisplayServer.window_get_position()
