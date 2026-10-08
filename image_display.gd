extends Control

# image inspector controller
# manages viewport, camera transformations, pixel inspection, diagnostic shaders, and ui overlays

# node references
@onready var image_sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: CanvasLayer = $UILayer
@onready var hud: Control = $UILayer/HUD
@onready var top_bar: PanelContainer = $UILayer/HUD/TopBar
@onready var bottom_bar: PanelContainer = $UILayer/HUD/BottomBar
@onready var file_info_label: Label = $UILayer/HUD/TopBar/Margin/HBox/FileInfoLabel
@onready var prev_button: Button = $UILayer/HUD/TopBar/Margin/HBox/PrevButton
@onready var next_button: Button = $UILayer/HUD/TopBar/Margin/HBox/NextButton
@onready var channel_button: Button = $UILayer/HUD/TopBar/Margin/HBox/ChannelButton
@onready var grid_button: Button = $UILayer/HUD/TopBar/Margin/HBox/GridButton
@onready var checker_button: Button = $UILayer/HUD/TopBar/Margin/HBox/CheckerButton
@onready var filter_button: Button = $UILayer/HUD/TopBar/Margin/HBox/FilterButton
@onready var zoom_label: Label = $UILayer/HUD/BottomBar/Margin/HBox/ZoomLabel
@onready var pixel_coords_label: Label = $UILayer/HUD/BottomBar/Margin/HBox/PixelCoordsLabel
@onready var pixel_color_label: Label = $UILayer/HUD/BottomBar/Margin/HBox/PixelColorLabel
@onready var color_swatch: ColorRect = $UILayer/HUD/BottomBar/Margin/HBox/ColorSwatch
@onready var copy_color_button: Button = $UILayer/HUD/BottomBar/Margin/HBox/CopyColorButton
@onready var tooltip_label: Label = $UILayer/HUD/TooltipLabel
@onready var tooltip_anim: AnimationPlayer = $UILayer/HUD/TooltipAnim
@onready var open_file_dialog: FileDialog = $UILayer/OpenFileDialog
@onready var error_dialog: AcceptDialog = $UILayer/ErrorDialog
@onready var metadata_dialog: AcceptDialog = $UILayer/MetadataDialog
@onready var help_dialog: AcceptDialog = $UILayer/HelpDialog

# camera configuration
@export var min_zoom: float = 0.02
@export var max_zoom: float = 128.0
@export var pan_sensitivity: float = 1.0

# drag state tracking
var is_dragging: bool = false

# texture and raw image data cache
var current_image: Image = null
var current_texture: ImageTexture = null
var texture_size: Vector2i = Vector2i.ZERO
var base_scale: float = 1.0

# window geometry
var window_size: Vector2i = Vector2i.ZERO

# active tween reference
var zoom_tween: Tween = null

# filter mode: 0 = auto, 1 = nearest, 2 = linear
var filter_mode_index: int = 0
const FILTER_MODE_NAMES: Array[String] = ["Filter: Auto", "Filter: Nearest", "Filter: Linear"]

# channel modes: 0 = rgb, 1 = red, 2 = green, 3 = blue, 4 = alpha, 5 = invert, 6 = grayscale
var channel_mode_index: int = 0
const CHANNEL_MODE_NAMES: Array[String] = [
	"Mode: RGB",
	"Mode: Red",
	"Mode: Green",
	"Mode: Blue",
	"Mode: Alpha",
	"Mode: Invert",
	"Mode: Grayscale"
]

# grid and checkerboard states
var is_pixel_grid_enabled: bool = false
var is_checkerboard_enabled: bool = true

# directory browsing state
var directory_images: PackedStringArray = []
var current_directory_index: int = -1

# currently inspected color and coordinate
var current_inspected_color: Color = Color.TRANSPARENT
var current_inspected_pixel: Vector2i = Vector2i(-1, -1)
var is_hovering_image: bool = false

func _ready() -> void:
	# initialize window dimensions, drag and drop listener, and load initial image
	window_size = DisplayServer.window_get_size()
	get_window().files_dropped.connect(_on_files_dropped)
	setup_file_dialog()
	setup_help_dialog_text()
	load_image_from_path(Global.current_image_path)

