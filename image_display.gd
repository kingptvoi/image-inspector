extends Control

@onready var texture = $Sprite2D

var can_drag: bool

func _ready() -> void:
	drag_zone()
	image_load()
	set_screen()
	camera_limits()
	
func _process(delta: float) -> void:
	
	var _delta = delta
	
	if Input.is_action_just_pressed("zoom_in"):
		$Camera2D.zoom.x += 0.05 * $Camera2D.zoom.x
		$Camera2D.zoom.y += 0.05 * $Camera2D.zoom.y
	if Input.is_action_just_pressed("zoom_out"):
		if $Camera2D.zoom.x <= 1:
			pass
		else:
			$Camera2D.zoom.x -= 0.05 * $Camera2D.zoom.x
			$Camera2D.zoom.y -= 0.05 * $Camera2D.zoom.y
	pass
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			can_drag = event.pressed
			
	elif event is InputEventMouseMotion and can_drag:
		$Camera2D.position -= event.relative
	
func image_load():
	var current_image = Global.image
		
	
	var image := Image.new()
	
	if image.load(current_image) == OK:
		texture.texture = ImageTexture.create_from_image(image)
	else:
		print("error loading " + current_image)

func set_screen():
	DisplayServer.window_set_size(Vector2i(DisplayServer.screen_get_size()))

func center_sprite():
	var coordinates = Vector2i(DisplayServer.screen_get_size())
	texture.position = coordinates / 2
	#$CenterContainer.size = Vector2i(DisplayServer.screen_get_size())

func drag_zone():
	$dragZone.size = DisplayServer.screen_get_size()
	$dragZone.position.x = -($dragZone.size.x / 2)
	$dragZone.position.y = -($dragZone.size.y / 2)
	print($dragZone.position)
	
func camera_limits():
	#texture.limit_right = texture.texture.get_width()
	$Camera2D.position.x = texture.position.x / 2
	$Camera2D.position.y = texture.position.y / 2
