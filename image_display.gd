extends Control

@onready var dragZone = $dragZone
@onready var texture = $Sprite2D
@onready var camera = $Camera2D

@export var pan_sensitivity: float

var can_drag: bool

var texture_size_global: Vector2i
var texture_scale_global: float

var screen_size: Vector2i
var window_size: Vector2i


func _ready() -> void:
	image_load()
	set_screen()
	#camera_limits()
	#drag_zone()


func _process(_delta: float) -> void:
	
	if Input.is_action_just_pressed("zoom_in"):
		camera.zoom *= 1.05
		
	if Input.is_action_just_pressed("zoom_out"):
		if camera.zoom.x > 1:
			camera.zoom *= 0.95
			
	check_zoom()
	drag_zone()
	camera_limits()
	
	#print("Camera position: " + str(camera.position))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			can_drag = event.pressed

	if event is InputEventMouseMotion and can_drag:
		camera.position -= event.relative / camera.zoom
		clamp_camera()
		
	if event is InputEventPanGesture:
		camera.position += event.delta * DisplayServer.screen_get_scale()
		clamp_camera()
		
	if event is InputEventMagnifyGesture:
		
		print(camera.zoom)
		
		filter_mode()
		
		camera.zoom *= event.factor
		camera.zoom.x = clamp(camera.zoom.x, 1.0, 15.0)
		camera.zoom.y = clamp(camera.zoom.y, 1.0, 15.0)
		
func check_zoom() -> void:
	if camera.zoom.x <= 1.0 or camera.zoom.y <= 1.0:
		camera.position.x = lerp(camera.position.x, texture.position.x / 2, 0.17)
		camera.position.y = lerp(camera.position.y, texture.position.y / 2, 0.17)
		
func image_load():
	var current_image = Global.image
	
	var image: Image = Image.new()
	
	if image.load(current_image) == OK:
		texture.texture = ImageTexture.create_from_image(image)
	else:
		print("error loading " + current_image)
	
	image_scale_check()


func image_scale_check() -> Vector2i:
	var texture_size: Vector2i = texture.texture.get_size()
	texture_size_global = texture_size
	return texture_size


func position_image():
	if texture_size_global.x > window_size.x or texture_size_global.y > window_size.y:
		scale_image()


func scale_image() -> void:
	var scale_x = float(window_size.x) / texture_size_global.x
	var scale_y = float(window_size.y) / texture_size_global.y
	
	var scale_factor = min(scale_x, scale_y)
	
	texture_scale_global = scale_factor
	
	texture.scale = Vector2(scale_factor, scale_factor)


func set_screen():
	screen_size = DisplayServer.screen_get_size()
	
	DisplayServer.window_set_size(Global.window_size)
	
	window_size = DisplayServer.window_get_size()
	
	DisplayServer.window_set_position(
		Vector2i((screen_size - window_size) / 2)
	)
	
	print("Texture size: ", texture_size_global)
	print("Window size: ", window_size)
	
	position_image()


func clamp_camera() -> void:
	var image_size = Vector2(texture.texture.get_size()) * texture.scale
	var viewport_size = Vector2(window_size) / camera.zoom

	var max_x = max(0.0, (image_size.x - viewport_size.x) / 2.0)
	var max_y = max(0.0, (image_size.y - viewport_size.y) / 2.0)

	camera.position.x = clamp(camera.position.x, -max_x, max_x)

	camera.position.y = clamp(camera.position.y, -max_y, max_y)

func center_sprite():
	var coordinates = DisplayServer.screen_get_size()
	texture.position = coordinates / 2


func drag_zone():
	dragZone.size = texture_size_global * texture_scale_global
	dragZone.position.x = -(dragZone.size.x / 2)
	dragZone.position.y = -(dragZone.size.y / 2)


func camera_limits():
	pass

func filter_mode() -> void:
	if camera.zoom.x <= 7.0:
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
