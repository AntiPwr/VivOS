extends Control

# Settings Manager with Integrated Escape Menu Functionality
# Handles all game settings and pause menu functionality

#region UI References
# Settings UI References - using safe node access pattern
var hours_slider = null
var hours_value = null

# Audio settings
var music_slider = null
var sfx_slider = null

# Difficulty settings
var easy_button = null
var normal_button = null 
var hard_button = null

# Video settings
var fullscreen_check = null

# Data settings
var autosave_check = null
var reset_button = null
var backup_button = null

# Close button
var close_button = null

# Escape Menu references
var escape_menu_overlay = null
var escape_settings_button = null
var escape_online_button = null
var escape_save_exit_button = null
var escape_resume_button = null
#endregion

#region Settings Variables
# Settings values
var current_difficulty = 1  # 0: Easy, 1: Normal, 2: Hard
var music_volume = 0.5
var sfx_volume = 0.7
var is_fullscreen = false
var productivity_hours = 8
var today_productivity = 0.0
var autosave_enabled = true

# Reference to the vivarium manager
var vivarium_manager
# Reference to the parent scene
var vivarium_scene
# Whether this is being used as a standalone settings panel or as an escape menu
var is_escape_menu_mode = false
#endregion

# Signals
signal settings_closed
signal online_services_requested

func _ready():
	print("Settings: Initializing...")
	
	# Make sure we're processing inputs
	set_process_input(true)
	
	# Ensure this control catches input
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make the background clickable but have it stop input propagation
	var background = get_node_or_null("Background")
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Ensure our position is valid
	if position == Vector2.ZERO:
		position = Vector2(100, 100)  # Set a safe default position
	
	# Before grabbing focus, ensure the control has the proper focus mode
	set_focus_mode(Control.FOCUS_ALL)
	
	# For child controls that might be trying to grab focus
	for child in get_children():
		if child is Control:
			child.set_focus_mode(Control.FOCUS_ALL)
	
	# Find controls that need focus - use safer method without direct path
	var first_focusable = _find_first_focusable_control()
	
	if first_focusable:
		first_focusable.grab_focus()
	
	# Connect signals and get references
	_connect_signals()
	_get_references()
	
	print("Settings: Ready complete")
	
	# Initialize settings values by loading them from global state
	_initialize_settings()
	
	# Call deferred ready for additional setup
	call_deferred("_deferred_ready")

# Find the first control that can be focused
func _find_first_focusable_control() -> Control:
	# Try to find a tab container first
	var tab_container = get_node_or_null("TabContainer")
	if tab_container:
		# Try to find the first control in the active tab
		var active_tab = tab_container.get_current_tab_control()
		if active_tab:
			for child in active_tab.get_children():
				if child is Control and child.focus_mode != Control.FOCUS_NONE:
					return child
	
	# If no tab container, look through all controls
	for child in get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE:
			return child
	
	return null

# Get UI reference nodes
func _get_references():
	# Safely get UI references with null checks - using explicit node paths for reliability
	hours_slider = get_node_or_null("ScrollContainer/VBoxContainer/DifficultySection/ProductivityContainer/ProductivitySlider")
	hours_value = get_node_or_null("ScrollContainer/VBoxContainer/DifficultySection/ProductivityContainer/TodayContainer/TodayLabel")
	music_slider = get_node_or_null("ScrollContainer/VBoxContainer/AudioSection/MusicSlider")
	sfx_slider = get_node_or_null("ScrollContainer/VBoxContainer/AudioSection/SFXSlider")
	easy_button = get_node_or_null("ScrollContainer/VBoxContainer/DifficultySection/HBoxContainer/EasyButton")
	normal_button = get_node_or_null("ScrollContainer/VBoxContainer/DifficultySection/HBoxContainer/NormalButton")
	hard_button = get_node_or_null("ScrollContainer/VBoxContainer/DifficultySection/HBoxContainer/HardButton")
	close_button = get_node_or_null("CloseButton")
	fullscreen_check = get_node_or_null("ScrollContainer/VBoxContainer/VideoSection/FullscreenCheck")
	autosave_check = get_node_or_null("ScrollContainer/VBoxContainer/DataSection/AutosaveCheck")
	reset_button = get_node_or_null("ScrollContainer/VBoxContainer/DataSection/ButtonContainer/ResetButton")
	backup_button = get_node_or_null("ScrollContainer/VBoxContainer/DataSection/ButtonContainer/BackupButton")
	
	# Get system references if they exist
	vivarium_manager = get_node_or_null("/root/VivariumManager")
	escape_menu_overlay = get_node_or_null("EscapeMenuOverlay")
	
	if escape_menu_overlay:
		escape_settings_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/SettingsButton")
		escape_online_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/OnlineButton")
		escape_save_exit_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/SaveExitButton") 
		escape_resume_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/ResumeButton")

