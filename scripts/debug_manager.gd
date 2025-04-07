extends Node

## COMPREHENSIVE DEBUG MANAGER
## Combines all debug functionality into a single script

# ---------- CONFIGURATION VARIABLES ----------

# General debug settings
@export_category("General Debug Settings")
@export var enabled: bool = true
@export var log_level: int = 1  # 0=off, 1=errors only, 2=warnings+errors, 3=all
@export var log_to_file: bool = false
@export var log_file_path: String = "user://vivarium_debug.log"
@export var draw_debug_visuals: bool = false

# UI debugging settings
@export_category("UI Debug Settings")
@export var ui_debug_enabled: bool = false
@export var track_mouse: bool = true
@export var track_interactions: bool = true
@export var track_panels: bool = true
@export var track_buttons: bool = true
@export var visual_overlay: bool = false

# Performance settings
@export_category("Performance Settings")
@export var collect_statistics: bool = false
@export var verbose_timing: bool = false

# Button fix settings
@export_category("Button Fix Settings")
@export var fix_all_buttons: bool = true
@export var fix_viv_button: bool = true

# Theme settings
@export_category("Theme Settings")
@export var apply_global_theme: bool = true
@export var default_font_size: int = 16

# Panel toggle settings
@export_category("Panel Toggle Settings")
@export var enable_panel_toggle: bool = true
@export var panel_toggle_key: int = KEY_F2

# ---------- STATE VARIABLES ----------

# General debug state
var log_file: FileAccess
var reported_messages = {}
var debug_overlay: CanvasLayer
var last_scene_name = ""
var scene_changing = false
var scene_change_start_time = 0
var instance_count = 0

# Statistics tracking
var fps_min = 1000
var fps_max = 0
var fps_avg = 0
var fps_samples = []
var max_samples = 100
var timing_data = {}

# UI debugging
var tracked_panels: Dictionary = {}
var tracked_buttons: Dictionary = {}
var tracked_events: Array = []
var mouse_position: Vector2 = Vector2.ZERO
var last_click_position: Vector2 = Vector2.ZERO
var last_click_time: float = 0.0
var click_success: bool = false
var total_clicks: int = 0
var successful_clicks: int = 0
var failed_clicks: int = 0
var panel_toggles: int = 0

# Theme management
var global_theme: Theme

# Animal debugging
var animals_in_scene = []
var debug_mode = false

# ---------- INITIALIZATION ----------

func _ready():
	print("DebugManager: Initializing comprehensive debug system...")
	process_priority = -1000  # Make sure this runs after everything else
	
	# Safety check to prevent duplicates
	instance_count += 1
	if instance_count > 1:
		print("WARNING: Multiple DebugManager instances detected!")
		queue_free()
		return

	# Initialize subsystems based on export settings
	if enabled:
		_init_logging()
		get_tree().connect("tree_changed", _on_scene_changed)
	
	if ui_debug_enabled:
		_init_ui_debugger()
	
	if apply_global_theme:
		_init_theme_manager()

	if fix_all_buttons:
		call_deferred("_process_existing_buttons")
		get_tree().node_added.connect(_on_node_added)
	
	if fix_viv_button:
		call_deferred("_fix_viv_button")
	
	if enable_panel_toggle:
		_init_panel_toggle()
	
	# Register keyboard shortcuts for debugging
	_register_debug_shortcuts()
	
	# Wait for the scene to be fully loaded
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	# Initial diagnostics
	_print_diagnostics("Initial startup")
	
	# Fix buttons at start
	if fix_all_buttons:
		call_deferred("_process_existing_buttons")
	
	log_message("DebugManager: Initialization complete", 2)

# ---------- LOGGING SYSTEM ----------

