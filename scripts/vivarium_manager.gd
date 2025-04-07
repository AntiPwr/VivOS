extends Node2D
## COMPREHENSIVE VIVARIUM MANAGER
## Combines all core functionality into a single script

# ---------- VIVARIUM SAVE DATA CLASS ----------
class VivariumSaveData extends Resource:
	# Save data properties
	@export var vivarium_name: String = ""
	@export var save_date: Dictionary = {}
	@export var data: Dictionary = {}
	
	func _init(p_name: String = "", p_data: Dictionary = {}) -> void:
		vivarium_name = p_name
		data = p_data
		save_date = Time.get_datetime_dict_from_system()
	
	# Returns a human-readable string of when this save was created
	func get_formatted_date() -> String:
		if save_date.is_empty():
			return "Unknown date"
		
		return "%04d-%02d-%02d %02d:%02d:%02d" % [
			save_date.year,
			save_date.month, 
			save_date.day,
			save_date.hour, 
			save_date.minute, 
			save_date.second
		]

# ---------- CONFIGURATION VARIABLES ----------

# Debug settings
@export_category("Debug Settings")
@export var enabled_debug: bool = true
@export var log_level: int = 2  # Increased to warnings+errors
@export var log_to_file: bool = true  # Enable file logging
@export var draw_debug_visuals: bool = true  # Enable visual debugging
@export var enable_camera_debug: bool = false

# UI debug settings
@export_category("UI Debug Settings")
@export var ui_debug_enabled: bool = true  # Enable UI debugging
@export var track_mouse: bool = true
@export var track_panels: bool = true
@export var track_buttons: bool = true
@export var debug_settings_panel: bool = true  # NEW: Debug settings panel specifically

# Settings debug
@export_category("Settings Debug")
@export var monitor_settings_creation: bool = true
@export var monitor_settings_position: bool = true
@export var fix_settings_issues: bool = true
@export var safe_settings_mode: bool = true  # NEW: Use safer settings instantiation

# Vivarium settings
@export_category("Vivarium Settings")
@export var auto_save: bool = true
@export var auto_save_interval: int = 300  # 5 minutes

# Game settings
@export_category("Game Settings")
@export var difficulty_level: int = 1  # 1=Easy, 2=Normal, 3=Hard
@export var productivity_hours: int = 8  # Target productive hours per day (1-24)
@export var use_real_time_clock: bool = true  # If false, use in-game time

# Audio settings
@export_category("Audio Settings")
@export var music_volume: float = 0.5
@export var sfx_volume: float = 0.7

# Video settings
@export_category("Video Settings")
@export var fullscreen: bool = false

# ---------- CONSTANTS ----------

# Save system (matching SaveManager)
const SAVE_DIR = "user://saves/"
const VIVARIUM_PREFIX = "vivarium_"
const SAVE_EXT = ".tres"

# Settings files
const SETTINGS_FILE = "user://game_settings.cfg"
const PRODUCTIVITY_FILE = "user://productivity_data.cfg"

# ---------- VARIABLES ----------

# Vivarium state
var vivarium_name: String = "Untitled Vivarium"
var first_frame: bool = true
var is_loading: bool = false
var needs_save: bool = false
var auto_save_timer: float = 0.0
# Current vivarium name - for global access (formerly in GlobalData)
var current_vivarium_name: String = ""

# References
@onready var animals_container = $Animals if has_node("Animals") else null

# Debug state
var log_file: FileAccess
var reported_messages = {}
var debug_overlay: CanvasLayer
var last_scene_name = ""
var scene_changing = false
var scene_change_start_time = 0

# UI tracking
var tracked_panels: Dictionary = {}
var tracked_buttons: Dictionary = {}
var tracked_events: Array = []
var panel_toggles: int = 0

# Statistics
var fps_min = 1000
var fps_max = 0
var fps_avg = 0
var fps_samples = []
var max_samples = 100
var timing_data = {}

# Productivity tracking
var last_productivity_check: Dictionary = Time.get_datetime_dict_from_system()
var productivity_today: float = 0.0  # Hours of productivity so far today
var start_app_time: float = float(Time.get_unix_time_from_system())
var total_app_time: float = 0.0  # Total time the app has been running
var last_session_time: float = 0.0  # Time from the previous session
var days_tracked: int = 0  # Number of days productivity has been tracked
var base_decay_rate: float = 0.0556  # Base rate for 30 minutes to fully decay at 100% difficulty

