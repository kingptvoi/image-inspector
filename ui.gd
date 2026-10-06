extends Control

@onready var tooltipLabel: Label = $SubViewport/CenterContainer/tooltipLabel
@onready var subviewport: SubViewport = $SubViewport

func _process(delta: float) -> void:
	labelPivot()
	resizeViewport()
	
func labelPivot() -> void:
	tooltipLabel.pivot_offset = tooltipLabel.size / 2.0

func resizeViewport() -> void:
	#subviewport.size = DisplayServer.window_get_size()
	print(self.global_position)
	#subviewport.position = Vector2i(DisplayServer.window_get_size() / 2)
