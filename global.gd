extends Node

# global singleton for state management across scenes

signal image_selected(path: String)
signal window_resized(new_size: Vector2i)

# current path of the loaded image file
var current_image_path: String = ""

# backward compatibility property for existing references
var image: String:
	get:
		return current_image_path
	set(value):
		current_image_path = value

# window geometry cache
var window_size: Vector2i = Vector2i.ZERO
var window_position: Vector2i = Vector2i.ZERO

# supported image file extensions
const SUPPORTED_EXTENSIONS: PackedStringArray = [
	"png",
	"jpg",
	"jpeg",
	"webp",
	"svg",
	"bmp",
	"tga"
]

# persistent storage path for recent files history
const RECENT_FILES_PATH: String = "user://recent_files.json"
var recent_files: PackedStringArray = []

func _ready() -> void:
	# load recent history on engine startup
	load_recent_files()

# check if given path has a supported image extension
func is_valid_image_path(path: String) -> bool:
	if path.is_empty():
		return false
	var ext: String = path.get_extension().to_lower()
	return ext in SUPPORTED_EXTENSIONS

# load recent files list from persistent storage
func load_recent_files() -> void:
	if not FileAccess.file_exists(RECENT_FILES_PATH):
		return
	var file: FileAccess = FileAccess.open(RECENT_FILES_PATH, FileAccess.READ)
	if file:
		var json_text: String = file.get_as_text()
		var parsed = JSON.parse_string(json_text)
		if parsed is Array:
			recent_files = PackedStringArray(parsed)

# add file path to recent files list and save
func add_recent_file(path: String) -> void:
	if path.is_empty():
		return
	var list: Array = Array(recent_files)
	list.erase(path)
	list.push_front(path)
	if list.size() > 10:
		list.resize(10)
	recent_files = PackedStringArray(list)
	var file: FileAccess = FileAccess.open(RECENT_FILES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(list))