# Signals
signal difficulty_changed(new_level)
signal productivity_updated(hours, target)

# ---------- INITIALIZATION ----------

func _ready():
	log_message("VivManager: Initializing comprehensive manager", 2)
	
	# Initialize save directory
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
		log_message("VivManager: Created save directory", 2)
	
	# Load settings
	load_settings()
	load_productivity_data()
	
	# Initialize debug systems
	if enabled_debug:
		_init_logging()
	
	# Try to get vivarium name from global data
	# This code checks if we're in a scene with already established global data
	var global_data_node = get_node_or_null("/root/GlobalData")
	if global_data_node and global_data_node.current_vivarium_name != "":
		vivarium_name = global_data_node.current_vivarium_name
		log_message("VivManager: Using vivarium name from GlobalData: " + vivarium_name, 2)
	
	# If current_vivarium_name is set, use it for vivarium_name
	if current_vivarium_name != "":
		vivarium_name = current_vivarium_name
		log_message("VivManager: Using vivarium name from current_vivarium_name: " + vivarium_name, 2)
	
	# Force camera to be current
	if has_node("Camera2D"):
		var camera = get_node("Camera2D")
		camera.enabled = true
		camera.make_current()
		camera.zoom = Vector2.ONE
		
		# Enable camera debug if specified
		if enable_camera_debug and camera.has_method("toggle_debug_overlay"):
			camera.toggle_debug_overlay(true)
		
		log_message("VivManager: Camera enabled and set current", 2)
	else:
		log_message("VivManager: No Camera2D found, using default camera", 1)
	
	# Ensure background is visible
	if has_node("GlassBackground"):
		var bg = get_node("GlassBackground")
		bg.visible = true
		log_message("VivManager: Background made visible at " + str(bg.position), 3)
	
	# Initialize vivarium
	log_message("VivManager: Initializing vivarium: " + vivarium_name, 2)
	
	# Load vivarium data if name is set and not "Untitled"
	if vivarium_name != "Untitled Vivarium":
		var loaded = load_vivarium(vivarium_name)
		if !loaded:
			log_message("VivManager: Failed to load vivarium, starting fresh", 1)
	
	# Add input actions
	_register_input_actions()
	
	# Connect to scene tree signals
	get_tree().connect("tree_changed", _on_scene_changed)
	
	# Start tracking time
	start_app_time = float(Time.get_unix_time_from_system())
	
	# Set app name based on vivarium
	DisplayServer.window_set_title("VivOS - " + vivarium_name)

# ---------- PROCESSING ----------

func _process(delta):
	# Check for first frame setup
	if first_frame and Engine.get_process_frames() > 5:
		_handle_first_frame()
	
	# Update auto-save timer if enabled
	if auto_save and !first_frame:
		auto_save_timer += delta
		if auto_save_timer >= auto_save_interval:
			if needs_save:
				save_vivarium()
				needs_save = false
			auto_save_timer = 0.0
	
	# Check for stuck scene transitions
	if scene_changing:
		var elapsed = Time.get_ticks_msec() - scene_change_start_time
		if elapsed > 5000:  # 5 second timeout
			log_message("WARNING: Scene transition taking too long (" + str(elapsed/1000.0) + " seconds)", 1)
			scene_changing = false  # Reset the flag to prevent continuous warnings
	
	# Update debug overlay if enabled
	if enabled_debug and ui_debug_enabled and debug_overlay:
		_update_debug_overlay()
	
	# Update productivity tracking
	if use_real_time_clock:
		_check_real_time_productivity()
	else:
		_update_in_game_productivity(delta)
	
	# Collect performance statistics
	if enabled_debug and Engine.get_frames_drawn() % 10 == 0:
		_update_performance_stats()

func _handle_first_frame():
	first_frame = false
	
	# Ensure camera is set up properly
	if has_node("Camera2D"):
		var camera = get_node("Camera2D")
		camera.enabled = true
		camera.make_current()
		
		# Set window size
		var viewport = get_viewport()
		if viewport:
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			
			# Update viewport size
			if viewport.size != Vector2i(1920, 1080):
				get_tree().root.size = Vector2i(1920, 1080)
				log_message("VivManager: Set viewport size to 1920x1080", 2)
		
		log_message("VivManager: Final viewport setup complete", 3)
	
	# Ensure UI is on top
	if has_node("CanvasLayer/UI"):
		log_message("VivManager: Ensuring UI is visible", 3)
		var ui = get_node("CanvasLayer/UI")
		
		if ui.has_node("VivButton"):
			var button = ui.get_node("VivButton")
			if !button.visible:
				button.visible = true
				log_message("VivManager: Made VivButton visible", 3)