func _init_logging():
	if log_to_file:
		var datetime = Time.get_datetime_dict_from_system()
		var filename = log_file_path
		if log_file_path == "user://vivarium_debug.log":
			# Create a timestamped log file
			filename = "user://vivarium_debug_%04d%02d%02d_%02d%02d%02d.log" % [
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
			print("DebugManager: Logging to " + filename)
		else:
			push_error("DebugManager: Failed to create log file")

func log_message(message: String, level: int = 2, category: String = "GENERAL"):
	if !enabled || level > log_level:
		return
	
	var prefix = ""
	match level:
		1: prefix = "ERROR"
		2: prefix = "INFO"
		3: prefix = "DEBUG"
		4: prefix = "VERBOSE"
		
	var output = category + " [" + prefix + "]: " + message
	print(output)
	
	if log_to_file && log_file:
		var datetime = Time.get_datetime_dict_from_system()
		var timestamp = "%02d:%02d:%02d" % [datetime["hour"], datetime["minute"], datetime["second"]]
		log_file.store_line("[%s] %s" % [timestamp, output])
		
	# Add to event tracking for UI debugger if enabled
	if ui_debug_enabled && level <= 2:
		_add_event(message)

# Log without duplicating the same message repeatedly
func log_once(message: String, identifier: String, level: int = 3, category: String = "GENERAL"):
	if reported_messages.has(identifier):
		return
		
	reported_messages[identifier] = true
	log_message(message, level, category)

# Reset a specific reported message to allow it to be logged again
func reset_message(identifier: String):
	if reported_messages.has(identifier):
		reported_messages.erase(identifier)

# Reset all reported messages
func reset_all_messages():
	reported_messages.clear()

# ---------- UI DEBUGGER SYSTEM ----------

func _init_ui_debugger():
	if visual_overlay:
		_create_debug_overlay()
	
	# Connect to input events
	if is_inside_tree() and get_viewport():
		get_viewport().connect("gui_focus_changed", _on_gui_focus_changed)
	
	log_message("UI Debugger initialized", 2, "UI")

func _create_debug_overlay():
	debug_overlay = CanvasLayer.new()
	debug_overlay.layer = 100 # Ensure it's on top
	debug_overlay.name = "UIDebugOverlay"
	
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var panel = Panel.new()
	panel.name = "DebugPanel"
	panel.anchor_right = 0.2
	panel.anchor_bottom = 0.5
	panel.position = Vector2(10, 10)
	panel.self_modulate = Color(0.1, 0.1, 0.1, 0.8)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "UI Debugger"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var click_stats = Label.new()
	click_stats.name = "ClickStats"
	click_stats.text = "Clicks: 0 | Success: 0 | Failed: 0"
	
	var panel_stats = Label.new()
	panel_stats.name = "PanelStats"
	panel_stats.text = "Panel Toggles: 0"
	
	var last_event = Label.new()
	last_event.name = "LastEvent"
	last_event.text = "Last Event: None"
	
	var event_list = RichTextLabel.new()
	event_list.name = "EventList"
	event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_list.text = "--- Events will appear here ---"
	event_list.scroll_following = true
	
	var toggle_button = Button.new()
	toggle_button.name = "ToggleButton"
	toggle_button.text = "Hide"
	toggle_button.pressed.connect(func(): panel.visible = !panel.visible)
	
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	vbox.add_child(click_stats)
	vbox.add_child(panel_stats)
	vbox.add_child(last_event)
	vbox.add_child(HSeparator.new())
	vbox.add_child(event_list)
	vbox.add_child(toggle_button)
	
	panel.add_child(vbox)
	control.add_child(panel)
	
	# Add mouse position tracker
	if track_mouse:
		var mouse_label = Label.new()
		mouse_label.name = "MousePosition"
		mouse_label.anchor_top = 1.0
		mouse_label.anchor_bottom = 1.0
		mouse_label.offset_top = -50
		mouse_label.offset_bottom = -20
		mouse_label.text = "Mouse: (0, 0)"
		control.add_child(mouse_label)
	
	debug_overlay.add_child(control)
	add_child(debug_overlay)

func register_panel(panel_name: String, panel_node: Control):
	if !ui_debug_enabled || !track_panels:
		return
		
	tracked_panels[panel_name] = panel_node
	log_message("Panel registered: " + panel_name, 3, "UI")

func register_button(button_name: String, button_node: Button):
	if !ui_debug_enabled || !track_buttons:
		return
		
	tracked_buttons[button_name] = button_node
	button_node.pressed.connect(func(): _on_button_pressed(button_name))
	log_message("Button registered: " + button_name, 3, "UI")

func report_panel_visibility_change(panel_name: String, is_visible: bool):
	if !ui_debug_enabled:
		return
		
	panel_toggles += 1
	var message = "Panel '%s' is now %s" % [panel_name, "visible" if is_visible else "hidden"]
	log_message(message, 3, "UI")
	_add_event(message)

func report_button_click(button_name: String, was_successful: bool):
	if !ui_debug_enabled:
		return
		
	click_success = was_successful
	var message = "Button '%s' clicked - %s" % [button_name, "SUCCESS" if was_successful else "FAILED"]
	log_message(message, 3, "UI")
	_add_event(message)
	
	if was_successful:
		successful_clicks += 1
	else:
		failed_clicks += 1

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

func _check_click_success():
	if !ui_debug_enabled:
		return
		
	if !click_success:
		failed_clicks += 1
		log_message("Click at (%d,%d) was NOT handled by any UI element" % [last_click_position.x, last_click_position.y], 3, "UI")
		_add_event("FAILED click at (%d,%d)" % [last_click_position.x, last_click_position.y])

func _on_button_pressed(button_name: String):
	if !ui_debug_enabled:
		return
		
	log_message("Button pressed: " + button_name, 3, "UI")
	_add_event("Button pressed: " + button_name)
	click_success = true

func _on_gui_focus_changed(control):
	if !ui_debug_enabled:
		return
		
	if control and control.get_class() == "Button":
		log_message("Focus changed to button: " + control.name, 3, "UI")
		_add_event("Focus: " + control.name)

func _count_visible_panels() -> int:
	if !ui_debug_enabled:
		return 0
		
	var count = 0
	for panel_name in tracked_panels:
		var panel = tracked_panels[panel_name]
		if is_instance_valid(panel) and panel.visible:
			count += 1
	return count

# ---------- BUTTON FIXING SYSTEM ----------

func _process_existing_buttons():
	if !fix_all_buttons:
		return
		
	log_message("Fixing existing buttons...", 2, "BUTTONS")
	
	# Find all buttons in the scene
	var buttons = _find_all_buttons(get_tree().root)
	
	for button in buttons:
		_fix_button(button)
	
	log_message("Fixed " + str(buttons.size()) + " buttons", 2, "BUTTONS")

func _fix_button(button: Button):
	if !fix_all_buttons:
		return
	
	# Set proper focus mode to prevent spacebar interaction
	button.focus_mode = Control.FOCUS_NONE
	
	# Set proper action mode for reliable click detection - mouse only
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	
	# Ensure the button has good mouse cursor
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Ensure mouse filtering is correct
	button.mouse_filter = Control.MOUSE_FILTER_STOP

# Recursively find all buttons in the scene
func _find_all_buttons(node: Node) -> Array:
	var buttons = []
	
	if node is Button:
		buttons.append(node)
	
	for child in node.get_children():
		buttons.append_array(_find_all_buttons(child))
	
	return buttons

# Handle newly added nodes
func _on_node_added(node):
	if !fix_all_buttons:
		return
		
	if node is Button:
		_fix_button(node)
		log_message("Fixed newly added button: " + node.name, 3, "BUTTONS")

func _fix_viv_button():
	if !fix_viv_button:
		return
		
	log_message("Attempting to fix VivButton...", 2, "VIVBUTTON")
	
	# Wait for scene to initialize fully
	await get_tree().create_timer(0.75).timeout
	_fix_viv_button_impl()
	
	# Run another attempt after a bit longer
	await get_tree().create_timer(2.0).timeout
	_fix_viv_button_impl()

func _fix_viv_button_impl():
	log_message("VivButton: EMERGENCY FIX ATTEMPT...", 2, "VIVBUTTON")
	
	# Get all relevant nodes - Ensure consistent lowercase
	var vivarium = get_tree().get_root().get_node_or_null("vivarium") 
	if vivarium == null:
		log_message("VivButton: ERROR - vivarium not found!", 1, "VIVBUTTON")
		return
		
	# Look for CanvasLayer/UI/VivButton in vivarium scene
	var viv_button = null
	var viv_panel = null
	
	# Try finding in the expected path
	if vivarium.has_node("CanvasLayer/UI/VivButton"):
		viv_button = vivarium.get_node("CanvasLayer/UI/VivButton")
		log_message("VivButton: Found VivButton in vivarium/CanvasLayer/UI/VivButton", 2, "VIVBUTTON")
		
		# Now look for VivUI instance, which should have the panel
		var viv_ui = get_tree().get_root().find_child("VivUI", true, false)
		if viv_ui:
			viv_panel = viv_ui.get_node_or_null("VivPanel")
			if viv_panel:
				log_message("VivButton: Found VivPanel in VivUI", 2, "VIVBUTTON")
			else:
				log_message("VivButton: ERROR - Could not find VivPanel in VivUI", 1, "VIVBUTTON")
				return
		else:
			log_message("VivButton: ERROR - Could not find VivUI node!", 1, "VIVBUTTON")
			return
	else:
		# Try finding it directly in the tree as fallback
		viv_button = get_tree().get_root().find_child("VivButton", true, false)
		viv_panel = get_tree().get_root().find_child("VivPanel", true, false)
		
		if viv_button and viv_panel:
			log_message("VivButton: Found VivButton and VivPanel through global search", 2, "VIVBUTTON")
		else:
			log_message("VivButton: ERROR - Could not locate VivButton or VivPanel!", 1, "VIVBUTTON")
			return
	
	# Button found - now apply super aggressive fixes
	
	# 1. Reset button to default state
	viv_button.disabled = false
	viv_button.focus_mode = Control.FOCUS_NONE  # Prevent keyboard focus
	viv_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	viv_button.modulate = Color(1.5, 1.5, 0.7)  # Make it very visible
	
	# 2. Remove ALL signal connections from the button
	var connections = viv_button.get_signal_connection_list("pressed")
	for conn in connections:
		log_message("VivButton: Removing existing connection: " + str(conn), 3, "VIVBUTTON")
		viv_button.disconnect("pressed", conn["callable"])
	
	# 3. Force panel to be invisible initially
	viv_panel.visible = false
	
	# 4. Add a DIRECT toggle function
	var toggle_func = func():
		log_message("VivButton: DIRECT TOGGLE FUNCTION CALLED", 2, "VIVBUTTON")
		viv_panel.visible = !viv_panel.visible
		log_message("VivButton: VivPanel visibility set to: " + str(viv_panel.visible), 2, "VIVBUTTON")
	
	# 5. Connect the direct toggle function
	viv_button.pressed.connect(toggle_func)
	
	# 6. Set up direct mouse monitor for the button
	viv_button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			log_message("VivButton: Direct mouse click detected on VivButton!", 2, "VIVBUTTON")
			toggle_func.call()  # Call toggle directly on mouse click
	)
	
	log_message("VivButton: Super aggressive fix applied to VivButton!", 2, "VIVBUTTON")