func setup_file_dialog() -> void:
	# configure open file dialog properties
	open_file_dialog.use_native_dialog = false
	open_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_file_dialog.access = FileDialog.ACCESS_FILESYSTEM

func _on_files_dropped(files: PackedStringArray) -> void:
	# handle os drag and drop files event directly inside inspector
	if files.size() > 0:
		load_image_from_path(files[0])

func _process(_delta: float) -> void:
	# update pixel coordinate and color inspector under mouse cursor
	update_pixel_inspector()

func _input(event: InputEvent) -> void:
	# handle drag start and end for mouse buttons
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_step(1.2, get_viewport().get_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_step(1.0 / 1.2, get_viewport().get_mouse_position())

	# handle panning during mouse motion
	if event is InputEventMouseMotion and is_dragging:
		camera.position -= event.relative / camera.zoom
		clamp_camera()

	# handle trackpad two finger pan gesture
	if event is InputEventPanGesture:
		camera.position += event.delta * (30.0 / camera.zoom.x)
		clamp_camera()

	# handle trackpad pinch to zoom gesture
	if event is InputEventMagnifyGesture:
		var target_zoom: float = clamp(camera.zoom.x * event.factor, min_zoom, max_zoom)
		set_camera_zoom_immediate(target_zoom, get_viewport().get_mouse_position())

	# handle keyboard shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		var pan_step: float = 60.0 / camera.zoom.x

		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			zoom_step(1.2, get_viewport().get_mouse_position())
		elif event.keycode == KEY_MINUS:
			zoom_step(1.0 / 1.2, get_viewport().get_mouse_position())
		elif event.keycode == KEY_0:
			fit_to_window()
		elif event.keycode == KEY_1:
			set_actual_size()
		elif event.keycode == KEY_2:
			set_zoom_multiplier(2.0)
		elif event.keycode == KEY_4:
			set_zoom_multiplier(4.0)
		elif event.keycode == KEY_LEFT or event.keycode == KEY_BRACKETLEFT:
			show_prev_image()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_BRACKETRIGHT:
			show_next_image()
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			camera.position.y -= pan_step
			clamp_camera()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			camera.position.y += pan_step
			clamp_camera()
		elif event.keycode == KEY_A and not event.ctrl_pressed and not event.meta_pressed:
			camera.position.x -= pan_step
			clamp_camera()
		elif event.keycode == KEY_D and not event.ctrl_pressed and not event.meta_pressed:
			camera.position.x += pan_step
			clamp_camera()
		elif event.keycode == KEY_G:
			toggle_pixel_grid()
		elif event.keycode == KEY_B:
			toggle_checkerboard()
		elif event.keycode == KEY_TAB:
			cycle_channel_mode()
		elif event.keycode == KEY_C:
			copy_inspected_color_to_clipboard()
		elif event.keycode == KEY_I:
			show_metadata_dialog()
		elif event.keycode == KEY_F1 or event.keycode == KEY_QUESTION:
			show_help_dialog()
		elif event.keycode == KEY_F11 or (event.keycode == KEY_F and (event.ctrl_pressed or event.meta_pressed)):
			toggle_fullscreen()
		elif event.keycode == KEY_H:
			toggle_hud_visibility()
		elif event.keycode == KEY_R and (event.ctrl_pressed or event.meta_pressed):
			reload_current_image()
		elif event.keycode == KEY_O and (event.ctrl_pressed or event.meta_pressed):
			open_file_dialog.popup_centered(Vector2i(880, 560))

# load image safely from file path and update display
func load_image_from_path(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		show_error("File does not exist: " + path)
		return false

	var img: Image = Image.new()
	var err: Error = img.load(path)
	if err != OK:
		show_error("Failed to load image file (error code %d): %s" % [err, path])
		return false

	current_image = img
	current_texture = ImageTexture.create_from_image(current_image)
	image_sprite.texture = current_texture
	texture_size = current_texture.get_size()
	Global.current_image_path = path
	Global.add_recent_file(path)

	scan_parent_directory(path)
	update_file_info_label(path)
	fit_to_window()
	return true

# scan parent folder for directory browsing
func scan_parent_directory(current_path: String) -> void:
	directory_images.clear()
	current_directory_index = -1

	var dir_path: String = current_path.get_base_dir()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		update_nav_buttons()
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var files: Array[String] = []

	while not file_name.is_empty():
		if not dir.current_is_dir() and Global.is_valid_image_path(file_name):
			files.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()
	directory_images = PackedStringArray(files)

	for i in range(directory_images.size()):
		if directory_images[i] == current_path:
			current_directory_index = i
			break

	update_nav_buttons()

# update navigation buttons enabled status
func update_nav_buttons() -> void:
	var total: int = directory_images.size()
	prev_button.disabled = (current_directory_index <= 0 or total <= 1)
	next_button.disabled = (current_directory_index >= total - 1 or total <= 1)

# show previous image in current directory
func show_prev_image() -> void:
	if current_directory_index > 0:
		load_image_from_path(directory_images[current_directory_index - 1])

# show next image in current directory
func show_next_image() -> void:
	if current_directory_index >= 0 and current_directory_index < directory_images.size() - 1:
		load_image_from_path(directory_images[current_directory_index + 1])

# display filename, index, and image resolution in top bar
func update_file_info_label(path: String) -> void:
	var filename: String = path.get_file()
	var total: int = directory_images.size()
	if total > 0 and current_directory_index >= 0:
		file_info_label.text = "[%d/%d] %s (%d x %d)" % [
			current_directory_index + 1,
			total,
			filename,
			texture_size.x,
			texture_size.y
		]
	else:
		file_info_label.text = "%s (%d x %d)" % [filename, texture_size.x, texture_size.y]

# fit image to window bounds and center camera
func fit_to_window() -> void:
	if texture_size == Vector2i.ZERO:
		return

	window_size = DisplayServer.window_get_size()
	var scale_x: float = float(window_size.x) / float(texture_size.x)
	var scale_y: float = float(window_size.y) / float(texture_size.y)
	base_scale = min(scale_x, scale_y)

	image_sprite.scale = Vector2(base_scale, base_scale)
	image_sprite.position = Vector2.ZERO

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	camera.zoom = Vector2.ONE
	camera.position = Vector2.ZERO
	update_shader_zoom()
	update_filter_mode()
	update_zoom_label()

# reset zoom to one to one pixel scale
func set_actual_size() -> void:
	if texture_size == Vector2i.ZERO:
		return

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	image_sprite.scale = Vector2.ONE
	camera.zoom = Vector2.ONE
	camera.position = Vector2.ZERO
	update_shader_zoom()
	update_filter_mode()
	update_zoom_label()

# set zoom to a specific multiple
func set_zoom_multiplier(multiplier: float) -> void:
	if texture_size == Vector2i.ZERO:
		return

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	image_sprite.scale = Vector2.ONE
	camera.zoom = Vector2.ONE * multiplier
	camera.position = Vector2.ZERO
	update_shader_zoom()
	update_filter_mode()
	update_zoom_label()

# zoom step with cursor centering calculation
func zoom_step(factor: float, mouse_screen_pos: Vector2) -> void:
	var current_z: float = camera.zoom.x
	var target_z: float = clamp(current_z * factor, min_zoom, max_zoom)

	if is_equal_approx(target_z, current_z):
		if factor > 1.0:
			show_tooltip("max zoom-in")
		else:
			show_tooltip("max zoom-out")
		DisplayServer.beep()
		return

	# calculate camera shift to zoom into cursor position
	var viewport_center: Vector2 = Vector2(window_size) / 2.0
	var screen_offset: Vector2 = mouse_screen_pos - viewport_center
	var target_camera_pos: Vector2 = camera.position + screen_offset * (1.0 / current_z - 1.0 / target_z)

	if zoom_tween and zoom_tween.is_valid():
		zoom_tween.kill()

	zoom_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	zoom_tween.tween_property(camera, "zoom", Vector2.ONE * target_z, 0.18)
	zoom_tween.tween_property(camera, "position", target_camera_pos, 0.18)
	zoom_tween.chain().tween_callback(func():
		clamp_camera()
		update_shader_zoom()
		update_filter_mode()
		update_zoom_label()
	)

# set zoom immediately for smooth gestures without tweening
func set_camera_zoom_immediate(target_z: float, mouse_screen_pos: Vector2) -> void:
	var current_z: float = camera.zoom.x
	var viewport_center: Vector2 = Vector2(window_size) / 2.0
	var screen_offset: Vector2 = mouse_screen_pos - viewport_center
	camera.position += screen_offset * (1.0 / current_z - 1.0 / target_z)
	camera.zoom = Vector2.ONE * target_z
	clamp_camera()
	update_shader_zoom()
	update_filter_mode()
	update_zoom_label()

# update shader zoom uniform for pixel grid calculations
func update_shader_zoom() -> void:
	var mat: ShaderMaterial = image_sprite.material as ShaderMaterial
	if mat:
		var effective_zoom: float = camera.zoom.x * image_sprite.scale.x
		mat.set_shader_parameter("current_zoom", effective_zoom)

# update texture filter mode based on zoom or user selection
func update_filter_mode() -> void:
	if filter_mode_index == 1:
		image_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	elif filter_mode_index == 2:
		image_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		# auto mode: use nearest when magnified beyond four times scale
		var effective_scale: float = camera.zoom.x * image_sprite.scale.x
		if effective_scale >= 4.0:
			image_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		else:
			image_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# update zoom percentage label in bottom bar
func update_zoom_label() -> void:
	var effective_zoom: float = camera.zoom.x * image_sprite.scale.x * 100.0
	zoom_label.text = "Zoom: %d%%" % int(effective_zoom)

# clamp camera position to avoid losing image outside viewport
func clamp_camera() -> void:
	if texture_size == Vector2i.ZERO:
		return

	var rendered_size: Vector2 = Vector2(texture_size) * image_sprite.scale
	var viewport_in_world: Vector2 = Vector2(window_size) / camera.zoom

	var max_x: float = max(0.0, (rendered_size.x - viewport_in_world.x) / 2.0)
	var max_y: float = max(0.0, (rendered_size.y - viewport_in_world.y) / 2.0)

	camera.position.x = clamp(camera.position.x, -max_x, max_x)
	camera.position.y = clamp(camera.position.y, -max_y, max_y)

# inspect pixel coordinate and color under cursor
func update_pixel_inspector() -> void:
	if current_image == null or texture_size == Vector2i.ZERO:
		return

	# calculate pixel coordinates relative to top left of image
	var mouse_world: Vector2 = camera.get_global_mouse_position()
	var half_size: Vector2 = (Vector2(texture_size) * image_sprite.scale) / 2.0
	var top_left_world: Vector2 = image_sprite.position - half_size
	var relative_pos: Vector2 = (mouse_world - top_left_world) / image_sprite.scale
	var pixel_coord: Vector2i = Vector2i(relative_pos.floor())

	if pixel_coord.x >= 0 and pixel_coord.x < texture_size.x and pixel_coord.y >= 0 and pixel_coord.y < texture_size.y:
		is_hovering_image = true
		current_inspected_pixel = pixel_coord
		current_inspected_color = current_image.get_pixelv(pixel_coord)

		pixel_coords_label.text = "X: %d  Y: %d" % [pixel_coord.x, pixel_coord.y]
		pixel_color_label.text = "RGBA: (%d, %d, %d, %d)  Hex: #%s" % [
			int(current_inspected_color.r * 255.0),
			int(current_inspected_color.g * 255.0),
			int(current_inspected_color.b * 255.0),
			int(current_inspected_color.a * 255.0),
			current_inspected_color.to_html(true)
		]
		color_swatch.color = current_inspected_color
		copy_color_button.disabled = false
	else:
		is_hovering_image = false
		pixel_coords_label.text = "X: -  Y: -"
		pixel_color_label.text = "RGBA: -  Hex: -"
		color_swatch.color = Color(0, 0, 0, 0)
		copy_color_button.disabled = true

# copy current inspected hex color to system clipboard
func copy_inspected_color_to_clipboard() -> void:
	if is_hovering_image:
		var hex_code: String = "#" + current_inspected_color.to_html(true)
		DisplayServer.clipboard_set(hex_code)
		show_tooltip("copied " + hex_code + " to clipboard")

# cycle through channel isolation and diagnostic shader modes
func cycle_channel_mode() -> void:
	channel_mode_index = (channel_mode_index + 1) % CHANNEL_MODE_NAMES.size()
	channel_button.text = CHANNEL_MODE_NAMES[channel_mode_index]
	var mat: ShaderMaterial = image_sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("channel_mode", channel_mode_index)
	show_tooltip(CHANNEL_MODE_NAMES[channel_mode_index].to_lower())

# toggle pixel grid overlay
func toggle_pixel_grid() -> void:
	is_pixel_grid_enabled = not is_pixel_grid_enabled
	grid_button.text = "Grid: On" if is_pixel_grid_enabled else "Grid: Off"
	var mat: ShaderMaterial = image_sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("show_pixel_grid", is_pixel_grid_enabled)
	show_tooltip("pixel grid enabled" if is_pixel_grid_enabled else "pixel grid disabled")

# toggle transparency checkerboard backdrop
func toggle_checkerboard() -> void:
	is_checkerboard_enabled = not is_checkerboard_enabled
	checker_button.text = "Checker: On" if is_checkerboard_enabled else "Checker: Off"
	var mat: ShaderMaterial = image_sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("show_checkerboard", is_checkerboard_enabled)
	show_tooltip("checkerboard enabled" if is_checkerboard_enabled else "checkerboard disabled")

# toggle fullscreen window mode
func toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		show_tooltip("windowed mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		show_tooltip("fullscreen mode")

# toggle hud visibility for unobstructed view
func toggle_hud_visibility() -> void:
	hud.visible = not hud.visible
	if hud.visible:
		show_tooltip("hud restored")

# show image metadata dialog
func show_metadata_dialog() -> void:
	if current_image == null:
		return

	var path: String = Global.current_image_path
	var file_size_bytes: int = 0
	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file:
			file_size_bytes = file.get_length()

	var megapixels: float = float(texture_size.x * texture_size.y) / 1000000.0
	var aspect_str: String = calculate_aspect_ratio(texture_size.x, texture_size.y)
	var format_str: String = get_format_name(current_image.get_format())
	var vram_estimate_bytes: int = texture_size.x * texture_size.y * 4

	var info_text: String = (
		"File: %s\n" +
		"Path: %s\n\n" +
		"Dimensions: %d x %d px\n" +
		"Aspect Ratio: %s\n" +
		"Megapixels: %.2f MP\n\n" +
		"File Size: %s\n" +
		"Format: %s\n" +
		"VRAM Estimate: %s"
	) % [
		path.get_file(),
		path,
		texture_size.x,
		texture_size.y,
		aspect_str,
		megapixels,
		format_bytes(file_size_bytes),
		format_str,
		format_bytes(vram_estimate_bytes)
	]

	metadata_dialog.dialog_text = info_text
	metadata_dialog.popup_centered()

# configure keyboard shortcuts cheatsheet text
func setup_help_dialog_text() -> void:
	help_dialog.dialog_text = (
		"Keyboard & Mouse Shortcuts:\n\n" +
		"- Zoom In / Out: Mouse Wheel Up / Down, +, -\n" +
		"- Fit to Window: 0\n" +
		"- Actual Size (1:1): 1\n" +
		"- Preset Zoom: 2 (200%), 4 (400%)\n" +
		"- Pan: Left Drag, Middle Drag, Trackpad Pan, WASD / Arrows\n" +
		"- Previous / Next Image: Left Arrow / Right Arrow, [, ]\n" +
		"- Cycle Channels / Modes: Tab\n" +
		"- Toggle Pixel Grid: G\n" +
		"- Toggle Checkerboard: B\n" +
		"- Copy Inspected Color: C\n" +
		"- Image Metadata: I\n" +
		"- Toggle Fullscreen: F11 / Cmd+F\n" +
		"- Toggle HUD (Zen Mode): H\n" +
		"- Reload Image: Ctrl+R / Cmd+R\n" +
		"- Open File Dialog: Ctrl+O / Cmd+O\n" +
		"- Help Cheatsheet: F1 / ?"
	)

# show keyboard shortcuts cheatsheet dialog
func show_help_dialog() -> void:
	help_dialog.popup_centered()

# format bytes to human readable string
func format_bytes(bytes: int) -> String:
	if bytes <= 0:
		return "0 B"
	elif bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1048576:
		return "%.2f KB" % (float(bytes) / 1024.0)
	else:
		return "%.2f MB" % (float(bytes) / 1048576.0)

# calculate aspect ratio string
func calculate_aspect_ratio(w: int, h: int) -> String:
	if w <= 0 or h <= 0:
		return "unknown"
	var a: int = w
	var b: int = h
	while b != 0:
		var t: int = b
		b = a % b
		a = t
	var gcd_val: int = a
	var rw: int = w / gcd_val
	var rh: int = h / gcd_val
	return "%d:%d (%.2f:1)" % [rw, rh, float(w) / float(h)]

# get readable string name for godot image format enum
func get_format_name(format_enum: int) -> String:
	match format_enum:
		Image.FORMAT_L8: return "L8 (Grayscale)"
		Image.FORMAT_LA8: return "LA8 (Grayscale + Alpha)"
		Image.FORMAT_R8: return "R8"
		Image.FORMAT_RG8: return "RG8"
		Image.FORMAT_RGB8: return "RGB8 (24-bit)"
		Image.FORMAT_RGBA8: return "RGBA8 (32-bit)"
		Image.FORMAT_RF: return "RF (32-bit Float)"
		Image.FORMAT_RGBF: return "RGBF (96-bit Float)"
		Image.FORMAT_RGBAF: return "RGBAF (128-bit Float)"
		_: return "Format ID %d" % format_enum

# show center banner notification with animation
func show_tooltip(message: String) -> void:
	tooltip_label.text = message
	tooltip_anim.stop()
	tooltip_anim.play("error")

# show error dialog
func show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered()

# reload current image from disk
func reload_current_image() -> void:
	if not Global.current_image_path.is_empty():
		load_image_from_path(Global.current_image_path)
		show_tooltip("reloaded image")

# handle window resizing
func _on_resized() -> void:
	window_size = DisplayServer.window_get_size()
	Global.window_size = window_size
	Global.window_position = DisplayServer.window_get_position()
	clamp_camera()

# button signal handlers
func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://app.tscn")

func _on_open_button_pressed() -> void:
	open_file_dialog.popup_centered(Vector2i(880, 560))

func _on_reload_button_pressed() -> void:
	reload_current_image()

func _on_prev_button_pressed() -> void:
	show_prev_image()

func _on_next_button_pressed() -> void:
	show_next_image()

func _on_channel_button_pressed() -> void:
	cycle_channel_mode()

func _on_grid_button_pressed() -> void:
	toggle_pixel_grid()

func _on_checker_button_pressed() -> void:
	toggle_checkerboard()

func _on_filter_button_pressed() -> void:
	filter_mode_index = (filter_mode_index + 1) % 3
	filter_button.text = FILTER_MODE_NAMES[filter_mode_index]
	update_filter_mode()

func _on_info_button_pressed() -> void:
	show_metadata_dialog()

func _on_help_button_pressed() -> void:
	show_help_dialog()

func _on_fit_button_pressed() -> void:
	fit_to_window()

func _on_actual_button_pressed() -> void:
	set_actual_size()

func _on_copy_color_button_pressed() -> void:
	copy_inspected_color_to_clipboard()

func _on_file_dialog_file_selected(path: String) -> void:
	load_image_from_path(path)