# ---------- INPUT HANDLING ----------

func _input(event):
	# Save shortcut (Ctrl+S)
	if event.is_action_pressed("save_game"):
		save_vivarium()
		get_viewport().set_input_as_handled()
	
	# Print diagnostics with F10
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		_print_diagnostics("F10 pressed")
		get_viewport().set_input_as_handled()
	
	# Handle other debug shortcuts if debug is enabled
	if enabled_debug:
		_handle_debug_input(event)

func _register_input_actions():
	# Save action
	if !InputMap.has_action("save_game"):
		InputMap.add_action("save_game")
		var event = InputEventKey.new()
		event.keycode = KEY_S
		event.ctrl_pressed = true
		InputMap.action_add_event("save_game", event)
	
	# Register debug actions
	if enabled_debug:
		# Debug toggle action
		if !InputMap.has_action("toggle_debug"):
			InputMap.add_action("toggle_debug")
			var event = InputEventKey.new()
			event.keycode = KEY_F1
			event.shift_pressed = true
			InputMap.action_add_event("toggle_debug", event)
			
		# UI debug toggle action
		if !InputMap.has_action("toggle_ui_debug"):
			InputMap.add_action("toggle_ui_debug")
			var event = InputEventKey.new()
			event.keycode = KEY_F2
			event.shift_pressed = true
			InputMap.action_add_event("toggle_ui_debug", event)

func _handle_debug_input(event):
	# Toggle debug with Shift+F1
	if event.is_action_pressed("toggle_debug"):
		enabled_debug = !enabled_debug
		log_message("Debug " + ("enabled" if enabled_debug else "disabled"), 2)
		get_viewport().set_input_as_handled()
	
	# Toggle UI debug with Shift+F2
	if event.is_action_pressed("toggle_ui_debug"):
		ui_debug_enabled = !ui_debug_enabled
		if debug_overlay:
			debug_overlay.visible = ui_debug_enabled
		log_message("UI Debug " + ("enabled" if ui_debug_enabled else "disabled"), 2)
		get_viewport().set_input_as_handled()
		
	# Toggle camera debug with F3
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_camera_debug(!enable_camera_debug)
		get_viewport().set_input_as_handled()
	
	# Toggle panel with F2
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		_toggle_panel()
		get_viewport().set_input_as_handled()

# ---------- PRODUCTIVITY TRACKING ----------

func _check_real_time_productivity():
	var current_time = Time.get_datetime_dict_from_system()
	
	# Check if it's a new day
	if current_time.day != last_productivity_check.day or current_time.month != last_productivity_check.month or current_time.year != last_productivity_check.year:
		# Reset daily productivity counter
		productivity_today = 0.0
		days_tracked += 1
		log_message("New day detected, reset productivity tracking", 2)
	
	# Update last check time
	last_productivity_check = current_time

func _update_in_game_productivity(delta):
	# Convert delta seconds to hours
	var delta_hours: float = delta / 3600.0
	
	# Add to productivity counter
	productivity_today += delta_hours
	
	# Check if we've reached a full day in the app
	if productivity_today >= 24.0:
		productivity_today = 0.0
		days_tracked += 1

func get_hunger_decay_rate() -> float:
	# Calculate how much of the productivity target has been met
	var productivity_ratio: float
	
	if use_real_time_clock:
		# For real-time clock: ratio of current productivity to target
		productivity_ratio = clamp(productivity_today / productivity_hours, 0.0, 1.0)
	else:
		# For in-game clock: simulate a 24-hour cycle based on game time
		var hour_of_day = fmod(productivity_today, 24.0)
		var active_hours = productivity_hours
		
		# If within active hours window, consider fully productive
		if hour_of_day < active_hours:
			productivity_ratio = 1.0
		else:
			productivity_ratio = 0.5  # Half effective outside active hours
	
	# Calculate decay rate inversely proportional to productivity
	# Less productivity = faster decay
	var decay_multiplier = 1.0 - (productivity_ratio * 0.8)  # Range: 0.2 to 1.0
	var decay_rate = base_decay_rate * decay_multiplier
	
	# Debug output
	if enabled_debug and Engine.get_process_frames() % 3600 == 0:  # Log once a minute
		log_message("Productivity: " + str(productivity_today) + "/" + str(productivity_hours) + 
			  " hours, Decay rate: " + str(decay_rate), 3)
	
	return decay_rate

