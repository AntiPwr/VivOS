extends Node

# Global Settings Manager
# Handles showing settings from anywhere in the game

# Settings scene reference 
var settings_scene = preload("res://scenes/settings.tscn")
var active_settings = null

# Signal to let main game know when settings are closed
signal settings_closed

func _ready():
	print("SettingsManager: initialized")

# Show settings panel with proper error handling
func show_settings():
	print("SettingsManager: Showing settings")
	
	# If settings are already shown, just return
	if active_settings and is_instance_valid(active_settings):
		print("SettingsManager: Settings already active")
		return active_settings
	
	# Load settings scene with proper error handling
	if not settings_scene:
		settings_scene = load("res://scenes/settings.tscn")
	
	if settings_scene:
		# Create settings instance safely
		var settings = settings_scene.instantiate()
		
		# Make sure it processes while game is paused
		settings.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		
		# Add to the root to ensure it's visible everywhere
		get_tree().root.add_child(settings)
		
		# Keep track of the active settings panel
		active_settings = settings
		
		# First, set a safe position to avoid transform errors
		settings.position = Vector2(500, 300)
		
		# Wait a frame to allow proper setup
		await get_tree().process_frame
		
		# Center in the viewport
		var viewport_size = get_viewport().get_visible_rect().size
		var panel_size = settings.size
		
		# Use fallback size if invalid
		if panel_size.x < 100 || panel_size.y < 100:
			panel_size = Vector2(800, 600) 
		
		settings.position = (viewport_size - panel_size) / 2
		
		# Fix all buttons to ensure they're interactive
		_fix_settings_buttons(settings)
		
		# Connect closing signal
		if !settings.is_connected("settings_closed", _on_settings_closed):
			settings.connect("settings_closed", _on_settings_closed)
		
		print("SettingsManager: Settings panel created at " + str(settings.position))
		return settings
	else:
		print("SettingsManager: Failed to load settings scene")
		return null

# Recursively fix all buttons in the settings panel
func _fix_settings_buttons(node):
	if node is Button:
		node.focus_mode = Control.FOCUS_ALL
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif node is Slider:
		node.focus_mode = Control.FOCUS_ALL
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is CheckBox:
		node.focus_mode = Control.FOCUS_ALL
		node.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Process all children
	for child in node.get_children():
		_fix_settings_buttons(child)

# Hide/close any active settings panel
func hide_settings():
	if active_settings and is_instance_valid(active_settings):
		active_settings.queue_free()
		active_settings = null

# Handle settings panel closed
func _on_settings_closed():
	print("SettingsManager: Settings panel closed")
	active_settings = null
	emit_signal("settings_closed")

# Handle input to close settings with Escape key
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if active_settings and is_instance_valid(active_settings):
			hide_settings()
			emit_signal("settings_closed")
