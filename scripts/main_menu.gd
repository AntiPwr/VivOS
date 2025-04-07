extends Control

# Comprehensive Main Menu Script - consolidated from main_menu.gd and settings_ui.gd

#region UI References
# Main menu references
@onready var saves_list = $VBoxContainer/MenuPanel/MenuContainer/SavesList
@onready var load_button = $VBoxContainer/MenuPanel/MenuContainer/ButtonsContainer/LoadButton
@onready var delete_button = $VBoxContainer/MenuPanel/MenuContainer/ButtonsContainer/DeleteButton
@onready var new_button = $VBoxContainer/MenuPanel/MenuContainer/ButtonsContainer/NewButton
@onready var quit_button = $VBoxContainer/MenuPanel/MenuContainer/QuitButton
@onready var title = $Title
@onready var subtitle = $Subtitle

# Dialog references
@onready var new_vivarium_dialog = $NewVivariumDialog
@onready var confirm_dialog = $ConfirmDialog
@onready var name_input = $NewVivariumDialog/VBoxContainer/NameInput

# Settings references
@onready var settings_button = $SettingsButton
@onready var settings_overlay = $SettingsOverlay

# Settings scene reference
var settings_scene = preload("res://scenes/settings.tscn")
var active_settings_panel = null
#endregion

#region State Variables
# Save system reference
var save_system
var settings_visible = false
#endregion

func _ready():
	# Get reference to the VivariumManager autoload 
	save_system = get_node("/root/VivariumManager")
	
	if not save_system:
		push_error("Main Menu: Could not find VivariumManager autoload. Check project settings.")
		# Create a fallback empty array for saves list
		var empty_array = []
		_refresh_saves_list_fallback(empty_array)
	
	# Force proper size and layout
	_setup_ui_layout()
	
	# Update subtitle text
	if subtitle:
		subtitle.text = "Your Second-Mind Vivarium!"
	
	# Apply custom font styling - use Syne for titles
	var theme_manager = get_node_or_null("/root/ThemeManager")
	if theme_manager:
		if title:
			theme_manager.apply_heading_style(title, "Large")
		if subtitle:
			theme_manager.apply_heading_style(subtitle, "Medium")
	
	# Connect signals only when UI components are found
	if _verify_ui_components():
		_connect_signals()
	
		# Load the saved vivariums
		_refresh_saves_list()
	
	# Initially hide dialogs
	if new_vivarium_dialog:
		new_vivarium_dialog.visible = false
		# Center the dialog in the viewport
		_center_dialog(new_vivarium_dialog)
		
	if confirm_dialog:
		confirm_dialog.visible = false
		# Center the dialog in the viewport
		_center_dialog(confirm_dialog)
	
	# Connect the settings button
	if settings_button:
		# We no longer need to connect here as it's handled in _connect_signals
		pass
	
	# Update background and adjust UI for better visibility
	_setup_background()
	
	print("MainMenu: Ready complete")

# Input handler for keyboard shortcuts
func _input(event):
	# Check for Escape key to toggle settings, but only if settings are already active
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if active_settings_panel and is_instance_valid(active_settings_panel):
			_close_settings()
			get_viewport().set_input_as_handled()
		# Do not handle escape key otherwise in main menu

#region Main Menu Core Functions
# Center a dialog panel in the viewport
func _center_dialog(dialog_panel: Control):
	if !dialog_panel:
		return
	
	# Ensure the dialog has a valid size before positioning
	if dialog_panel.size.x <= 1 || dialog_panel.size.y <= 1:
		# Set a larger default size for better readability
		var default_size = Vector2(600, 400)  # Increased from 400x300
		dialog_panel.custom_minimum_size = default_size
		dialog_panel.size = default_size
		print("MainMenu: Dialog had invalid size, set to default: ", default_size)
	
	# Get the viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate the center position
	var center_pos = (viewport_size - dialog_panel.size) / 2
	
	# Set the dialog position to be centered
	dialog_panel.position = center_pos
	
	print("MainMenu: Centered dialog at position ", dialog_panel.position, " with size ", dialog_panel.size)