func record_productivity(hours: float):
	productivity_today += hours
	productivity_updated.emit(productivity_today, productivity_hours)
	save_productivity_data()

# ---------- SAVE/LOAD SYSTEM ----------

func save_vivarium() -> bool:
	log_message("Saving vivarium: " + vivarium_name, 2)
	
	# Create save data dictionary
	var save_data = {
		"vivarium_name": vivarium_name,
		"animals": []
	}
	
	# Save all animals
	if animals_container:
		for animal in animals_container.get_children():
			if animal.has_method("get_save_data"):
				save_data.animals.append(animal.get_save_data())
			elif "species" in animal:  # Fallback for old animals
				var animal_data = {
					"type": animal.species.to_lower().replace(" ", "_"),
					"name": animal.creature_name,
					"position": {"x": animal.position.x, "y": animal.position.y},
					"health": animal.get("health") if animal.has("health") else 100.0,
					"satisfaction": animal.get("satisfaction") if animal.has("satisfaction") else 100.0
				}
				save_data.animals.append(animal_data)
	
	# Save to file
	var success = _save_vivarium_to_file(vivarium_name, save_data)
	
	if success:
		log_message("Vivarium saved successfully", 2)
	else:
		log_message("Failed to save vivarium", 1)
	
	return success

func load_vivarium(vivarium_name_to_load: String) -> bool:
	log_message("Loading vivarium: " + vivarium_name_to_load, 2)
	
	# Load from file
	var vivarium_data = _load_vivarium_from_file(vivarium_name_to_load)
	
	# Properly handle the case of a new vivarium with no existing save
	if vivarium_data.is_empty():
		log_message("Failed to load vivarium - no data found", 1)
		return false
	
	# Use the vivarium name from the data or fall back to the provided name
	if vivarium_data.has("vivarium_name"):
		vivarium_name = vivarium_data.vivarium_name
	else:
		vivarium_name = vivarium_name_to_load
		log_message("No vivarium name in data, using: " + vivarium_name, 2)
	
	# Clear existing animals
	if animals_container:
		for child in animals_container.get_children():
			child.queue_free()
	
	# Load animals if they exist
	if vivarium_data.has("animals") and vivarium_data.animals is Array and animals_container:
		if vivarium_data.animals.size() > 0:
			log_message("Loading " + str(vivarium_data.animals.size()) + " animals", 2)
			var animal_manager = get_node_or_null("/root/AnimalManager")
			
			if !animal_manager:
				log_message("AnimalManager not found, can't spawn animals", 1)
				return false
			
			for animal_data in vivarium_data.animals:
				# Map old type names to new consolidated type names
				var species_type = "Cherry Shrimp"
				if animal_data.type == "dream_guppy":
					species_type = "Dream Guppy"
				
				# Create animal using AnimalManager
				var spawn_position = Vector2(animal_data.position.x, animal_data.position.y)
				var animal = animal_manager.spawn_animal(species_type, spawn_position, animals_container)
				
				# Set saved properties
				if animal:
					animal.creature_name = animal_data.name
					if animal_data.has("health"):
						animal.health = animal_data.health
					if animal_data.has("satisfaction"):
						animal.satisfaction = animal_data.satisfaction
					
					log_message("Spawned " + species_type + " named '" + animal_data.name + "'", 3)
		else:
			log_message("No animals found in save data", 2)
	
	log_message("Vivarium loaded successfully", 2)
	return true

func _save_vivarium_to_file(save_name: String, vivarium_data: Dictionary) -> bool:
	# Ensure we have a valid name
	if save_name.is_empty():
		log_message("Cannot save vivarium with empty name", 1)
		return false
	
	# Create a resource to save
	var save_data = VivariumSaveData.new()
	save_data.vivarium_name = save_name
	save_data.save_date = Time.get_datetime_dict_from_system()
	save_data.data = vivarium_data
	
	# Generate the save path
	var save_path = SAVE_DIR + VIVARIUM_PREFIX + save_name.to_lower().replace(" ", "_") + SAVE_EXT
	
	# Save the resource
	var result = ResourceSaver.save(save_data, save_path)
	if result == OK:
		log_message("Vivarium saved to " + save_path, 3)
		return true
	else:
		log_message("Failed to save vivarium. Error code: " + str(result), 1)
		return false

