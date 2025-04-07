extends Control

# Escape Menu - Controls the pause menu functionality when Escape key is pressed

# Reference to button nodes
@onready var resume_button = $MenuPanel/VBoxContainer/ResumeButton
@onready var settings_button = $MenuPanel/VBoxContainer/SettingsButton
@onready var online_button = $MenuPanel/VBoxContainer/OnlineButton
@onready var save_exit_button = $MenuPanel/VBoxContainer/SaveExitButton

# Reference to the settings scene
var settings_scene = preload("res://scenes/settings.tscn")
var settings_instance = null

# Reference to the parent scene
var vivarium_scene

# Signals
signal menu_closed

func _ready():
	# Get the parent scene (should be the vivarium scene)
	vivarium_scene = get_parent()
	
	# Fix button focus modes - ensure buttons can be clicked
	_fix_button_focus(resume_button)
	_fix_button_focus(settings_button)
	_fix_button_focus(online_button)
	_fix_button_focus(save_exit_button)
	
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	online_button.pressed.connect(_on_online_pressed)
	save_exit_button.pressed.connect(_on_save_exit_pressed)
	
	# Ensure buttons are clickable
	_ensure_buttons_clickable()
	
	# Pause the game when the menu appears
	get_tree().paused = true

# Helper to fix button focus modes
func _fix_button_focus(button):
	if button:
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# Make sure buttons are clickable
func _ensure_buttons_clickable():
	for button in [$MenuPanel/VBoxContainer/ResumeButton, 
					$MenuPanel/VBoxContainer/SettingsButton, 
					$MenuPanel/VBoxContainer/OnlineButton, 
					$MenuPanel/VBoxContainer/SaveExitButton]:
		if button:
			# Set proper mouse filter to ensure clicks reach the buttons
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			# Use button release mode for more reliable detection
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			# Ensure focus is set correctly
			button.focus_mode = Control.FOCUS_ALL
			# Set mouse cursor
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			# Ensure button is enabled
			button.disabled = false

# Resume button handler
func _on_resume_pressed():
	_close_menu()

# Settings button handler
func _on_settings_pressed():
	# Find the global settings manager
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("show_settings"):
		# Important: Use CallDeferred to avoid potential processing issues
		call_deferred("_show_settings_deferred", settings_manager)
	else:
		# Fallback to old method if settings manager not found
		call_deferred("_show_settings_fallback")

# Use deferred calls for safer scene manipulation
func _show_settings_deferred(settings_manager):
	var settings_panel = settings_manager.show_settings()
	if settings_panel:
		# Make settings_panel process even while game is paused
		settings_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		
		# Hide the menu panel while settings are shown
		$MenuPanel.visible = false
		
		# Connect to the closed signal with proper error handling
		if !settings_manager.is_connected("settings_closed", _on_settings_closed):
			settings_manager.connect("settings_closed", _on_settings_closed)

# Fallback method for showing settings
func _show_settings_fallback():
	# Instantiate settings scene
	if settings_instance == null:
		settings_instance = settings_scene.instantiate()
		if settings_instance:
			# Make settings process while paused
			settings_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
			
			add_child(settings_instance)
			
			# Position the settings panel
			if settings_instance:
				# Make the main menu panel invisible
				$MenuPanel.visible = false
				
				# Connect the closed signal
				if settings_instance.has_signal("settings_closed"):
					if !settings_instance.is_connected("settings_closed", _on_settings_closed):
						settings_instance.connect("settings_closed", _on_settings_closed)

# Handle settings closed
func _on_settings_closed():
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null
	
	# Show the main menu panel again
	$MenuPanel.visible = true

# Online button handler
func _on_online_pressed():
	# Show a notification dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Online Services"
	dialog.dialog_text = "Online services are coming soon!"
	dialog.get_ok_button().text = "OK"
	
	add_child(dialog)
	dialog.popup_centered()

# Save & Exit button handler
func _on_save_exit_pressed():
	# Save the vivarium
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("save_vivarium"):
		viv_manager.save_vivarium()
	
	# Unpause before exiting
	get_tree().paused = false
	
	# Return to main menu
	if viv_manager and viv_manager.has_method("return_to_menu"):
		viv_manager.return_to_menu()
	else:
		# Fallback method
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Close the menu and resume the game
func _close_menu():
	get_tree().paused = false
	emit_signal("menu_closed")
	queue_free()

# Override input to ensure we handle events properly
func _input(event):
	# Always handle mouse events inside this control
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = event.position
		if get_global_rect().has_point(mouse_pos):
			# If mouse is within our menu, prevent further processing
			get_viewport().set_input_as_handled()
	
	# Check for Escape key to toggle menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# If settings are open, close them first
		if settings_instance:
			_on_settings_closed()
		else:
			# Otherwise close the menu
			_close_menu()
		get_viewport().set_input_as_handled()