# Verify that all required UI components are found
func _verify_ui_components() -> bool:
	var all_valid = true
	
	# Check all critical components
	if !saves_list:
		push_error("SavesList not found! Check the scene hierarchy.")
		all_valid = false
		
	if !load_button:
		push_error("LoadButton not found! Check the scene hierarchy.")
		all_valid = false
		
	if !delete_button:
		push_error("DeleteButton not found! Check the scene hierarchy.")
		all_valid = false
		
	if !new_button:
		push_error("NewButton not found! Check the scene hierarchy.")
		all_valid = false
		
	if !quit_button:
		push_error("QuitButton not found! Check the scene hierarchy.")
		all_valid = false
		
	# Only print children hierarchy in debug mode
	if OS.is_debug_build() and !all_valid:
		print("MainMenu children hierarchy:")
		_print_children(self, 0)
	
	return all_valid

# Helper to print the node hierarchy
func _print_children(node: Node, indent: int = 0):
	var indent_str = ""
	for i in range(indent):
		indent_str += "    "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_children(child, indent + 1)

# Set up UI layout - ensuring proper positioning
func _setup_ui_layout():
	# Get viewport dimensions
	var viewport_size = get_viewport().get_visible_rect().size
	print("MainMenu: Viewport size is ", viewport_size)
	
	# Use anchors for proper sizing instead of directly setting size
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Reset any offsets
	position = Vector2.ZERO
	
	# Connect to viewport resize events - only if not already connected
	if !get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	
	print("MainMenu: UI layout set up")
	
	# Center the dialogs in the viewport
	if new_vivarium_dialog:
		_center_dialog(new_vivarium_dialog)
	
	if confirm_dialog:
		_center_dialog(confirm_dialog)

# Connect all signals
func _connect_signals():
	print("MainMenu: Connecting signals...")
	
	# Connect button signals
	if new_button:
		new_button.pressed.connect(_on_new_button_pressed)
		print("Connected NewButton")
	
	if load_button:
		load_button.pressed.connect(_on_load_button_pressed)
		print("Connected LoadButton")
	
	if delete_button:
		delete_button.pressed.connect(_on_delete_button_pressed)
		print("Connected DeleteButton")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		print("Connected QuitButton")
	
	# Connect settings button with extra error handling
	if settings_button:
		# Disconnect any existing connections to prevent duplicates
		if settings_button.pressed.is_connected(_on_settings_button_pressed):
			settings_button.pressed.disconnect(_on_settings_button_pressed)
			print("Disconnected existing settings button connection")
		
		# Connect with error handling
		settings_button.pressed.connect(_on_settings_button_pressed)
		print("Connected SettingsButton with enhanced error handling")
	else:
		push_error("Settings button not found!")
	
	# Connect new vivarium dialog signals if dialog exists
	if new_vivarium_dialog:
		var new_dialog_create = new_vivarium_dialog.get_node_or_null("VBoxContainer/HBoxContainer/CreateButton")
		var new_dialog_cancel = new_vivarium_dialog.get_node_or_null("VBoxContainer/HBoxContainer/CancelButton")
		
		if new_dialog_create:
			new_dialog_create.pressed.connect(_on_create_button_pressed)
			print("Connected CreateButton")
			
		if new_dialog_cancel:
			new_dialog_cancel.pressed.connect(_on_cancel_new_dialog)
			print("Connected CancelButton")
	
	# Connect confirm dialog signals if dialog exists
	if confirm_dialog:
		var confirm_dialog_confirm = confirm_dialog.get_node_or_null("VBoxContainer/HBoxContainer/ConfirmButton")
		var confirm_dialog_cancel = confirm_dialog.get_node_or_null("VBoxContainer/HBoxContainer/CancelButton")
		
		if confirm_dialog_confirm:
			confirm_dialog_confirm.pressed.connect(_on_confirm_delete)
			print("Connected ConfirmButton")
			
		if confirm_dialog_cancel:
			confirm_dialog_cancel.pressed.connect(_on_cancel_confirm_dialog)
			print("Connected CancelButton")
	
	# Connect saves list signal
	if saves_list:
		saves_list.item_selected.connect(_on_saves_list_item_selected)
		print("Connected SavesList item_selected")
	
	print("MainMenu: All signals connected")