func _load_vivarium_from_file(load_name: String) -> Dictionary:
	var save_path = SAVE_DIR + VIVARIUM_PREFIX + load_name.to_lower().replace(" ", "_") + SAVE_EXT
	
	if not FileAccess.file_exists(save_path):
		log_message("Creating new vivarium - no existing save found for: " + load_name, 2)
		# Return an empty but valid dictionary structure
		return {
			"vivarium_name": load_name, 
			"animals": []
		}
	
	var save_data = ResourceLoader.load(save_path)
	if save_data is VivariumSaveData:
		log_message("Loaded vivarium from " + save_path, 3)
		return save_data.data
	else:
		log_message("Failed to load vivarium save data", 1)
		return {}

func get_saved_vivariums() -> Array:
	var saved_vivariums = []
	
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with(VIVARIUM_PREFIX) and file_name.ends_with(SAVE_EXT):
				var extracted_name = file_name.substr(VIVARIUM_PREFIX.length(), 
					file_name.length() - VIVARIUM_PREFIX.length() - SAVE_EXT.length())
				
				# Convert back to display format (replace underscores with spaces, capitalize)
				extracted_name = extracted_name.replace("_", " ").capitalize()
				saved_vivariums.append(extracted_name)
			
			file_name = dir.get_next()
	else:
		log_message("Could not access save directory", 1)
	
	return saved_vivariums

func delete_vivarium(save_name: String) -> bool:
	var save_path = SAVE_DIR + VIVARIUM_PREFIX + save_name.to_lower().replace(" ", "_") + SAVE_EXT
	
	if not FileAccess.file_exists(save_path):
		log_message("Cannot delete - save file does not exist: " + save_path, 1)
		return false
	
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		var result = dir.remove(save_path)
		if result == OK:
			log_message("Deleted save file: " + save_path, 2)
			return true
		else:
			log_message("Failed to delete save file. Error code: " + str(result), 1)
			return false
	
	log_message("Could not access save directory to delete file", 1)
	return false

# ---------- SETTINGS MANAGEMENT ----------

func save_settings():
	var config = ConfigFile.new()
	config.set_value("Game", "difficulty", difficulty_level)
	config.set_value("Game", "productivity_hours", productivity_hours)
	config.set_value("Game", "use_real_time_clock", use_real_time_clock)
	config.set_value("Audio", "music_volume", music_volume)
	config.set_value("Audio", "sfx_volume", sfx_volume)
	config.set_value("Video", "fullscreen", fullscreen)
	config.set_value("Debug", "enabled", enabled_debug)
	config.set_value("Debug", "log_level", log_level)
	
	var error = config.save(SETTINGS_FILE)
	if error != OK:
		log_message("Error saving settings: " + str(error), 1)

func load_settings():
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_FILE)
	
	if error == OK:
		# Load values or use defaults
		difficulty_level = config.get_value("Game", "difficulty", 1)
		productivity_hours = config.get_value("Game", "productivity_hours", 8)
		use_real_time_clock = config.get_value("Game", "use_real_time_clock", true)
		music_volume = config.get_value("Audio", "music_volume", 0.5)
		sfx_volume = config.get_value("Audio", "sfx_volume", 0.7)
		fullscreen = config.get_value("Video", "fullscreen", false)
		enabled_debug = config.get_value("Debug", "enabled", true)
		log_level = config.get_value("Debug", "log_level", 1)
		
		# Apply loaded settings
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		
		log_message("Settings loaded from file", 3)
	else:
		log_message("Using default settings", 2)

func save_productivity_data():
	var config = ConfigFile.new()
	config.set_value("Productivity", "today", productivity_today)
	config.set_value("Productivity", "last_check", Time.get_unix_time_from_system())
	config.set_value("Productivity", "days_tracked", days_tracked)
	config.set_value("Productivity", "total_app_time", total_app_time)
	
	var error = config.save(PRODUCTIVITY_FILE)
	if error != OK:
		log_message("Error saving productivity data: " + str(error), 1)