# ---------- THEME MANAGER SYSTEM ----------

func _init_theme_manager():
	if !apply_global_theme:
		return
		
	log_message("ThemeManager: Initializing", 2, "THEME")
	
	# Try both possible locations for the global theme
	global_theme = load("res://themes/global_theme.tres")
	if global_theme == null:
		global_theme = load("res://resources/themes/global_theme.tres")
	
	if global_theme:
		log_message("ThemeManager: Successfully loaded global theme", 2, "THEME")
		
		# In Godot 4, we can't set ThemeDB.fallback_theme directly
		# Instead, we'll apply the theme to the current scene and all new scenes
		call_deferred("_apply_theme_to_current_scene") 
	else:
		log_message("ThemeManager: Failed to load global theme!", 1, "THEME")

func _apply_theme_to_current_scene():
	if !apply_global_theme || !global_theme:
		return
		
	# Wait for the scene to finish setting up
	await get_tree().process_frame
	
	# Get the current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		_apply_theme_to_node(current_scene)
		log_message("ThemeManager: Applied theme to current scene: " + current_scene.name, 3, "THEME")
	
	# Connect to the tree_changed signal to handle scene changes
	# Avoid connecting multiple times
	if get_tree() and !get_tree().tree_changed.is_connected(_on_tree_changed_theme):
		get_tree().tree_changed.connect(_on_tree_changed_theme)

