extends Node2D

# COMPREHENSIVE VIVARIUM MANAGER
# Combines all core functionality into a single script

# References to key subsystems
var animal_manager: Node
var camera_manager: Node
var settings_manager: Node
var ui_manager: Node

# Vivarium data
var vivarium_name: String = "My Vivarium"
var vivarium_created_date: Dictionary
var last_saved_time: int = 0

# Game settings
var difficulty_level: int = 1  # 1=Easy, 2=Normal, 3=Hard
var auto_save: bool = true
var auto_save_interval: int = 300  # seconds

# Productivity tracking
var productivity_today: float = 0.0
var productivity_target: float = 8.0  # hours
var productivity_history: Dictionary = {}

# Lifecycle state
var is_initialized: bool = false
var save_timer: float = 0.0

# Signals
signal vivarium_loaded
signal vivarium_saved
signal productivity_updated(current, target)

func _ready():
	print("VivariumManager: Starting initialization...")
	
	# Record creation date for new vivariums
	vivarium_created_date = Time.get_datetime_dict_from_system()
	
	# Find required managers
	_find_managers()
	
	# Connect signals
	_connect_signals()
	
	# Mark as initialized
	is_initialized = true
	
	print("VivariumManager: Initialization complete")

# Process function for auto-save and time tracking
func _process(delta):
	if !is_initialized:
		return
	
	# Handle auto-save timer
	if auto_save:
		save_timer += delta
		if save_timer >= auto_save_interval:
			save_timer = 0
			save_vivarium()

# Find all required manager nodes
func _find_managers():
	# Find AnimalManager
	animal_manager = get_node_or_null("/root/AnimalManager")
	if !animal_manager:
		print("VivariumManager: Warning - AnimalManager not found")
	
	# Find CameraManager
	camera_manager = get_node_or_null("/root/CameraManager")
	if !camera_manager:
		print("VivariumManager: Warning - CameraManager not found")
	
	# Find SettingsManager
	settings_manager = get_node_or_null("/root/SettingsManager") 
	if !settings_manager:
		print("VivariumManager: Warning - SettingsManager not found")
	
	# Find UI Manager (could be VivUI1)
	ui_manager = get_tree().get_root().find_child("VivUI1", true, false)
	if !ui_manager:
		print("VivariumManager: Warning - UI Manager not found")

# Connect to required signals
func _connect_signals():
	# Connect to vivarium signals if vivarium scene exists
	var vivarium = get_tree().current_scene
	if vivarium and vivarium.has_signal("vivarium_ready"):
		if !vivarium.is_connected("vivarium_ready", Callable(self, "_on_vivarium_ready")):
			vivarium.connect("vivarium_ready", Callable(self, "_on_vivarium_ready"))

# Handle vivarium ready signal
func _on_vivarium_ready():
	print("VivariumManager: Vivarium is ready, loading data...")
	
	# Load vivarium data if a name is set
	if vivarium_name != "My Vivarium":
		load_vivarium(vivarium_name)
	
	emit_signal("vivarium_loaded")

# VIVARIUM MANAGEMENT FUNCTIONS

# Set the name of the current vivarium
func set_vivarium_name(viv_name: String):
	vivarium_name = viv_name
	print("VivariumManager: Vivarium name set to " + viv_name)

# Get the current vivarium name
func get_vivarium_name() -> String:
	return vivarium_name

# Save the current vivarium state
func save_vivarium() -> bool:
	print("VivariumManager: Saving vivarium: " + vivarium_name)
	
	# Create save data dictionary
	var save_data = {
		"name": vivarium_name,
		"created_date": vivarium_created_date,
		"save_date": Time.get_datetime_dict_from_system(),
		"difficulty": difficulty_level,
		"productivity": {
			"today": productivity_today,
			"target": productivity_target,
			"history": productivity_history
		},
		"water_params": _get_water_parameters(),
		"animals": _get_animals_data(),
		"plants": _get_plants_data(),
		"decorations": _get_decorations_data()
	}
	
	# Save to file
	var save_path = "user://saves/" + vivarium_name.replace(" ", "_") + ".save"
	
	# Create directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if !dir.dir_exists("saves"):
		dir.make_dir("saves")
	
	# Save to file with error handling
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		last_saved_time = Time.get_ticks_msec()
		emit_signal("vivarium_saved")
		print("VivariumManager: Vivarium saved successfully")
		return true
	else:
		print("VivariumManager: Error saving vivarium: " + str(FileAccess.get_open_error()))
		return false

# Load a saved vivarium
func load_vivarium(viv_name: String) -> bool:
	print("VivariumManager: Loading vivarium: " + viv_name)
	
	# Set the vivarium name
	vivarium_name = viv_name
	
	# Construct the save path
	var save_path = "user://saves/" + viv_name.replace(" ", "_") + ".save"
	
	# Check if the file exists
	if !FileAccess.file_exists(save_path):
		print("VivariumManager: Save file not found: " + save_path)
		return false
	
	# Load the file
	var file = FileAccess.open(save_path, FileAccess.READ)
	if !file:
		print("VivariumManager: Error opening save file: " + str(FileAccess.get_open_error()))
		return false
	
	# Load and parse data
	var save_data = file.get_var()
	
	# Apply the loaded data
	if typeof(save_data) == TYPE_DICTIONARY:
		_apply_save_data(save_data)
		print("VivariumManager: Vivarium loaded successfully")
		return true
	else:
		print("VivariumManager: Invalid save data format")
		return false