# Handle viewport resizing
func _on_viewport_resized():
	print("MainMenu: Viewport resized")
	
	# Let anchors handle the resizing - no need to manually set size
	_setup_ui_layout()
	
	# Center settings panel if active
	if active_settings_panel and is_instance_valid(active_settings_panel):
		_center_dialog(active_settings_panel)

# Refresh the list of saved vivariums
func _refresh_saves_list():
	# Clear current list
	saves_list.clear()
	
	# Get saved vivariums - with null check
	if save_system and save_system.has_method("get_saved_vivariums"):
		var saved_vivariums = save_system.get_saved_vivariums()
		
		# Add to list or show placeholder
		if saved_vivariums.size() > 0:
			for viv_name in saved_vivariums:
				saves_list.add_item(viv_name)
			# Initially disable load/delete buttons
			load_button.disabled = true
			delete_button.disabled = true
		else:
			saves_list.add_item("No saved vivariums found")
			load_button.disabled = true
			delete_button.disabled = true
	else:
		# Fallback when save system doesn't have the method
		saves_list.add_item("No saved vivariums found")
		load_button.disabled = true
		delete_button.disabled = true
		push_error("Main Menu: VivManager doesn't have get_saved_vivariums method")

# Fallback function when save system isn't found
func _refresh_saves_list_fallback(_saved_vivariums):
	# Clear current list
	saves_list.clear()
	
	# Add empty placeholder
	saves_list.add_item("No saved vivariums found")
	load_button.disabled = true
	delete_button.disabled = true
#endregion

#region Button Handlers
func _on_new_button_pressed():
	print("New button pressed")
	if new_vivarium_dialog and name_input:
		# Hide the main menu panel but keep the title and subtitle visible
		$VBoxContainer/MenuPanel.visible = false
		
		# Show and setup the new vivarium dialog
		name_input.text = ""
		new_vivarium_dialog.visible = true
		
		# Ensure dialog is centered in the viewport
		_center_dialog(new_vivarium_dialog)
		
		name_input.grab_focus()

func _on_load_button_pressed():
	var selected_idx = saves_list.get_selected_items()
	if selected_idx.size() > 0:
		var vivarium_name = saves_list.get_item_text(selected_idx[0])
		_load_vivarium(vivarium_name)

func _on_delete_button_pressed():
	print("Delete button pressed")
	var selected_idx = saves_list.get_selected_items()
	if selected_idx.size() > 0:
		var vivarium_name = saves_list.get_item_text(selected_idx[0])
		print("Confirming deletion of: " + vivarium_name)
		
		if confirm_dialog:
			# Update the confirmation message
			var label = confirm_dialog.get_node_or_null("VBoxContainer/Label")
			if label:
				label.text = "Are you sure you want to delete the vivarium '" + vivarium_name + "'?"
			
			# Hide the menu panel but keep the title and subtitle visible
			$VBoxContainer/MenuPanel.visible = false
			
			# Show the confirmation dialog and ensure it's centered
			confirm_dialog.visible = true
			_center_dialog(confirm_dialog)

func _on_quit_button_pressed():
	get_tree().quit()

# Show settings panel and hide main menu content
func _on_settings_button_pressed():
	print("Settings button pressed")
	
	# Use the global settings manager instead of creating our own
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("show_settings"):
		# Hide main menu content before showing settings
		$VBoxContainer.visible = false
		$Title.visible = false
		$Subtitle.visible = false
		
		# Show overlay to dim the background
		if settings_overlay:
			settings_overlay.visible = true
		
		# Show settings and connect to close signal
		var settings_panel = settings_manager.show_settings()
		if settings_panel and !settings_manager.is_connected("settings_closed", _on_settings_closed):
			settings_manager.connect("settings_closed", _on_settings_closed)
	else:
		# Fallback to old method
		_create_settings_panel_deferred()

func _on_settings_closed():
	print("Settings closed, restoring main menu")
	
	# Show main menu content again
	$VBoxContainer.visible = true
	$Title.visible = true
	$Subtitle.visible = true
	
	# Hide overlay
	if settings_overlay:
		settings_overlay.visible = false
	
	# Disconnect from settings manager if needed
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.is_connected("settings_closed", _on_settings_closed):
		settings_manager.disconnect("settings_closed", _on_settings_closed)