func _apply_theme_to_node(node: Node):
	if !apply_global_theme || !global_theme:
		return
		
	# If the node is a Control, apply the theme
	if node is Control:
		node.theme = global_theme
	
	# Process all children recursively
	for child in node.get_children():
		_apply_theme_to_node(child)

func _on_tree_changed_theme():
	if !apply_global_theme:
		return
		
	# Check if tree is available before proceeding
	if !is_inside_tree() or !get_tree():
		log_message("ThemeManager: Tree changed but tree is null or node not in tree", 3, "THEME")
		return
	
	# Wait a moment for the scene to stabilize
	call_deferred("_deferred_theme_update")

# Handle scene changes in a deferred way to ensure the tree is ready
func _deferred_theme_update():
	if !apply_global_theme:
		return
		
	# Add some safety with extra checks
	if !is_inside_tree() or !get_tree():
		log_message("ThemeManager: Deferred update skipped - tree not available", 3, "THEME")
		return
		
	# Wait frames
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Apply theme to new scene if we're still in the tree
	if is_inside_tree() and get_tree():
		_apply_theme_to_current_scene()
	else:
		log_message("ThemeManager: Tree no longer available after waiting frames", 3, "THEME")

func apply_heading_style(node: Control, size: String = "Medium"):
	if !apply_global_theme || !global_theme || !node:
		return
	
	var style_name = "Header" + size
	
	if node is Label:
		node.add_theme_font_override("font", global_theme.get_font("font", style_name))
		node.add_theme_font_size_override("font_size", global_theme.get_font_size("font_size", style_name))

