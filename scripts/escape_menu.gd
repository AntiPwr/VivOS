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
	
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	online_button.pressed.connect(_on_online_pressed)
	save_exit_button.pressed.connect(_on_save_exit_pressed)
	
	# Pause the game when the menu appears
	get_tree().paused = true

# Resume button handler
func _on_resume_pressed():
	_close_menu()

# Settings button handler
func _on_settings_pressed():
	# Find the global settings manager
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("show_settings"):
		settings_manager.show_settings()
		
		# Hide the menu panel while settings are shown
		$MenuPanel.visible = false
	else:
		# Fallback to old method if settings manager not found
		# Instantiate settings scene
		if settings_instance == null:
			settings_instance = settings_scene.instantiate()
			add_child(settings_instance)
			
			# Position the settings panel
			if settings_instance:
				# Make the main menu panel invisible
				$MenuPanel.visible = false
				
				# Connect the closed signal
				if settings_instance.has_signal("settings_closed"):
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

# Input handler for additional keyboard interaction (like Escape key)
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# If settings are open, close them first
		if settings_instance:
			_on_settings_closed()
		else:
			# Otherwise close the menu
			_close_menu()
		get_viewport().set_input_as_handled()