# Initialize settings
func _initialize_settings():
	# Load settings from config file
	_load_settings()
	
	# Deferred initialization to ensure all nodes are ready
	call_deferred("_deferred_ready")

# Deferred ready function
func _deferred_ready():
	# Wait for one frame to ensure everything is loaded
	await get_tree().process_frame
	
	# Check if we're being used in the main menu
	var parent_is_main_menu = get_parent() and get_parent().name == "MainMenu"
	
	# Only try to access escape menu nodes if they exist
	if has_node("EscapeMenuOverlay"):
		# Get Escape Menu references
		escape_menu_overlay = get_node_or_null("EscapeMenuOverlay")
		if escape_menu_overlay:
			escape_settings_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/SettingsButton")
			escape_online_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/OnlineButton")
			escape_save_exit_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/SaveExitButton")
			escape_resume_button = escape_menu_overlay.get_node_or_null("MenuPanel/VBoxContainer/ResumeButton")
	
	# Determine if we're being used as an escape menu
	is_escape_menu_mode = name == "EscapeMenu" or get_parent().name == "EscapeMenu" or has_node("EscapeMenuOverlay")
	
	# Special handling for main menu settings display
	if get_parent() and get_parent().name == "MainMenu":
		is_escape_menu_mode = false
		print("Settings: Detected we're in main menu")
		
		# Ensure size is appropriate for main menu display
		custom_minimum_size = Vector2(800, 600)
		
		# Make sure we're visible
		visible = true
		
	if is_escape_menu_mode:
		# Set process mode to process even when paused if we're an escape menu
		process_mode = Node.PROCESS_MODE_ALWAYS
		
		# The main panel should be hidden unless we're in standalone mode
		if escape_menu_overlay:
			escape_menu_overlay.visible = true
			# Hide the settings content initially
			if has_node("ScrollContainer"):
				$ScrollContainer.visible = false
			if has_node("SettingsTitle"):
				$SettingsTitle.visible = false
			if close_button:
				close_button.visible = false
	
	# Initialize UI with loaded values
	_initialize_ui()
	
	# Center in viewport if not already positioned by parent
	if position == Vector2.ZERO or parent_is_main_menu:
		_center_in_viewport()
	
	print("Settings: Initialization complete")
	
	# Hide the menu initially if we're in escape menu mode
	if is_escape_menu_mode and name == "EscapeMenu":
		visible = false

# Initialize UI with current values
func _initialize_ui():
	# Set initial state of settings UI with null checks
	if hours_slider:
		hours_slider.value = productivity_hours
		_update_hours_display(productivity_hours)
	
	if music_slider:
		music_slider.value = music_volume
	
	if sfx_slider:
		sfx_slider.value = sfx_volume
	
	if fullscreen_check:
		fullscreen_check.button_pressed = is_fullscreen
	
	if autosave_check:
		autosave_check.button_pressed = autosave_enabled
	
	# Update UI to match current difficulty
	_update_difficulty_buttons()