func apply_body_style(node: Control, size: String = "Medium"):
	if !apply_global_theme || !global_theme || !node:
		return
	
	var style_name = "Body" + size
	
	if node is Label:
		node.add_theme_font_override("font", global_theme.get_font("font", style_name))
		node.add_theme_font_size_override("font_size", global_theme.get_font_size("font_size", style_name))

func apply_button_style(node: Button, size: String = "Medium"):
	if !apply_global_theme || !global_theme || !node:
		return
	
	var style_name = "Button" + size
	
	node.add_theme_font_override("font", global_theme.get_font("font", style_name))
	node.add_theme_font_size_override("font_size", global_theme.get_font_size("font_size", style_name))

# ---------- PANEL TOGGLE SYSTEM ----------

func _init_panel_toggle():
	if !enable_panel_toggle:
		return
		
	log_message("PanelToggle: Adding emergency toggle for debugging", 2, "PANEL")
	
	# Remove the debug label creation and panel positioning that was causing errors
	# The original code was trying to call a non-existent method
	# await get_tree().create_timer(1.0).timeout
	# call_deferred("_fix_bio_panel_positioning")

# Add the missing method that was causing errors
func _fix_bio_panel_positioning():
	# This is the implementation of the missing method
	log_message("Fixing bio panel positioning", 2, "PANEL")
	
	# Find the bio panel if it exists
	var bio_panel = get_tree().get_root().find_child("BioToolPanel", true, false)
	if bio_panel and bio_panel is Control:
		# Center it in the viewport or position it appropriately
		var viewport_size = get_viewport().get_visible_rect().size
		var panel_size = bio_panel.size
		bio_panel.position = Vector2(
			(viewport_size.x - panel_size.x) / 2,
			(viewport_size.y - panel_size.y) / 2
		)
		log_message("Bio panel positioned at: " + str(bio_panel.position), 2, "PANEL")
	else:
		log_message("Bio panel not found or not ready", 2, "PANEL")

# ---------- DIAGNOSTICS SYSTEM ----------

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

func _print_scene_tree(node, indent, max_depth: int = 3):
	if indent > max_depth:
		return
		
	var indent_str = ""
	for i in indent:
		indent_str += "  "
	
	log_message(indent_str + node.name + " (" + node.get_class() + ")", 3, "TREE")
	
	for child in node.get_children():
		_print_scene_tree(child, indent + 1, max_depth)

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