func load_productivity_data():
	var config = ConfigFile.new()
	var error = config.load(PRODUCTIVITY_FILE)
	
	if error == OK:
		productivity_today = config.get_value("Productivity", "today", 0.0)
		days_tracked = config.get_value("Productivity", "days_tracked", 0)
		last_session_time = config.get_value("Productivity", "total_app_time", 0.0)
		
		# Check if this is a new day
		var last_check_time = config.get_value("Productivity", "last_check", 0)
		var last_check_date = Time.get_datetime_dict_from_unix_time(last_check_time)
		var current_date = Time.get_datetime_dict_from_system()
		
		if current_date.day != last_check_date.day or current_date.month != last_check_date.month or current_date.year != last_check_date.year:
			productivity_today = 0.0
			log_message("New day detected, reset productivity counter", 2)
		
		log_message("Productivity data loaded", 3)
	else:
		log_message("No productivity data found, starting fresh", 2)

# ---------- DEBUGGING SYSTEM ----------

func _init_logging():
	if log_to_file:
		var datetime = Time.get_datetime_dict_from_system()
		var filename = "user://vivarium_debug_%04d%02d%02d_%02d%02d%02d.log" % [
			datetime["year"], datetime["month"], datetime["day"],
			datetime["hour"], datetime["minute"], datetime["second"]
		]
		
		log_file = FileAccess.open(filename, FileAccess.WRITE)
		if log_file:
			log_file.store_line("=== VivOS Debug Log ===")
			log_file.store_line("Started at: %04d-%02d-%02d %02d:%02d:%02d" % [
				datetime["year"], datetime["month"], datetime["day"],
				datetime["hour"], datetime["minute"], datetime["second"]
			])
			log_file.store_line("----------------------------")
			log_message("Logging to " + filename, 2)
		else:
			push_error("Failed to create log file")

func log_message(message: String, level: int = 2, category: String = "GENERAL"):
	if !enabled_debug || level > log_level:
		return
	
	var prefix = ""
	match level:
		1: prefix = "ERROR"
		2: prefix = "INFO"
		3: prefix = "DEBUG"
		4: prefix = "VERBOSE"
		
	var output = category + " [" + prefix + "]: " + message
	print(output)
	
	if log_to_file and log_file:
		var datetime = Time.get_datetime_dict_from_system()
		var timestamp = "%02d:%02d:%02d" % [datetime["hour"], datetime["minute"], datetime["second"]]
		log_file.store_line("[%s] %s" % [timestamp, output])
		
	# Add to event tracking for UI debugger if enabled
	if ui_debug_enabled and level <= 2:
		_add_event(message)

func log_once(message: String, identifier: String, level: int = 3, category: String = "GENERAL"):
	if reported_messages.has(identifier):
		return
		
	reported_messages[identifier] = true
	log_message(message, level, category)

func _update_debug_overlay():
	# Update stats if we have a debug overlay
	if !debug_overlay:
		return
		
	# Update panel stats
	var panel_stats = debug_overlay.get_node_or_null("Control/DebugPanel/VBoxContainer/PanelStats")
	if panel_stats:
		panel_stats.text = "Panel Toggles: %d | Active Panels: %d" % [panel_toggles, _count_visible_panels()]
	
	# Update event list
	var event_list = debug_overlay.get_node_or_null("Control/DebugPanel/VBoxContainer/EventList")
	if event_list && tracked_events.size() > 0:
		event_list.text = ""
		var events_to_show = min(tracked_events.size(), 20)
		for i in range(events_to_show):
			var event = tracked_events[tracked_events.size() - 1 - i]
			event_list.append_text(event + "\n")

func _add_event(event_text: String):
	if !ui_debug_enabled:
		return
		
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp = "%02d:%02d:%02d" % [datetime["hour"], datetime["minute"], datetime["second"]]
	tracked_events.append("[%s] %s" % [timestamp, event_text])
	
	# Keep event list from getting too large
	if tracked_events.size() > max_samples:
		tracked_events.remove_at(0)
	
	# Update last event label if overlay exists
	if debug_overlay:
		var last_event = debug_overlay.get_node_or_null("Control/DebugPanel/VBoxContainer/LastEvent")
		if last_event:
			last_event.text = "Last: " + event_text

func _on_scene_changed():
	scene_changing = true
	scene_change_start_time = Time.get_ticks_msec()
	
	# Log at info level
	log_message("Scene changing detected", 2, "SCENE")
	
	# Check if current scene has changed
	_check_scene_change()
	
	# Release the scene_changing flag after a delay
	get_tree().create_timer(1.0).timeout.connect(func():
		scene_changing = false
		log_message("Scene change completed", 2, "SCENE")
	)