# Connect all UI signals
func _connect_signals():
	# Standard settings signals
	if hours_slider:
		hours_slider.value_changed.connect(_on_hours_slider_changed)
	
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)
	
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	if autosave_check:
		autosave_check.toggled.connect(_on_autosave_toggled)
	
	if reset_button:
		reset_button.pressed.connect(_on_reset_stats_pressed)
	
	if backup_button:
		backup_button.pressed.connect(_on_backup_pressed)
	
	if easy_button:
		easy_button.pressed.connect(func(): set_difficulty(0))
	
	if normal_button:
		normal_button.pressed.connect(func(): set_difficulty(1))
	
	if hard_button:
		hard_button.pressed.connect(func(): set_difficulty(2))
		
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Escape menu signals
	if escape_menu_overlay:
		if escape_settings_button:
			escape_settings_button.pressed.connect(_on_escape_settings_pressed)
		
		if escape_online_button:
			escape_online_button.pressed.connect(_on_online_pressed)
		
		if escape_save_exit_button:
			escape_save_exit_button.pressed.connect(_on_save_exit_pressed)
		
		if escape_resume_button:
			escape_resume_button.pressed.connect(hide_menu)

# Center panel in viewport with safety checks
func _center_in_viewport():
	_safe_center_in_viewport()

# New absolutely safe centering function
func _safe_center_in_viewport():
	# Add a small delay to ensure the viewport is ready
	await get_tree().create_timer(0.01).timeout
	
	# Get the viewport dimensions:
	var viewport_rect = get_viewport_rect()
	
	# Use a safe default size if our size is too small
	if size.x < 100 or size.y < 100:
		size = Vector2(800, 600)
		custom_minimum_size = Vector2(800, 600)
	
	# Calculate a safe center position
	var safe_x = max(0, (viewport_rect.size.x - size.x) / 2)
	var safe_y = max(0, (viewport_rect.size.y - size.y) / 2)
	var safe_pos = Vector2(safe_x, safe_y)
	
	# Apply the position
	position = safe_pos
	print("Settings: Centered at position: ", position)

# Check if we're called from escape menu
func is_in_escape_menu() -> bool:
	return is_escape_menu_mode

#region Escape Menu Functionality
# Show the menu and pause the game
func show_menu():
	visible = true
	
	# Ensure proper positioning to prevent transform errors
	_safe_center_in_viewport()
	
	if is_escape_menu_mode:
		if has_node("EscapeMenuOverlay"):
			escape_menu_overlay.visible = true
			# Hide the settings content
			if has_node("ScrollContainer"):
				$ScrollContainer.visible = false
			if has_node("SettingsTitle"):
				$SettingsTitle.visible = false	
			if close_button:
				close_button.visible = false
		
		get_tree().paused = true

# Hide the menu and resume the game
func hide_menu():
	if is_escape_menu_mode:
		if has_node("EscapeMenuOverlay"):
			# If we're showing settings, just go back to the main escape menu
			if $ScrollContainer.visible:
				$ScrollContainer.visible = false
				$SettingsTitle.visible = false
				$CloseButton.visible = false
				escape_menu_overlay.visible = true
				return
		
		get_tree().paused = false
	
	visible = false

# Called when escape key is pressed
func toggle_menu():
	# Use a timer to defer the toggle and prevent transform errors
	var timer = Timer.new()
	timer.wait_time = 0.01
	timer.one_shot = true
	timer.timeout.connect(_deferred_toggle_menu)
	add_child(timer)
	timer.start()

# Use deferred execution to avoid transform errors
func _deferred_toggle_menu():
	if visible:
		hide_menu()
	else:
		show_menu()

# Handle settings button press in escape menu
func _on_escape_settings_pressed():
	if has_node("EscapeMenuOverlay"):
		# Hide the escape menu overlay and show settings
		escape_menu_overlay.visible = false
		$ScrollContainer.visible = true
		$SettingsTitle.visible = true
		$CloseButton.visible = true

# Handle online button press
func _on_online_pressed():
	# Emit signal for online services
	emit_signal("online_services_requested")
	
	# Show a notification dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Online Services"
	dialog.dialog_text = "Online services are coming soon!"
	dialog.get_ok_button().text = "OK"
	add_child(dialog)
	dialog.popup_centered()

