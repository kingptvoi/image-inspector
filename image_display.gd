extends Control

# ---- DEBUG VALUES ----
# cameraPosition: the coordinates of the camera (with the origin in the middle of the screen)
# cameraZoom: the Vector2(x, y) value of the camera displayed with float numbers
# textureSize: the size of the image that is loaded in pixels
# windowSize: the size of the program's window in pixels

#@onready var UserInterface = $UserInterface
@onready var tooltipLabel = $tooltipLabel
@onready var tooltipAnim = $tooltipAnim
@onready var dragZone = $dragZone
@onready var texture = $Sprite2D
@onready var camera = $Camera2D
@onready var UI = $UI

@export var pan_sensitivity: float

var can_drag: bool

var texture_size_global: Vector2i
var texture_scale_global: float

var screen_size: Vector2i
var window_size: Vector2i
var window_position: Vector2i

#var zoom_tween: Tween = Tween.new()

var active_tween


func _ready() -> void:
	
	image_load()
	set_screen()
	#camera_limits()
	#drag_zone()
	
	_debug("windowSize")
	_debug("textureSize")
	_debug("scaledTextureSize")

func _process(_delta: float) -> void:
	
	if Input.is_action_just_pressed("zoom_in"):
		
		if camera.zoom.x < 15.0:
			
			var target_zoom = min(camera.zoom.x * 1.2, 15.0)
				
			active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			active_tween.tween_property(camera, "zoom", Vector2.ONE * target_zoom, 0.2)
			
			_debug("cameraZoom")
			
		else:
			DisplayServer.beep()
			#tooltipText("maxZoomIn")
		
	if Input.is_action_just_pressed("zoom_out"):
		
		if camera.zoom.x > 1:
			
			var target_zoom = max(camera.zoom.x / 1.2, 1.0)
				
			active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			active_tween.tween_property(camera, "zoom", Vector2.ONE * target_zoom, 0.2)
			
			_debug("cameraZoom")
			
		else:
			DisplayServer.beep()
			#tooltipText("maxZoomOut")
			
	camera_limits()
	check_zoom()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			can_drag = event.pressed

	if event is InputEventMouseMotion and can_drag:
		camera.position -= event.relative / camera.zoom
		clamp_camera()
		UI_position()
		
	if event is InputEventPanGesture:
		camera.position += event.delta * DisplayServer.screen_get_scale()
		clamp_camera()
		UI_position()
		
	if event is InputEventMagnifyGesture:
		
		filter_mode()
		
		UI_position()
		
		camera.zoom *= event.factor
		
		_debug("cameraZoom")


func check_zoom() -> void:
	if camera.zoom.x <= 1.0:
		camera.position.x = lerp(camera.position.x, texture.position.x / 2, 0.17)
		camera.position.y = lerp(camera.position.y, texture.position.y / 2, 0.17)
		
	camera.zoom = Vector2.ONE * clamp(camera.zoom.x, 1.0, 15.0)


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


func scale_image() -> void:
	var scale_x = float(window_size.x) / texture_size_global.x
	var scale_y = float(window_size.y) / texture_size_global.y
	
	var scale_factor = min(scale_x, scale_y)
	
	texture_scale_global = scale_factor
	
	texture.scale = Vector2(scale_factor, scale_factor)


func set_screen():
	
	window_position = DisplayServer.window_get_position()
	
	screen_size = DisplayServer.screen_get_size()
	
	DisplayServer.window_set_size(Global.window_size)
	
	window_size = DisplayServer.window_get_size()
	
	#DisplayServer.window_set_position(Vector2i((screen_size - window_size) / 2))
	DisplayServer.window_set_position(Global.window_position)
	
	position_image()


func position_image():
	if texture_size_global.x > window_size.x or texture_size_global.y > window_size.y:
		scale_image()


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


func camera_limits():
	pass


func filter_mode() -> void:
	if camera.zoom.x <= 7.0:
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func UI_position() -> void:
	UI.scale = Vector2(Vector2(1, 1) / camera.zoom)
	UI.position = Vector2.ZERO - Vector2((Vector2(window_size) / camera.zoom) / 2)
	UI.size.x = DisplayServer.window_get_size().x


func tooltipText(value: String) -> void:
	if value == "maxZoomOut":
		tooltipLabel.text = "max zoom-out"
		tooltipAnimation(true)
	elif value == "maxZoomIn":
		tooltipLabel.text = "max zoom-in"
		tooltipAnimation(true)


func tooltipAnimation(value: bool) -> void:
	
	if value:
		tooltipLabel.reset_size()
		tooltipLabel.pivot_offset = tooltipLabel.size / 2
		tooltipLabel.scale = Vector2.ONE / camera.zoom
		tooltipLabel.position.x = camera.position.x - tooltipLabel.size.x / 2.0
		tooltipLabel.position.y = -(window_size.y / camera.zoom.y) / 2
		
		tooltipLabel.visible = true
		tooltipAnim.stop()
		tooltipAnim.play("error")
	else:
		tooltipAnim.stop()
		
		
func _on_resized() -> void:
	
	window_size = DisplayServer.window_get_size()
	window_position = DisplayServer.window_get_position()

func _debug(value: String) -> void:
	if value == "cameraPosition":
		print("Camera position: " + str(camera.position))
	elif value == "cameraZoom":
		print(camera.zoom)
	elif value == "textureSize":
		print("Texture size: ", texture_size_global)
	elif value == "scaledTextureSize":
		print("Displayed texture size: ", texture_size_global * texture_scale_global)
	elif value == "windowSize":
		print("Window size: ", window_size)
	pass