# Delete a saved vivarium
func delete_vivarium(viv_name: String) -> bool:
	print("VivariumManager: Deleting vivarium: " + viv_name)
	
	# Construct the save path
	var save_path = "user://saves/" + viv_name.replace(" ", "_") + ".save"
	
	# Check if the file exists
	if !FileAccess.file_exists(save_path):
		print("VivariumManager: Save file not found: " + save_path)
		return false
	
	# Delete the file
	var err = DirAccess.remove_absolute(save_path)
	if err != OK:
		print("VivariumManager: Error deleting save file: " + str(err))
		return false
	
	print("VivariumManager: Vivarium deleted successfully")
	return true

# Get a list of all saved vivariums
func get_saved_vivariums() -> Array:
	var saves = []
	
	# Check if saves directory exists
	var dir = DirAccess.open("user://saves")
	if !dir:
		# Create the directory if it doesn't exist
		DirAccess.open("user://").make_dir("saves")
		return saves
	
	# List all save files
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".save"):
			# Extract vivarium name from filename
			var viv_name = file_name.replace(".save", "").replace("_", " ")
			saves.append(viv_name)
		file_name = dir.get_next()
	
	return saves

# Return to the main menu
func return_to_menu():
	print("VivariumManager: Returning to main menu")
	get_tree().change_scene_to_file("res://modules/ui/main_menu.tscn")

# PRODUCTIVITY TRACKING FUNCTIONS

# Record productivity time (in hours)
func record_productivity(hours: float):
	productivity_today += hours
	emit_signal("productivity_updated", productivity_today, productivity_target)
	print("VivariumManager: Recorded " + str(hours) + " hours of productivity")

# Set productivity target (in hours)
func set_productivity_target(hours: float):
	productivity_target = hours
	emit_signal("productivity_updated", productivity_today, productivity_target)

# Reset daily productivity tracking
func reset_daily_productivity():
	# Store current value in history before resetting
	var date_key = _get_date_key()
	productivity_history[date_key] = productivity_today
	
	# Reset today's value
	productivity_today = 0.0
	emit_signal("productivity_updated", productivity_today, productivity_target)

# SETTINGS FUNCTIONS

# Set difficulty level
func set_difficulty(level: int):
	difficulty_level = clamp(level, 1, 3)
	print("VivariumManager: Difficulty set to " + str(difficulty_level))

# HELPER FUNCTIONS

# Get current water parameters
func _get_water_parameters() -> Dictionary:
	var vivarium = get_tree().current_scene
	if vivarium and vivarium.has_method("get_water_parameters"):
		return vivarium.get_water_parameters()
	
	# Default values if method not found
	return {
		"temperature": 25.0,
		"ph": 7.0,
		"hardness": 7.0
	}

# Get save data for animals
func _get_animals_data() -> Array:
	var animals_data = []
	
	if animal_manager:
		var animals = get_tree().get_nodes_in_group("animals")
		for animal in animals:
			if animal.has_method("get_creature_name"):
				var animal_data = {
					"name": animal.get_creature_name(),
					"species": animal.species_type,
					"position": {"x": animal.position.x, "y": animal.position.y},
					"health": animal.health,
					"hunger": animal.hunger,
					"satisfaction": animal.satisfaction,
					"age": animal.age
				}
				animals_data.append(animal_data)
	
	return animals_data

# Get save data for plants
func _get_plants_data() -> Array:
	# Placeholder for future implementation
	return []

# Get save data for decorations
func _get_decorations_data() -> Array:
	# Placeholder for future implementation
	return []

# Apply loaded save data to current vivarium
func _apply_save_data(data: Dictionary):
	# Apply basic vivarium data
	if data.has("name"):
		vivarium_name = data.name
	
	if data.has("created_date"):
		vivarium_created_date = data.created_date
	
	if data.has("difficulty"):
		difficulty_level = data.difficulty
	
	# Apply productivity data
	if data.has("productivity"):
		if data.productivity.has("today"):
			productivity_today = data.productivity.today
		
		if data.productivity.has("target"):
			productivity_target = data.productivity.target
		
		if data.productivity.has("history"):
			productivity_history = data.productivity.history
	
	# Apply water parameters
	if data.has("water_params"):
		var vivarium = get_tree().current_scene
		if vivarium and vivarium.has_method("set_water_parameters"):
			var wp = data.water_params
			vivarium.set_water_parameters(wp.temperature, wp.ph, wp.hardness)
	
	# Spawn animals from save data
	if data.has("animals") and animal_manager:
		# First clear existing animals
		animal_manager.clear_all_animals()
		
		# Spawn new animals from save data
		for animal_data in data.animals:
			var pos = Vector2(animal_data.position.x, animal_data.position.y)
			var animal = animal_manager.spawn_animal(animal_data.species, pos)
			
			# Apply saved properties
			if animal:
				animal.set_creature_name(animal_data.name)
				animal.is_named = true
				animal.health = animal_data.health
				animal.hunger = animal_data.hunger
				animal.satisfaction = animal_data.satisfaction
				animal.age = animal_data.age
	
	# Emit updated signal
	emit_signal("productivity_updated", productivity_today, productivity_target)

# Get date key for productivity history
func _get_date_key() -> String:
	var date = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]