# Create settings panel in a deferred way to prevent crashes
func _create_settings_panel_deferred():
	print("Creating settings panel (deferred)")
	
	# Verify the scene is valid
	if settings_scene == null:
		print("ERROR: Settings scene is null, attempting to load from path")
		settings_scene = load("res://scenes/settings.tscn")
		if settings_scene == null:
			print("FATAL ERROR: Could not load settings scene")
			# Restore main menu UI since we can't show settings
			$VBoxContainer.visible = true
			$Title.visible = true
			$Subtitle.visible = true
			if settings_overlay:
				settings_overlay.visible = false
			return
	
	print("Settings scene loaded, instantiating...")
	
	# Create the panel with error handling
	var panel = null
	
	if settings_scene.can_instantiate():
		panel = settings_scene.instantiate()
		if panel == null:
			print("ERROR: Failed to instantiate settings panel")
			# Restore main menu UI
			$VBoxContainer.visible = true
			$Title.visible = true
			$Subtitle.visible = true
			if settings_overlay:
				settings_overlay.visible = false
			return
	else:
		print("ERROR: Settings scene cannot be instantiated")
		# Restore main menu UI
		$VBoxContainer.visible = true
		$Title.visible = true
		$Subtitle.visible = true
		if settings_overlay:
			settings_overlay.visible = false
		return
	
	# Store panel reference before adding to scene tree
	active_settings_panel = panel
	panel.name = "Settings" # Keep consistent name
	print("Settings panel instantiated successfully")
	
	# Add panel to scene tree
	add_child(panel)
	print("Settings panel added to scene tree")
	
	# Ensure the panel has a safe size
	if !panel.size || panel.size.x < 10 || panel.size.y < 10:
		panel.custom_minimum_size = Vector2(800, 600)
		panel.size = Vector2(800, 600)
		print("Fixed panel size to " + str(panel.size))
	
	# Position the panel safely after a short delay
	await get_tree().create_timer(0.05).timeout
	_finish_settings_panel_setup(panel)

# Finish panel setup after it's been properly added to scene
func _finish_settings_panel_setup(panel):
	if !is_instance_valid(panel):
		print("Panel is no longer valid during setup")
		return
		
	# Position the panel safely
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	panel.position = (viewport_size - panel_size) / 2
	print("Panel positioned at: " + str(panel.position))
	
	# Connect signals with careful error checking
	if panel.has_signal("settings_closed"):
		if !panel.is_connected("settings_closed", Callable(self, "_on_settings_closed")):
			panel.connect("settings_closed", Callable(self, "_on_settings_closed"))
			print("Connected to settings_closed signal")
	else:
		print("WARNING: settings_closed signal not found")
		
		# As a fallback, find and connect to the close button directly
		var close_button = panel.get_node_or_null("CloseButton")
		if close_button:
			if !close_button.is_connected("pressed", Callable(self, "_on_settings_closed")):
				close_button.pressed.connect(Callable(self, "_on_settings_closed"))
				print("Connected close button directly")
				
	print("Settings panel setup complete")

# Close the settings panel and restore the main menu
func _close_settings():
	if active_settings_panel and is_instance_valid(active_settings_panel):
		active_settings_panel.queue_free()
		active_settings_panel = null
	
	# Hide overlay
	if settings_overlay:
		settings_overlay.visible = false
	
	# Show main menu content again
	$VBoxContainer.visible = true
	$Title.visible = true
	$Subtitle.visible = true
	
	settings_visible = false
	print("Settings panel closed")

# Set up background and ensure UI elements are visible against it
func _setup_background():
	# Get references to background elements
	var background = get_node_or_null("Background")
	var overlay = get_node_or_null("OverlayGradient")
	
	# Ensure background is visible and properly sized
	if background:
		background.anchor_right = 1.0
		background.anchor_bottom = 1.0
		# Use valid enum values for TextureRect
		background.expand = true  # Using the expand boolean property instead of enum
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		print("MainMenu: Background set up")
	
	# Ensure overlay gradient is visible to improve text contrast
	if overlay:
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		print("MainMenu: Overlay gradient set up")