# Handle save and exit button press
func _on_save_exit_pressed():
	# Save the vivarium
	if vivarium_manager and vivarium_manager.has_method("save_vivarium"):
		vivarium_manager.save_vivarium()
	
	# Unpause before exiting
	get_tree().paused = false
	
	# Return to main menu
	if vivarium_manager and vivarium_manager.has_method("return_to_menu"):
		vivarium_manager.return_to_menu()
	else:
		# Fallback method
		get_tree().change_scene_to_file("res://modules/ui/main_menu.tscn")
#endregion

#region Settings functionality
# Update hours display with null check
func _update_hours_display(value):
	if hours_value:
		hours_value.text = "Today's Progress: " + str(today_productivity) + " / " + str(int(value)) + " hours"

# Handler for hours slider change
func _on_hours_slider_changed(value):
	productivity_hours = int(value)
	_update_hours_display(value)
	_save_settings()
	
	# Update in VivManager if available
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("set_productivity_target"):
		viv_manager.set_productivity_target(productivity_hours)

# Handler for music volume change
func _on_music_volume_changed(value):
	music_volume = value
	_apply_audio_settings()
	_save_settings()
	
	# Update in VivManager if available
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("set_music_volume"):
		viv_manager.set_music_volume(music_volume)

# Handler for SFX volume change
func _on_sfx_volume_changed(value):
	sfx_volume = value
	_apply_audio_settings()
	_save_settings()
	
	# Update in VivManager if available
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("set_sfx_volume"):
		viv_manager.set_sfx_volume(sfx_volume)

# Handler for fullscreen toggle
func _on_fullscreen_toggled(toggled):
	is_fullscreen = toggled
	_apply_video_settings()
	_save_settings()
	
	# Update in VivManager if available
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("set_fullscreen"):
		viv_manager.set_fullscreen(is_fullscreen)

# Handler for autosave toggle
func _on_autosave_toggled(toggled):
	autosave_enabled = toggled
	_save_settings()
	
	# Update in VivManager if available
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("set_auto_save"):
		viv_manager.auto_save = autosave_enabled

# Handler for reset stats button
func _on_reset_stats_pressed():
	# Show confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Reset Statistics"
	confirm_dialog.dialog_text = "Are you sure you want to reset all productivity statistics? This cannot be undone."
	confirm_dialog.get_ok_button().text = "Reset"
	confirm_dialog.get_cancel_button().text = "Cancel"
	
	# Connect confirmation signal
	confirm_dialog.confirmed.connect(func():
		# Reset productivity tracking
		today_productivity = 0.0
		_update_hours_display(productivity_hours)
		_save_settings()
		# Reset in VivManager if available
		var viv_manager = get_node_or_null("/root/VivManager")
		if viv_manager and viv_manager.has_method("reset_productivity"):
			viv_manager.record_productivity(-viv_manager.productivity_today)
			print("Reset productivity statistics")
	)
	
	# Add to scene and show
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

# Handler for backup button
func _on_backup_pressed():
	# TODO: Implement backup functionality
	print("Backup functionality not yet implemented")
	
	# Show a notification dialog
	var info_dialog = AcceptDialog.new()
	info_dialog.title = "Backup Information"
	info_dialog.dialog_text = "Your save data is located at:\n" + OS.get_user_data_dir() + "/saves/"
	info_dialog.get_ok_button().text = "OK"
	
	# Add to scene and show
	add_child(info_dialog)
	info_dialog.popup_centered()

# Apply audio settings
func _apply_audio_settings():
	# Get the AudioManager singleton
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		if audio_manager.has_method("set_music_volume"):
			audio_manager.set_music_volume(music_volume)
		if audio_manager.has_method("set_sfx_volume"):
			audio_manager.set_sfx_volume(sfx_volume)