# ---------- SETTINGS CHECKER ----------

func _check_project_settings():
	log_message("Checking project settings:", 3, "SETTINGS")
	
	# Check window size - using DisplayServer
	log_message("Display/Window/Size: " + str(DisplayServer.window_get_size()), 3, "SETTINGS")
	
	# Check main scene
	var main_scene = ProjectSettings.get_setting("application/run/main_scene")
	log_message("Main scene: " + str(main_scene), 3, "SETTINGS")
	
	# Fix window size if needed
	_fix_window_size()

func _fix_window_size():
	# Get current window size
	var current_size = DisplayServer.window_get_size()
	log_message("Current window size: " + str(current_size), 3, "SETTINGS")
	
	# If size is not exactly 1920x1080, adjust it
	if current_size.x != 1920 or current_size.y != 1080:
		log_message("Adjusting window size from " + str(current_size) + " to (1920, 1080)", 2, "SETTINGS")
		
		# Set to 1920x1080
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		
		 # Content scale factor adjustment removed - not supported in this Godot version
		# For scaling adjustments, consider using get_tree().root.content_scale_factor instead
		
		log_message("Window size adjusted to: " + str(DisplayServer.window_get_size()), 2, "SETTINGS")

# ---------- ANIMAL DEBUG TOOLS ----------

func toggle_animal_debug_mode():
	debug_mode = !debug_mode
	log_message("Animal debug mode " + ("enabled" if debug_mode else "disabled"), 2, "ANIMALS")
	
	# Find all animals in the scene
	animals_in_scene = get_tree().get_nodes_in_group("animals")
	log_message("Found " + str(animals_in_scene.size()) + " animals", 2, "ANIMALS")
	
	# Visualize their interaction areas
	for animal in animals_in_scene:
		if animal.has_node("InteractionArea/CollisionShape2D"):
			var shape = animal.get_node("InteractionArea/CollisionShape2D")
			if debug_mode:
				# Make collision shapes visible
				shape.debug_color = Color(1, 0, 0, 0.3)  # Red, semi-transparent
			else:
				# Reset to nearly invisible
				shape.debug_color = Color(1, 1, 1, 0.05)
			
			log_message("Animal " + str(animal.get("creature_name")) + " at position " + str(animal.global_position), 3, "ANIMALS")

# ---------- SCENE MONITORING ----------

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

# Check if current scene has changed and log if so
func _check_scene_change():
	var root = get_tree().get_root()
	var current_scene = root.get_child(root.get_child_count() - 1)
	
	if current_scene.name != last_scene_name:
		last_scene_name = current_scene.name
		log_message("Scene changed to: " + current_scene.name, 2, "SCENE")
		return true
		
	return false

# ---------- TIMING FUNCTIONS ----------

# Start timing a block of code
func time_start(label):
	if !enabled || !verbose_timing:
		return
	timing_data[label] = Time.get_ticks_usec()

# End timing and log result
func time_end(label):
	if !enabled || !verbose_timing || !timing_data.has(label):
		return
	
	var end_time = Time.get_ticks_usec()
	var duration = (end_time - timing_data[label]) / 1000.0
	log_message("Timing '%s': %.2f ms" % [label, duration], 3, "TIMING")
	timing_data.erase(label)

# ---------- REGISTER DEBUG SHORTCUTS ----------

func _register_debug_shortcuts():
	# Register the action if it doesn't exist
	if not InputMap.has_action("toggle_ui_debugger"):
		InputMap.add_action("toggle_ui_debugger")
		
		# Create keyboard shortcut event (Shift+F1)
		var event = InputEventKey.new()
		event.keycode = KEY_F1
		event.shift_pressed = true
		
		InputMap.action_add_event("toggle_ui_debugger", event)
		
	# Add a separate action for toggling visual highlights
	if not InputMap.has_action("toggle_debug_highlights"):
		InputMap.add_action("toggle_debug_highlights")
		
		# Create keyboard shortcut event (Shift+F2)
		var event = InputEventKey.new()
		event.keycode = KEY_F2
		event.shift_pressed = true
		
		InputMap.action_add_event("toggle_debug_highlights", event)
		
	log_message("Registered debug shortcuts: Shift+F1, Shift+F2", 2, "INPUT")