# Dialog handlers
func _on_create_button_pressed():
	print("Create button pressed")
	if name_input and name_input.text.strip_edges() != "":
		var vivarium_name = name_input.text.strip_edges()
		print("Creating new vivarium: " + vivarium_name)
		
		# Hide dialog
		new_vivarium_dialog.visible = false
		
		# Pass the name to VivManager instead of GlobalData
		var viv_manager = get_node_or_null("/root/VivManager")
		if viv_manager:
			viv_manager.set_vivarium_name(vivarium_name)
		else:
			print("WARNING: VivManager singleton not found")
		
		# Show a loading indicator
		var loading_label = Label.new()
		loading_label.text = "Loading..."
		loading_label.add_theme_font_size_override("font_size", 32)
		loading_label.set_anchors_preset(Control.PRESET_CENTER)
		add_child(loading_label)
		
		# Defer the scene change to avoid camera errors during scene transition
		call_deferred("_safe_change_scene", "res://scenes/vivarium.tscn")
	else:
		print("No name provided")

# Safe scene change method
func _safe_change_scene(scene_path: String):
	# Wait a frame to ensure UI updates have happened
	await get_tree().process_frame
	
	# Change scene safely
	get_tree().change_scene_to_file(scene_path)

func _on_cancel_new_dialog():
	print("Create vivarium canceled")
	if new_vivarium_dialog:
		# Hide the new vivarium dialog
		new_vivarium_dialog.visible = false
		
		# Show the main menu panel again
		$VBoxContainer/MenuPanel.visible = true

func _on_confirm_delete():
	print("Delete confirmed")
	var selected_idx = saves_list.get_selected_items()
	if selected_idx.size() > 0:
		var vivarium_name = saves_list.get_item_text(selected_idx[0])
		
		# Delete the vivarium
		if save_system:
			var success = save_system.delete_vivarium(vivarium_name)
			if success:
				print("Deleted vivarium: " + vivarium_name)
				_refresh_saves_list()
			else:
				print("Failed to delete vivarium: " + vivarium_name)
		
		# Hide the confirmation dialog and show the menu panel
		confirm_dialog.visible = false
		$VBoxContainer/MenuPanel.visible = true

func _on_cancel_confirm_dialog():
	print("Delete canceled")
	
	# Hide the confirmation dialog and show the menu panel
	if confirm_dialog:
		confirm_dialog.visible = false
		$VBoxContainer/MenuPanel.visible = true

# Selection handler
func _on_saves_list_item_selected(index):
	var text = saves_list.get_item_text(index)
	if text != "No saved vivariums found":
		load_button.disabled = false
		delete_button.disabled = false
	else:
		load_button.disabled = true
		delete_button.disabled = true
#endregion

#region Vivarium Management
# Create a new vivarium
func _create_new_vivarium(vivarium_name):
	# Store the name in VivManager instead of GlobalData
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager:
		viv_manager.set_vivarium_name(vivarium_name)
	else:
		print("WARNING: VivManager singleton not found")
	
	# Go to the vivarium scene
	get_tree().change_scene_to_file("res://scenes/vivarium.tscn")

# Load an existing vivarium
func _load_vivarium(vivarium_name):
	# Store the name in VivManager instead of GlobalData
	var viv_manager = get_node_or_null("/root/VivManager")
	if viv_manager:
		viv_manager.set_vivarium_name(vivarium_name)
	else:
		print("WARNING: VivManager singleton not found")
	
	# Go to the vivarium scene
	get_tree().change_scene_to_file("res://scenes/vivarium.tscn")
#endregion

# Show naming dialog for the given animal
func show_naming_dialog(_animal = null):
	print("VivUI1: Showing naming dialog")

# Handle when a name is confirmed
func _on_name_confirmed(animal_name):
	print("VivUI1: Name confirmed: " + animal_name)

# Handle when naming dialog is closed
func _on_naming_dialog_closed():
	print("VivUI1: Naming dialog closed")