func _check_scene_change():
	var root = get_tree().get_root()
	var current_scene = root.get_child(root.get_child_count() - 1)
	
	if current_scene.name != last_scene_name:
		last_scene_name = current_scene.name
		log_message("Scene changed to: " + current_scene.name, 2, "SCENE")
		return true
		
	return false

func _update_performance_stats():
	var current_fps = Engine.get_frames_per_second()
	fps_min = min(fps_min, current_fps)
	fps_max = max(fps_max, current_fps)
	
	fps_samples.append(current_fps)
	if fps_samples.size() > max_samples:
		fps_samples.pop_front()
	
	# Calculate average
	var sum = 0
	for sample in fps_samples:
		sum += sample
	fps_avg = sum / fps_samples.size()

	# Print performance statistics less frequently
	if Engine.get_frames_drawn() % 300 == 0:
		log_message("Performance: FPS Min: %d, Max: %d, Avg: %.1f" % [fps_min, fps_max, fps_avg], 3, "PERF")

func _print_diagnostics(trigger: String):
	log_message("DIAGNOSTICS: " + trigger, 2, "DIAG")
	
	# Safety check
	if !is_inside_tree() or !get_tree():
		return
	
	var time_dict = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		time_dict["year"], time_dict["month"], time_dict["day"],
		time_dict["hour"], time_dict["minute"], time_dict["second"]
	]
	
	var vp_size = get_viewport().get_visible_rect().size
	var window_size = DisplayServer.window_get_size()
	
	var scene_name = "unknown"
	if get_tree() and get_tree().current_scene:
		scene_name = get_tree().current_scene.name
	else:
		return  # Exit early if not ready
	
	var camera = get_viewport().get_camera_2d()
	var camera_str = "None found"
	if camera:
		camera_str = "Position: " + str(camera.position) + ", Enabled: " + str(camera.enabled)
	
	log_message("\n=== VIVARIUM DIAGNOSTICS: %s ===" % trigger, 2, "DIAG")
	log_message("Time: %s" % time_str, 2, "DIAG")
	log_message("Viewport: %s | Window: %s" % [vp_size, window_size], 2, "DIAG")
	log_message("Camera: %s" % camera_str, 2, "DIAG")
	log_message("Current Scene: %s" % scene_name, 2, "DIAG")
	log_message("===========================================================\n", 2, "DIAG")
	
	# Check if we're in the vivarium scene
	if scene_name.to_lower() == "vivarium":
		_check_vivarium_scene()

func _check_vivarium_scene():
	# Safety check
	if !is_inside_tree() or !get_tree() or !get_tree().current_scene:
		return
		
	# Only check if we're in the vivarium scene
	var viv_node = get_tree().current_scene
	if viv_node.name.to_lower() != "vivarium":
		return
	
	# Quick integrity check of key vivarium components
	var has_camera = viv_node.has_node("Camera2D")
	var has_background = viv_node.has_node("GlassBackground") 
	var has_animals = viv_node.has_node("Animals")
	var has_ui = viv_node.has_node("VivUI")
	
	var passed = has_camera && has_background && has_animals && has_ui
	
	log_message("Vivarium integrity check: %s" % ("PASSED" if passed else "FAILED"), 2, "DIAG")
	if !passed:
		log_message("Missing components: %s%s%s%s" % [
			"Camera " if !has_camera else "",
			"Background " if !has_background else "",
			"Animals " if !has_animals else "",
			"UI " if !has_ui else ""
		], 1, "DIAG")

func _count_visible_panels() -> int:
	if !ui_debug_enabled:
		return 0
		
	var count = 0
	for panel_name in tracked_panels:
		var panel = tracked_panels[panel_name]
		if is_instance_valid(panel) and panel.visible:
			count += 1
	return count

# ---------- PUBLIC API ----------

# Scene navigation
func return_to_menu() -> void:
	log_message("Returning to main menu", 2)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Settings setters
func set_difficulty(level: int):
	difficulty_level = clamp(level, 1, 3)
	save_settings()
	difficulty_changed.emit(difficulty_level)

func set_productivity_target(hours: int):
	productivity_hours = clamp(hours, 1, 24)
	save_settings()
	productivity_updated.emit(productivity_today, productivity_hours)