# ---------- INPUT HANDLING ----------

func _input(event):
	# If UI debugger is enabled, track inputs
	if ui_debug_enabled && track_interactions && event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			total_clicks += 1
			last_click_position = event.position
			last_click_time = Time.get_ticks_msec() / 1000.0
			click_success = false # Will be set to true if something handles this click
			
			# Add a timer to check if click was successful
			var timer = Timer.new()
			timer.wait_time = 0.1
			timer.one_shot = true
			timer.timeout.connect(func(): _check_click_success())
			add_child(timer)
			timer.start()
	
	# Keyboard shortcuts for debug functions
	if event is InputEventKey and event.pressed:
		 # Remove Panel toggle functionality
		# if event.keycode == panel_toggle_key and enable_panel_toggle:
		#	_toggle_panel()
		#	get_viewport().set_input_as_handled()
		
		# Animal debug mode
		if event.ctrl_pressed and event.keycode == KEY_D:
			toggle_animal_debug_mode()
			get_viewport().set_input_as_handled()
		
		# VivPanel toggle with F3  
		elif event.keycode == KEY_F3 and fix_viv_button:
			_toggle_viv_panel()
			get_viewport().set_input_as_handled()
		
		# Debug overlay toggle
		elif event.is_action_pressed("toggle_ui_debugger"):
			ui_debug_enabled = !ui_debug_enabled
			if debug_overlay:
				debug_overlay.visible = ui_debug_enabled
			log_message("UI Debugger " + ("enabled" if ui_debug_enabled else "disabled"), 2, "UI")
			get_viewport().set_input_as_handled()
		
		# Print diagnostics with F10
		elif event.keycode == KEY_F10:
			_print_diagnostics("F10 pressed")
			get_viewport().set_input_as_handled()

# Keep this function for other uses, but it won't be triggered by F2 key anymore
func _toggle_panel():
	var viv_ui = get_tree().get_root().find_child("VivUI", true, false)
	if viv_ui && viv_ui.has_node("VivPanel"):
		var panel = viv_ui.get_node("VivPanel")
		panel.visible = !panel.visible
		log_message("Panel toggled to " + str(panel.visible), 2, "PANEL")

# Toggle the VivPanel using F3
func _toggle_viv_panel():
	var viv_panel = get_tree().get_root().find_child("VivPanel", true, false)
	if viv_panel:
		viv_panel.visible = !viv_panel.visible
		log_message("F3 toggle - VivPanel visibility: " + str(viv_panel.visible), 2, "VIVBUTTON")

# ---------- PROCESS FUNCTION ----------

func _process(_delta):
	# Check for stuck scene transitions
	if scene_changing:
		var elapsed = Time.get_ticks_msec() - scene_change_start_time
		if elapsed > 5000:  # 5 second timeout
			log_message("WARNING: Scene transition taking too long (" + str(elapsed/1000.0) + " seconds)", 1, "SCENE")
			scene_changing = false  # Reset the flag to prevent continuous warnings
	
	# Update UI debugger overlay if enabled
	if ui_debug_enabled && visual_overlay && debug_overlay:
		# Update mouse position
		if track_mouse:
			mouse_position = get_viewport().get_mouse_position()
			var mouse_label = debug_overlay.get_node_or_null("Control/MousePosition")
			if mouse_label:
				mouse_label.text = "Mouse: (%d, %d)" % [mouse_position.x, mouse_position.y]
		
		# Update stats
		var click_stats = debug_overlay.get_node_or_null("Control/DebugPanel/VBoxContainer/ClickStats")
		if click_stats:
			click_stats.text = "Clicks: %d | Success: %d | Failed: %d" % [total_clicks, successful_clicks, failed_clicks]
		
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
	
	# Performance statistics
	if collect_statistics && Engine.get_frames_drawn() % 10 == 0:
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