# Apply video settings
func _apply_video_settings():
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# Set difficulty level
func set_difficulty(level: int):
	current_difficulty = level
	_update_difficulty_buttons()
	_save_settings()
	
	# Update in VivManager if available
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager and viv_manager.has_method("set_difficulty"):
		viv_manager.set_difficulty(level + 1) # +1 because our scale is 0-2, VivManager uses 1-3
	
	# Update any game_settings singleton if available
	var game_settings = get_node_or_null("/root/GameSettings")
	if game_settings and game_settings.has_method("set_difficulty"):
		game_settings.set_difficulty(level)

# Update difficulty button UI
func _update_difficulty_buttons():
	if easy_button and normal_button and hard_button:
		easy_button.button_pressed = (current_difficulty == 0)
		normal_button.button_pressed = (current_difficulty == 1)
		hard_button.button_pressed = (current_difficulty == 2)

# Handle close button press with awareness of escape menu
func _on_close_button_pressed():
	emit_signal("settings_closed")
	
	# Special case for main menu - just emit the signal and let the menu handle it
	if get_parent() and get_parent().name == "MainMenu":
		print("Settings: Closing from main menu")
		return
	
	# If we're in an escape menu, we should only close this panel or go back to the menu
	if is_in_escape_menu():
		if has_node("EscapeMenuOverlay") and $ScrollContainer.visible:
			# Go back to the escape menu
			$ScrollContainer.visible = false
			$SettingsTitle.visible = false
			$CloseButton.visible = false
			escape_menu_overlay.visible = true
		else:
			queue_free()
	else:
		# Normal behavior for standalone settings
		queue_free()

# Override _input to handle escape key differently when in escape menu
func _input(event):
	# Check for Escape key to close settings or toggle menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		print("Settings: Escape key detected")
		get_viewport().set_input_as_handled()
		
		if is_in_escape_menu():
			print("Settings: In escape menu mode")
			# If we're showing settings in escape menu, go back to main escape menu
			if has_node("EscapeMenuOverlay") and has_node("ScrollContainer") and $ScrollContainer.visible:
				$ScrollContainer.visible = false
				if has_node("SettingsTitle"):
					$SettingsTitle.visible = false
				if has_node("CloseButton"):
					$CloseButton.visible = false
				escape_menu_overlay.visible = true
			else:
				# Toggle the menu with a safe deferred call
				call_deferred("toggle_menu")
		else:
			# Normal behavior for standalone settings
			print("Settings: In standalone mode, closing")
			call_deferred("_on_close_button_pressed")
#endregion

#region Data Management
# Save settings to config file
func _save_settings():
	var config = ConfigFile.new()
	
	# Game settings
	config.set_value("game", "difficulty", current_difficulty)
	config.set_value("game", "productivity_hours", productivity_hours)
	config.set_value("game", "today_productivity", today_productivity)
	config.set_value("game", "autosave", autosave_enabled)
	
	# Audio settings
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	
	# Video settings
	config.set_value("video", "fullscreen", is_fullscreen)
	
	# Save the config file
	config.save("user://settings.cfg")

# Load settings from config file
func _load_settings():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	# If the file doesn't exist or has an error, use defaults
	if err != OK:
		return
	
	# Game settings
	current_difficulty = config.get_value("game", "difficulty", 1)
	productivity_hours = config.get_value("game", "productivity_hours", 8)
	today_productivity = config.get_value("game", "today_productivity", 0.0)
	autosave_enabled = config.get_value("game", "autosave", true)
	
	# Audio settings
	music_volume = config.get_value("audio", "music_volume", 0.5)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.7)
	
	# Video settings
	is_fullscreen = config.get_value("video", "fullscreen", false)
	
	# Apply loaded settings
	_apply_audio_settings()
	_apply_video_settings()
	
	# Update VivManager with loaded settings
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager:
		if viv_manager.has_method("set_difficulty"):
			viv_manager.set_difficulty(current_difficulty + 1) # +1 for conversion
		if viv_manager.has_method("set_productivity_target"):
			viv_manager.set_productivity_target(productivity_hours)
		if "auto_save" in viv_manager:
			viv_manager.auto_save = autosave_enabled
#endregion