func set_use_real_time(enabled: bool):
	use_real_time_clock = enabled
	save_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0, 1)
	save_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0, 1)
	save_settings()

func set_fullscreen(enabled: bool):
	fullscreen = enabled
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func set_vivarium_name(new_name: String) -> void:
	vivarium_name = new_name
	current_vivarium_name = new_name
	log_message("VivManager: Set vivarium name to: " + vivarium_name, 2)
	DisplayServer.window_set_title("VivOS - " + vivarium_name)

# Get the current vivarium name
func get_vivarium_name() -> String:
	return vivarium_name

# Global data transition functions - provide compatibility with old GlobalData references
func get_global_data(key: String, default_value = null):
	# Implement data storage functionality if needed
	match key:
		"vivarium_name":
			return vivarium_name
		_:
			return default_value

func set_global_data(key: String, value):
	# Implement data storage functionality if needed
	match key:
		"vivarium_name":
			set_vivarium_name(value)
	
	# Mark that we need to save the data
	needs_save = true

# Debug toggles
func toggle_camera_debug(enable: bool = true):
	enable_camera_debug = enable
	
	if has_node("Camera2D"):
		var camera = get_node("Camera2D")
		if camera.has_method("toggle_debug_overlay"):
			camera.toggle_debug_overlay(enable_camera_debug)
			log_message("Camera debug overlay " + ("enabled" if enable_camera_debug else "disabled"), 2)
			return true
	
	return false

func _toggle_panel():
	var viv_ui = get_tree().get_root().find_child("VivUI", true, false)
	if viv_ui && viv_ui.has_node("VivPanel"):
		var panel = viv_ui.get_node("VivPanel")
		panel.visible = !panel.visible
		log_message("Panel toggled to " + str(panel.visible), 2, "PANEL")
		panel_toggles += 1

# Timing functions
func time_start(label):
	if !enabled_debug:
		return
	timing_data[label] = Time.get_ticks_usec()

func time_end(label):
	if !enabled_debug || !timing_data.has(label):
		return
	
	var end_time = Time.get_ticks_usec()
	var duration = (end_time - timing_data[label]) / 1000.0
	log_message("Timing '%s': %.2f ms" % [label, duration], 3, "TIMING")
	timing_data.erase(label)

# Safety wrapper to instantiate settings panel
func create_settings_panel_safely(parent_node = null):
	if !safe_settings_mode:
		# Use standard method
		var settings_scene = load("res://scenes/settings.tscn")
		if settings_scene:
			return settings_scene.instantiate()
		return null
	
	# Safe mode implementation
	log_message("Using safe settings panel creation", 2, "SETTINGS")
	
	# Try to load the scene
	var settings_resource = load("res://scenes/settings.tscn")
	if !settings_resource:
		log_message("Failed to load settings scene", 1, "SETTINGS")
		return null
	
	# Check if it can be instantiated
	if !settings_resource.can_instantiate():
		log_message("Settings scene cannot be instantiated", 1, "SETTINGS")
		return null
	
	# Try to instantiate
	var panel = null
	panel = settings_resource.instantiate()
	if !panel:
		log_message("Panel is null after instantiation", 1, "SETTINGS")
		return null
	
	log_message("Settings panel created successfully", 2, "SETTINGS")
	
	# Set up safe size
	panel.custom_minimum_size = Vector2(800, 600)
	
	# Add to parent if provided
	if parent_node and parent_node.is_inside_tree():
		parent_node.add_child(panel)
		
		# Position after adding
		if monitor_settings_position:
			_position_settings_panel(panel, parent_node)
	
	
	
	return panel

# Position settings panel safely
func _position_settings_panel(panel, parent_node):
	if !panel or !parent_node:
		return
		
	# Wait for panel to be ready
	await parent_node.get_tree().process_frame
	
	# Get viewport size
	var viewport_size = parent_node.get_viewport_rect().size
	var panel_size = panel.size
	
	# Use fallback if size is invalid
	if panel_size.x < 10 or panel_size.y < 10:
		panel_size = Vector2(800, 600)
		log_message("Using fallback size for panel positioning", 2, "SETTINGS")
	
	# Calculate center position
	var center_pos = (viewport_size - panel_size) / 2
	center_pos = Vector2(max(0, center_pos.x), max(0, center_pos.y))
	
	# Set position
	panel.position = center_pos
	log_message("Positioned panel at " + str(center_pos), 2, "SETTINGS")
