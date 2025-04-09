extends CanvasLayer

# VivUI1: Core UI Management and Hierarchy
# Consolidated from multiple scripts

# Export resource for animal scene (keep this since it's likely needed)
@export var animal_scene: PackedScene

#region Node references
var control_node: Control = null
var viv_button: Button = null
var viv_panel: Panel = null
var bio_tool_button: Button = null
var bio_tool_panel: Panel = null
var scape_tool_button: Button = null
var scape_tool_panel: Panel = null
var eco_tool_button: Button = null
var eco_tool_panel: Panel = null
var hierarchy_button: Button = null
var hierarchy_panel = null
var escape_menu = null
var active_naming_panel = null  # Reference to an open naming panel
var pending_animal_to_name = null  # Reference to animal waiting to be named

# Camera and system references
var vivarium: Node2D = null
var camera: Camera2D = null
var selected_animal: Node2D = null

# Error tracking
var initialization_errors = []
#endregion

#region Resource references
# Resource references
var animal_spawner = null
var animal_scenes = {
	"cherryshrimp": null,  # Will reference animal_scene from exports
	"dreamguppy": null     # Will reference animal_scene from exports
}

var plant_scenes = {
	# Add plant scenes when you have them
}

# New reference for the hierarchy panel scene
var hierarchy_panel_scene = preload("res://modules/ui/panels/hierarchy_panel.tscn")
var hierarchy_panel_instance = null

# Naming dialog reference
var active_naming_dialog = null

# Add missing center_dialog function
func center_dialog(dialog: Control) -> void:
	if !dialog:
		return
	
	# Get viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate center position
	var center_x = (viewport_size.x - dialog.size.x) / 2
	var center_y = (viewport_size.y - dialog.size.y) / 2
	
	# Set position
	dialog.position = Vector2(center_x, center_y)
#endregion

#region Viewport adjustment properties
var last_viewport_size: Vector2 = Vector2.ZERO
var initialized: bool = false
var _last_adjustment_time: int = 0
var _scene_change_counter: int = 0 # Ensure this is explicitly declared as int
#endregion

# Signals
signal animal_selected(animal)
signal animal_deselected(animal)

func _ready():
	print("VivUI: Starting initialization...")
	
	# Set up references from exported resources
	if animal_scene:
		animal_scenes["cherryshrimp"] = animal_scene
		animal_scenes["dreamguppy"] = animal_scene
	else:
		# Fallback to direct preload if scene reference is not set
		print("VivUI: WARNING - animal_scene not provided, using fallback preload")
		animal_scenes["cherryshrimp"] = preload("res://modules/animals/consolidated_animal.tscn")
		animal_scenes["dreamguppy"] = preload("res://modules/animals/consolidated_animal.tscn")
	
	# Wrap initialization in try/catch to prevent crashes
	_safe_initialize()
	
	# Set up viewport adjustment
	_setup_viewport_adjuster()
	
	# Connect to animal manager signals with proper error checking
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if animal_manager:
		if animal_manager.has_signal("animal_naming_requested"):
			if !animal_manager.is_connected("animal_naming_requested", Callable(self, "show_animal_bio_panel_for_naming")):
				animal_manager.connect("animal_naming_requested", Callable(self, "show_animal_bio_panel_for_naming"))
				print("VivUI1: Connected to animal_naming_requested signal")
		else:
			print("VivUI1: WARNING - AnimalManager doesn't have animal_naming_requested signal")
	else:
		print("VivUI1: WARNING - Could not find AnimalManager singleton")
	
	# Add to viv_ui1 group for easier reference
	add_to_group("viv_ui1")
	
	# Set up camera references
	camera = get_viewport().get_camera_2d()

# Safe initialization to prevent crashes
func _safe_initialize():
	# Get control node
	control_node = get_node_or_null("Control")
	if !control_node:
		print("VivUI: CRITICAL - Control node not found!")
		initialization_errors.append("Control node not found")
		return
	
	# Get basic references with updated paths
	viv_button = control_node.get_node_or_null("VivButton")
	viv_panel = control_node.get_node_or_null("VivPanel")
	
	# Report success or failure
	if viv_button:
		print("VivUI: Successfully found VivButton")
	else:
		print("VivUI: CRITICAL - VivButton not found!")
		initialization_errors.append("VivButton not found")
	
	if viv_panel:
		print("VivUI: Successfully found VivPanel")
	else:
		print("VivUI: CRITICAL - VivPanel not found!")
		initialization_errors.append("VivPanel not found")
	
	# Get panel nodes with updated paths
	if viv_panel:
		bio_tool_button = viv_panel.get_node_or_null("BioToolButton")
		scape_tool_button = viv_panel.get_node_or_null("ScapeToolButton")
		eco_tool_button = viv_panel.get_node_or_null("EcoButton")
		hierarchy_button = viv_panel.get_node_or_null("HierarchyButton")
		
		if bio_tool_button:
			bio_tool_panel = bio_tool_button.get_node_or_null("BioToolPanel")
		if scape_tool_button:
			scape_tool_panel = scape_tool_button.get_node_or_null("ScapeToolPanel")
		if eco_tool_button:
			eco_tool_panel = eco_tool_button.get_node_or_null("EcoToolPanel")
		if hierarchy_button and hierarchy_button.has_node("HierarchyPanel"):
			hierarchy_panel = hierarchy_button.get_node_or_null("HierarchyPanel")
	
	# Get escape menu reference
	escape_menu = get_tree().get_root().find_child("EscapeMenu", true, false)
	if !escape_menu:
		print("VivUI: Could not find EscapeMenu")
	
	# Connect button signals
	_connect_buttons()
	
	# Set initial panel states
	if viv_panel:
		viv_panel.visible = false
	
	# Hide all subpanels
	if bio_tool_panel: bio_tool_panel.visible = false
	if scape_tool_panel: scape_tool_panel.visible = false
	if eco_tool_panel: eco_tool_panel.visible = false
	if hierarchy_panel: hierarchy_panel.visible = false
	
	# Find system nodes - both lowercase and normal case for compatibility
	_find_system_nodes()
	
	# Report completion status
	if initialization_errors.size() > 0:
		print("VivUI: Initialization completed with " + str(initialization_errors.size()) + " errors")
		for err in initialization_errors:
			print("VivUI: Error: " + err)
	else:
		print("VivUI: Initialization complete (success)")

#region Viewport adjustment
func _setup_viewport_adjuster():
	print("ViewportAdjuster: Initializing...")
	
	# Connect to scene change signal
	get_tree().root.connect("size_changed", _on_viewport_size_changed)
	
	# Perform initial adjustment
	_adjust_ui_elements(true)
	
	initialized = true
	print("ViewportAdjuster: Initialization complete")

func _on_viewport_size_changed():
	if initialized:
		# Throttle adjustments
		_scene_change_counter += 1
		if _scene_change_counter % 3 == 0:
			print("ViewportAdjuster: Viewport size changed, adjusting UI")
		_adjust_ui_elements()

func _adjust_ui_elements(is_initial: bool = false) -> void:
	var current_viewport_size = get_viewport().get_visible_rect().size
	
	# Skip adjustment if viewport size hasn't changed and we've initialized
	if current_viewport_size == last_viewport_size && initialized && !is_initial:
		return
		
	# Store the new viewport size
	last_viewport_size = current_viewport_size
	_last_adjustment_time = Time.get_ticks_msec()
	
	# Adjust camera if needed
	_adjust_camera()
	
	# Find important UI elements that need adjustment
	var dialogs = []
	
	# Get the current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		# Find dialogs that need centering
		dialogs = _find_dialogs(current_scene)
		
		# Center any dialogs found
		for dialog in dialogs:
			# Center dialogs in the viewport
			_center_dialog(dialog)
	
	# Record timing for performance tracking
	var elapsed = Time.get_ticks_msec() - _last_adjustment_time
	if elapsed > 100:
		print("ViewportAdjuster: Adjustment took " + str(elapsed) + "ms")

func _adjust_camera() -> Camera2D:
	# Try to find the main camera
	var camera_node = get_viewport().get_camera_2d()
	return camera_node

func _find_dialogs(node: Node) -> Array:
	var dialogs = []
	
	# Search for Panel nodes with specific names or properties
	if node is Panel and (
		node.name == "NewVivariumDialog" or
		node.name == "ConfirmDialog" or
		node.name == "LoadingDialog" or
		(node.name.ends_with("Dialog") and node.get_parent() is Control)
	):
		dialogs.append(node)
	
	# Recursively search children, but limit depth to avoid excessive logging
	for child in node.get_children():
		# Only recurse into containers and controls
		if child is Control:
			dialogs.append_array(_find_dialogs(child))
			
	return dialogs

func _center_dialog(dialog: Control) -> void:
	if !dialog:
		return
		
	# Get viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate center position
	var center_x = (viewport_size.x - dialog.size.x) / 2
	var center_y = (viewport_size.y - dialog.size.y) / 2
	
	# Set position
	dialog.position = Vector2(center_x, center_y)
#endregion

# Find system nodes safely
func _find_system_nodes():
	# Try to find the vivarium node
	var root = get_tree().get_root()
	if root:
		vivarium = root.find_child("vivarium", true, false)
		if not vivarium:
			vivarium = root.find_child("Vivarium", true, false)
	
	# Try to find the camera
	camera = get_viewport().get_camera_2d()
	if not camera and vivarium:
		camera = vivarium.find_child("Camera2D", true, false)
		
	# Get animal_manager instead of creating animal_spawner
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if !animal_manager:
		push_error("VivUI1: Could not find AnimalManager singleton")

# Connect all buttons
func _connect_buttons():
	# Safely connect buttons
	_safe_connect_button(viv_button, _toggle_main_panel, "VivButton toggle")
	_safe_connect_button(bio_tool_button, _toggle_bio_panel, "BioToolButton toggle")
	_safe_connect_button(scape_tool_button, _toggle_scape_panel, "ScapeToolButton toggle")
	_safe_connect_button(eco_tool_button, _toggle_eco_panel, "EcoToolButton toggle")
	_safe_connect_button(hierarchy_button, _toggle_hierarchy_panel, "HierarchyButton toggle")
	
	# Connect animal spawn buttons if they exist
	if bio_tool_panel:
		_safe_connect_button(bio_tool_panel.get_node_or_null("AnimalButton"), 
			_toggle_animal_menu, "AnimalButton toggle")
		_safe_connect_button(bio_tool_panel.get_node_or_null("PlantButton"), 
			_toggle_plant_menu, "PlantButton toggle")
		_safe_connect_button(bio_tool_panel.get_node_or_null("ShrimpButton"), 
			_spawn_cherry_shrimp, "ShrimpButton click")
		_safe_connect_button(bio_tool_panel.get_node_or_null("GuppyButton"), 
			_spawn_dream_guppy, "GuppyButton click")
	
	# Look for a settings button
	var settings_button = viv_panel.get_node_or_null("SettingsButton") if viv_panel else null
	_safe_connect_button(settings_button, _on_settings_button_pressed, "SettingsButton")
	
	# Set all buttons to use mouse click action mode only
	_configure_button_inputs()

# Helper to safely connect buttons
func _safe_connect_button(button, callback, description):
	if button:
		# Disconnect any existing connections to prevent duplicates
		if button.is_connected("pressed", callback):
			button.disconnect("pressed", callback)
		# Connect new signal
		button.pressed.connect(callback)
		print("VivUI: Connected " + description)

# Configure all buttons to only respond to mouse clicks
func _configure_button_inputs():
	# Collect all buttons from the UI hierarchy
	var all_buttons = _find_all_buttons(self)
	
	# Configure each button to ignore spacebar
	for button in all_buttons:
		if button is Button:
			button.focus_mode = Control.FOCUS_NONE  # Prevent keyboard focus
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE  # Only respond to clicks
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # Better cursor feedback
	
	print("VivUI: Configured " + str(all_buttons.size()) + " buttons to ignore spacebar")

# Recursively find all buttons in this UI tree
func _find_all_buttons(node: Node) -> Array:
	var buttons = []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_find_all_buttons(child))
	
	return buttons

# Panel toggle functions
func _toggle_main_panel():
	print("VivUI: Main panel toggle triggered!")
	if viv_panel:
		viv_panel.visible = !viv_panel.visible
		print("VivUI: Main panel visibility now: " + str(viv_panel.visible))

func _toggle_bio_panel():
	print("VivUI: Bio panel toggled")
	if bio_tool_panel:
		bio_tool_panel.visible = !bio_tool_panel.visible

func _toggle_scape_panel():
	print("VivUI: Scape panel toggled")
	if scape_tool_panel:
		scape_tool_panel.visible = !scape_tool_panel.visible
		if scape_tool_panel.visible:
			# Initialize scape tool UI elements when panel becomes visible
			_initialize_scape_tool_ui()

# Initialize the scape tool UI controls
func _initialize_scape_tool_ui():
	if !scape_tool_panel:
		return
	
	# Find VivUI2
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		# Try to find the registry to get VivUI2
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	# Setup brush button
	var brush_button = scape_tool_panel.get_node_or_null("BrushButton")
	if !brush_button:
		# Try creating it if not found
		brush_button = Button.new()
		brush_button.name = "BrushButton"
		brush_button.text = "Brush"
		brush_button.position = Vector2(10, 10)
		brush_button.size = Vector2(80, 30)
		scape_tool_panel.add_child(brush_button)
	
	if brush_button:
		if !brush_button.pressed.is_connected(_on_brush_button_pressed):
			brush_button.pressed.connect(_on_brush_button_pressed)
	else:
		print("VivUI1: BrushButton not found in ScapeToolPanel")
	
	# Setup pen button
	var pen_button = scape_tool_panel.get_node_or_null("PenButton")
	if !pen_button:
		# Try creating it if not found
		pen_button = Button.new()
		pen_button.name = "PenButton"
		pen_button.text = "Pen"
		pen_button.position = Vector2(100, 10)
		pen_button.size = Vector2(80, 30)
		scape_tool_panel.add_child(pen_button)
	
	if pen_button:
		if !pen_button.pressed.is_connected(_on_pen_button_pressed):
			pen_button.pressed.connect(_on_pen_button_pressed)
	else:
		print("VivUI1: PenButton not found in ScapeToolPanel")
	
	# Setup size slider
	var size_slider = scape_tool_panel.get_node_or_null("SizeSlider")
	if !size_slider:
		# Try creating it if not found
		size_slider = HSlider.new()
		size_slider.name = "SizeSlider"
		size_slider.position = Vector2(10, 50)
		size_slider.size = Vector2(270, 20)
		size_slider.min_value = 5.0
		size_slider.max_value = 100.0
		size_slider.step = 5.0
		var size_label = Label.new()
		size_label.text = "Size"
		size_label.position = Vector2(10, 30)
		scape_tool_panel.add_child(size_label)
		scape_tool_panel.add_child(size_slider)
	
	if size_slider:
		if !size_slider.value_changed.is_connected(_on_size_slider_changed):
			size_slider.value_changed.connect(_on_size_slider_changed)
			# Set initial value
			if viv_ui2 and "brush_size" in viv_ui2:
				size_slider.value = viv_ui2.brush_size
	else:
		print("VivUI1: SizeSlider not found in ScapeToolPanel")
	
	# Setup strength slider
	var strength_slider = scape_tool_panel.get_node_or_null("StrengthSlider")
	if !strength_slider:
		# Try creating it if not found
		strength_slider = HSlider.new()
		strength_slider.name = "StrengthSlider"
		strength_slider.position = Vector2(10, 100)
		strength_slider.size = Vector2(270, 20)
		strength_slider.min_value = 0.1
		strength_slider.max_value = 2.0
		strength_slider.step = 0.1
		var strength_label = Label.new()
		strength_label.text = "Strength" 
		strength_label.position = Vector2(10, 80)
		scape_tool_panel.add_child(strength_label)
		scape_tool_panel.add_child(strength_slider)
	
	if strength_slider:
		if !strength_slider.value_changed.is_connected(_on_strength_slider_changed):
			strength_slider.value_changed.connect(_on_strength_slider_changed)
			# Set initial value
			if viv_ui2 and "brush_strength" in viv_ui2:
				strength_slider.value = viv_ui2.brush_strength
	else:
		print("VivUI1: StrengthSlider not found in ScapeToolPanel")

# Handle brush button press
func _on_brush_button_pressed():
	print("VivUI1: Brush tool selected")
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		# Try to find the registry to get VivUI2
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	if viv_ui2 and viv_ui2.has_method("set_scape_tool_mode"):
		viv_ui2.set_scape_tool_mode(0) # 0 for brush mode
		viv_ui2.activate_scape_tool()

# Handle pen button press
func _on_pen_button_pressed():
	print("VivUI1: Pen tool selected")
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		# Try to find the registry to get VivUI2
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	if viv_ui2 and viv_ui2.has_method("set_scape_tool_mode"):
		viv_ui2.set_scape_tool_mode(1) # 1 for pen mode
		viv_ui2.activate_scape_tool()

# Handle size slider change
func _on_size_slider_changed(value):
	print("VivUI1: Brush size changed to: " + str(value))
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		# Try to find the registry to get VivUI2
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	if viv_ui2 and viv_ui2.has_method("set_brush_size"):
		viv_ui2.set_brush_size(value)

# Handle strength slider change
func _on_strength_slider_changed(value):
	print("VivUI1: Brush strength changed to: " + str(value))
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		# Try to find the registry to get VivUI2
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	if viv_ui2 and viv_ui2.has_method("set_brush_strength"):
		viv_ui2.set_brush_strength(value)

func _toggle_eco_panel():
	print("VivUI: Eco panel toggled")
	if eco_tool_panel:
		eco_tool_panel.visible = !eco_tool_panel.visible
		if eco_tool_panel.visible and eco_tool_panel.has_node("BackgroundOption"):
			# Setup background options if panel becomes visible
			var background_option = eco_tool_panel.get_node("BackgroundOption")
			if !background_option.item_selected.is_connected(_on_background_selected):
				# Connect the item selection if not already connected
				background_option.item_selected.connect(_on_background_selected)

# Handle background selection
func _on_background_selected(index: int):
	var background_option = eco_tool_panel.get_node_or_null("BackgroundOption")
	if background_option:
		var background_name = background_option.get_item_text(index)
		print("VivUI: Selected background: " + background_name)
		
		# Find VivUI2
		var viv_ui2 = get_node_or_null("/root/VivUI2")
		if !viv_ui2:
			# Try to find the registry to get VivUI2
			var global_registry = get_node_or_null("/root/Registry")
			if global_registry and global_registry.has_method("get_viv_ui2"):
				viv_ui2 = global_registry.get_viv_ui2()
		
		# Forward background request to VivUI2
		if viv_ui2 and viv_ui2.has_method("set_background"):
			viv_ui2.set_background(background_name)
		else:
			print("VivUI1: Could not find VivUI2 to set background")

#region Hierarchy Panel Management
func _toggle_hierarchy_panel():
	print("VivUI: Hierarchy panel toggled")
	# Always use the embedded hierarchy panel first if it exists
	if hierarchy_panel:
		hierarchy_panel.visible = !hierarchy_panel.visible
		print("VivUI: Using embedded hierarchy panel, visibility: " + str(hierarchy_panel.visible))
		return
	
	# Otherwise try to use the standalone panel with error handling
	if hierarchy_panel_instance and is_instance_valid(hierarchy_panel_instance):
		hierarchy_panel_instance.visible = !hierarchy_panel_instance.visible
		if hierarchy_panel_instance.visible:
			if hierarchy_panel_instance.has_method("populate_tree"):
				hierarchy_panel_instance.populate_tree()
	else:
		_create_hierarchy_panel()

# Create the standalone hierarchy panel with safety checks
func _create_hierarchy_panel():
	# Only create if needed
	if hierarchy_panel_instance and is_instance_valid(hierarchy_panel_instance):
		print("VivUI: Hierarchy panel already exists")
		return
		
	print("VivUI: Creating hierarchy panel instance")
	
	# Use the preloaded scene
	if hierarchy_panel_scene == null:
		# Try to load the scene
		hierarchy_panel_scene = load("res://modules/ui/panels/hierarchy.tscn")
		if hierarchy_panel_scene == null:
			print("VivUI: ERROR - Could not load hierarchy panel scene")
			return
	
	# Create panel instance
	hierarchy_panel_instance = hierarchy_panel_scene.instantiate()
	if control_node:
		# Add to the UI layer
		control_node.add_child(hierarchy_panel_instance)
		var viewport_size = get_viewport().get_visible_rect().size
		# Position and configure the panel
		hierarchy_panel_instance.position = Vector2(viewport_size.x - 400, 100)
		# Connect signals
		if hierarchy_panel_instance.has_signal("panel_closed"):
			if hierarchy_panel_instance.is_connected("panel_closed", Callable(self, "_on_hierarchy_panel_closed")):
				hierarchy_panel_instance.disconnect("panel_closed", Callable(self, "_on_hierarchy_panel_closed"))
			hierarchy_panel_instance.panel_closed.connect(Callable(self, "_on_hierarchy_panel_closed"))
		# Make visible initially
		hierarchy_panel_instance.visible = true
		print("VivUI: Hierarchy panel created at position: " + str(hierarchy_panel_instance.position))
	else:
		print("VivUI: ERROR - Could not create hierarchy panel, no control node!")

# Handler for when hierarchy panel is closed
func _on_hierarchy_panel_closed():
	print("VivUI: Hierarchy panel was closed")
	if hierarchy_panel_instance and is_instance_valid(hierarchy_panel_instance):
		hierarchy_panel_instance.visible = false
#endregion

# Menu toggle functions
func _toggle_animal_menu():
	# Implementation will go here
	pass

func _toggle_plant_menu():
	# Implementation will go here
	pass

# Animal spawning functions
func _spawn_cherry_shrimp():
	print("VivUI: Attempting to spawn Cherry Shrimp")
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if animal_manager and vivarium:
		# Get mouse position
		var mouse_pos = get_viewport().get_mouse_position()
		# Get world position - using get_canvas_transform from the viewport
		var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
		
		# Use the animal_manager to spawn the Cherry Shrimp with proper error handling
		var animal = null
		if animal_manager.has_method("spawn_cherry_shrimp"):
			animal = animal_manager.spawn_cherry_shrimp(world_pos)
			if animal:
				print("VivUI: Cherry Shrimp spawned at: " + str(world_pos))
			else:
				push_error("VivUI: Animal manager returned null animal")
		else:
			push_error("VivUI: Animal manager missing spawn_cherry_shrimp method")
	else:
		push_error("VivUI: Could not spawn Cherry Shrimp - missing animal_manager or vivarium")

func _spawn_dream_guppy():
	print("VivUI: Attempting to spawn Dream Guppy")
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if animal_manager and vivarium:
		# Get mouse position
		var mouse_pos = get_viewport().get_mouse_position()
		# Get world position - using get_canvas_transform from the viewport
		var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
		
		# Use the animal_manager to spawn the Dream Guppy with proper error handling
		var animal = null
		if animal_manager.has_method("spawn_dream_guppy"):
			animal = animal_manager.spawn_dream_guppy(world_pos)
			if animal:
				print("VivUI: Dream Guppy spawned at: " + str(world_pos))
			else:
				push_error("VivUI: Animal manager returned null animal")
		else:
			push_error("VivUI: Animal manager missing spawn_dream_guppy method")
	else:
		push_error("VivUI: Could not spawn Dream Guppy - missing animal_manager or vivarium")

# Common animal spawning with error handling - Deprecated in favor of animal_spawner
func _spawn_animal(animal_key: String):
	print("VivUI: Using deprecated _spawn_animal method. Use animal_spawner instead.")
	if !animal_scenes.has(animal_key) or !vivarium:
		print("VivUI: Can't spawn animal - missing resources")
		return
	
	# Create animal
	var animal = animal_scenes[animal_key].instantiate()
	if animal.has_method("_initialize_species"):
		if animal_key == "cherryshrimp":
			animal.species_type = "Cherry Shrimp"
		elif animal_key == "dreamguppy":
			animal.species_type = "Dream Guppy"
	
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	# Get world position - using get_canvas_transform from the viewport instead
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
	animal.position = world_pos
	
	# Find animals container
	var animals_container = vivarium.get_node_or_null("Animals") 
	if animals_container:
		animals_container.add_child(animal)
	else:
		# Fall back to adding directly to vivarium
		vivarium.add_child(animal)
		
	print("VivUI: Animal spawned at: " + str(animal.position))
	
	# Update hierarchy panel after a frame delay
	if hierarchy_panel_instance and hierarchy_panel_instance.visible:
		await get_tree().process_frame
		if hierarchy_panel_instance.has_method("populate_tree"):
			hierarchy_panel_instance.populate_tree()

# Open escape menu - safe implementation
func toggle_escape_menu():
	print("VivUI1: Toggle escape menu requested")
	# Create settings panel directly instead of using the helper
	show_settings()

# Process Input - handle Escape key - MODIFIED to prevent escape from closing naming dialog
func _input(event):
	# Check for escape key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Only toggle escape menu if we're not naming an animal
		if !active_naming_dialog or !is_instance_valid(active_naming_dialog):
			# Toggle escape menu
			toggle_escape_menu()
			# Mark the event as handled to prevent other nodes from processing it
			get_viewport().set_input_as_handled()

# Enhanced animal selection functionality - MODIFIED to check if animal is named first
func select_animal(animal):
	# Only allow selecting named animals
	if !animal.has_been_named():
		print("VivUI1: Not selecting unnamed animal")
		return
	
	if selected_animal == animal:
		# If clicking the same animal again, just show the panel
		show_animal_bio_panel(animal)
		return
		
	if selected_animal:
		deselect_animal()
	
	selected_animal = animal
	emit_signal("animal_selected", animal)
	
	# Show animal info panel
	show_animal_bio_panel(animal)
	
	# Focus camera on this animal
	focus_camera_on_animal(animal)
	
	# Highlight the animal
	if animal.has_method("select"):
		animal.select()
	elif animal.has_method("set_selected"):
		animal.set_selected(true)

# Deselect the currently selected animal
func deselect_animal():
	if !selected_animal:
		return
		
	# Call deselect on the animal if it has the method
	if selected_animal.has_method("deselect"):
		selected_animal.deselect()
	elif selected_animal.has_method("set_selected"):
		selected_animal.set_selected(false)
	
	# Emit deselected signal
	emit_signal("animal_deselected", selected_animal)
	
	# Clear selected animal reference
	selected_animal = null
	
	print("VivUI1: Animal deselected")

# Function to handle when user cancels naming
func _cancel_naming_process():
	# Unpause the game
	get_tree().paused = false
	
	if pending_animal_to_name and is_instance_valid(pending_animal_to_name):
		# Get animal manager and request removal of unnamed animal
		var animal_manager = get_node_or_null("/root/AnimalManager")
		if animal_manager and animal_manager.has_method("remove_unnamed_animal"):
			animal_manager.remove_unnamed_animal(pending_animal_to_name)
			pending_animal_to_name = null
	
	# Close the panel
	if active_naming_panel and is_instance_valid(active_naming_panel):
		active_naming_panel.queue_free()
		active_naming_panel = null

# Focus and track the camera on a specific animal
func focus_camera_on_animal(animal):
	if !camera or !animal or !is_instance_valid(animal):
		return
	
	# Set camera to follow this animal
	var camera_manager = camera if camera.has_method("set_follow_target") else null
	if !camera_manager:
		camera_manager = get_node_or_null("/root/CameraManager")
	
	if camera_manager and camera_manager.has_method("set_follow_target"):
		print("VivUI1: Setting camera to follow " + animal.get_creature_name())
		camera_manager.set_follow_target(animal)
		
		# Also zoom in on the animal
		if camera_manager.has_method("zoom_to_target"):
			camera_manager.zoom_to_target(animal, 0.6)  # 60% zoom level
	elif camera:
		# Fallback - move camera directly if no manager available
		camera.global_position = animal.global_position

# Show animal bio panel with naming interface - MODIFIED to use a naming dialog instead
func show_animal_bio_panel_for_naming(animal):
	print("VivUI1: Opening naming dialog for " + animal.get_creature_name())
	
	# Check for existing panels and remove them
	_close_existing_animal_panels()
	
	# Store reference to the animal being named
	pending_animal_to_name = animal
	
	# Focus camera on the animal without selecting it yet
	focus_camera_on_animal(animal)
	
	# Use the dedicated naming dialog
	show_naming_dialog(animal)
	
	# Pause the game while naming an animal to ensure user completes it
	get_tree().paused = true

# Show naming dialog for the given animal - IMPROVED implementation
func show_naming_dialog(animal = null):
	print("VivUI1: Showing naming dialog")
	# Check if a dialog is already active
	if active_naming_dialog and is_instance_valid(active_naming_dialog):
		active_naming_dialog.queue_free()
	
	# Create a dedicated naming dialog
	var dialog = Panel.new()
	dialog.name = "NamingDialog"
	dialog.size = Vector2(400, 200)
	
	# Create title
	var title = Label.new()
	title.text = "Name Your " + animal.species_type
	title.position = Vector2(20, 20)
	title.size = Vector2(360, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(title)
	
	# Create name input
	var name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "Enter a name..."
	name_input.position = Vector2(50, 70)
	name_input.size = Vector2(300, 40)
	dialog.add_child(name_input)
	
	# Set initial focus to text field to make typing immediate
	name_input.call_deferred("grab_focus")
	
	# Add random name button
	var random_button = Button.new()
	random_button.text = "Random"
	random_button.position = Vector2(50, 120)
	random_button.size = Vector2(90, 30)
	random_button.pressed.connect(func():
		if animal.has_method("generate_name_suggestion"):
			name_input.text = animal.generate_name_suggestion()
			# Set cursor to end of text
			name_input.caret_column = name_input.text.length()
	)
	dialog.add_child(random_button)
	
	# Create buttons
	var confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.position = Vector2(200, 120)
	confirm_button.size = Vector2(100, 30)
	dialog.add_child(confirm_button)
	
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(310, 120)
	cancel_button.size = Vector2(90, 30)
	dialog.add_child(cancel_button)
	
	# Connect signals
	confirm_button.pressed.connect(func(): 
		if name_input.text.strip_edges().is_empty():
			# Alert about empty name not allowed
			var alert = AcceptDialog.new()
			alert.title = "Naming Error"
			alert.dialog_text = "Please provide a name for your " + animal.species_type
			control_node.add_child(alert)
			alert.popup_centered()
		else:
			# Set the name and close
			animal.set_creature_name(name_input.text)
			animal.is_named = true
			pending_animal_to_name = null
			dialog.queue_free()
			active_naming_dialog = null
			# Unpause the game after naming is completed
			get_tree().paused = false
	)
	
	cancel_button.pressed.connect(func(): 
		_cancel_naming_process()
		dialog.queue_free()
		active_naming_dialog = null
	)
	
	# Add to UI
	if control_node:
		control_node.add_child(dialog)
	active_naming_dialog = dialog
	
	# Center dialog
	center_dialog(dialog)
	
	# Generate initial random name
	if animal.has_method("generate_name_suggestion"):
		name_input.text = animal.generate_name_suggestion()
		# Set cursor to end of text
		name_input.caret_column = name_input.text.length()
	
	return dialog

# Show regular bio panel for viewing
func show_animal_bio_panel(animal):
	print("VivUI1: Showing animal info panel for " + animal.get_creature_name())
	
	# Check for existing panels and remove them
	_close_existing_animal_panels()
	
	# Focus camera on the animal
	focus_camera_on_animal(animal)
	
	# Try to load the proper animal_bio_panel scene
	var bio_panel_scene = load("res://modules/ui/panels/animal_bio_panel.tscn")
	if bio_panel_scene:
		var bio_panel = bio_panel_scene.instantiate()
		if bio_panel:
			# Add panel to the control node
			if control_node:
				control_node.add_child(bio_panel)
				
			# Configure the panel
			bio_panel.set_animal(animal)
			bio_panel.set_follow_animal(true) # Make panel follow the animal
			
			# Position the panel initially
			_position_panel_near_animal(bio_panel, animal)
			
			return bio_panel
	
	# Fallback to simple info panel
	print("VivUI1: Could not load animal_bio_panel scene, using fallback")
	return _create_simple_info_panel(animal)

# Create a simple info panel as fallback
func _create_simple_info_panel(animal):
	# Create the panel
	var panel = Panel.new()
	panel.name = "AnimalInfoPanel"
	panel.size = Vector2(500, 400)
	
	# Create the title
	var title = Label.new()
	title.text = animal.get_creature_name() + " - " + animal.species_type
	title.position = Vector2(20, 20)
	title.size = Vector2(460, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	
	# Create tab container
	var tab_container = TabContainer.new()
	tab_container.position = Vector2(20, 60)
	tab_container.size = Vector2(460, 280)
	panel.add_child(tab_container)
	
	# Create needs tab
	var needs_tab = _create_needs_tab(animal)
	needs_tab.name = "Needs"
	tab_container.add_child(needs_tab)
	
	# Create custom tab
	var custom_tab = _create_custom_tab(animal)
	custom_tab.name = "Custom"
	tab_container.add_child(custom_tab)
	
	# Create info tab
	var info_tab = _create_info_tab(animal)
	info_tab.name = "Info"
	tab_container.add_child(info_tab)
	
	# Add close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(200, 350)
	close_button.size = Vector2(100, 40)
	close_button.pressed.connect(func(): panel.queue_free())
	panel.add_child(close_button)
	
	# Add to UI
	if control_node:
		control_node.add_child(panel)
	
	# Center the panel
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2
	
	return panel

# Helper function to close any existing animal panels
func _close_existing_animal_panels():
	# Find and close any existing animal bio panels
	var existing_panels = []
	
	# Find AnimalBioPanel nodes
	if control_node:
		for child in control_node.get_children():
			if child.name == "AnimalBioPanel" or child.name.begins_with("AnimalInfoPanel") or child.name.begins_with("AnimalNamingBioPanel") or child.name == "NamingDialog":
				existing_panels.append(child)
		
		# Close the panels
		for panel in existing_panels:
			panel.queue_free()
	
	# Also clear active_naming_panel reference if it was freed
	if active_naming_panel and not is_instance_valid(active_naming_panel):
		active_naming_panel = null
	
	if active_naming_dialog and not is_instance_valid(active_naming_dialog):
		active_naming_dialog = null

# Helper function to position panel near animal with proper offset
func _position_panel_near_animal(panel: Control, animal: Node2D):
	if not panel or not animal:
		return
		
	# Calculate screen position of the animal
	var viewport_transform = get_viewport().get_canvas_transform()
	var screen_position = viewport_transform * animal.global_position
	
	# Add offset to the right of the animal
	var offset = Vector2(30, -panel.size.y / 2)
	panel.position = screen_position + offset
	
	# Keep panel within screen bounds
	var viewport_size = get_viewport().get_visible_rect().size
	if panel.position.x < 10:
		panel.position.x = 10
	if panel.position.y < 10:
		panel.position.y = 10
	if panel.position.x + panel.size.x > viewport_size.x - 10:
		panel.position.x = viewport_size.x - panel.size.x - 10
	if panel.position.y + panel.size.y > viewport_size.y - 10:
		panel.position.y = viewport_size.y - panel.size.y - 10

# Create the info tab content - Fix for Integer Division Warnings
func _create_info_tab(animal) -> Control:
	var tab = Control.new()
	
	# Container for information
	var info_container = VBoxContainer.new()
	info_container.position = Vector2(10, 10)
	info_container.size = Vector2(440, 240)
	tab.add_child(info_container)
	
	# Species information
	var species_label = Label.new()
	species_label.text = "Species: " + animal.species_type
	info_container.add_child(species_label)
	
	# Age information
	var age_hours = animal.age * 24  # Convert days to hours
	var age_days = int(floor(animal.age))
	var age_months = int(floor(float(age_days) / 30.0)) # Fix integer division
	var age_years = int(floor(float(age_months) / 12.0)) # Fix integer division
	
	var remaining_months = age_months % 12
	var remaining_days = age_days % 30
	var remaining_hours = int(floor(age_hours - (age_days * 24)))
	
	var age_text = ""
	if age_years > 0:
		age_text += str(age_years) + " years, "
	if remaining_months > 0 or age_years > 0:
		age_text += str(remaining_months) + " months, "
	if remaining_days > 0 or remaining_months > 0 or age_years > 0:
		age_text += str(remaining_days) + " days, "
	age_text += str(remaining_hours) + " hours"
	
	var age_label = Label.new()
	age_label.text = "Age: " + age_text
	info_container.add_child(age_label)
	
	# Add age state
	var age_state_label = Label.new()
	age_state_label.text = "Life Stage: " + animal.age_state.capitalize()
	info_container.add_child(age_state_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	info_container.add_child(spacer)
	
	# Add feeding type
	var feeding_type = "Unknown"
	match animal.feeding_type:
		0: feeding_type = "Carnivore"
		1: feeding_type = "Herbivore"
		2: feeding_type = "Omnivore"
		3: feeding_type = "Detritivore"
		4: feeding_type = "Filter Feeder"
	
	var feeding_label = Label.new()
	feeding_label.text = "Diet: " + feeding_type
	info_container.add_child(feeding_label)
	
	# Add environmental preferences
	var env_prefs = "Environmental Preferences: "
	if animal.environment_prefs.is_empty():
		env_prefs += "None"
	else:
		var prefs = []
		for pref in animal.environment_prefs:
			match pref:
				0: prefs.append("Open Water")
				1: prefs.append("Plant Cover")
				2: prefs.append("Rocks")
				3: prefs.append("Caves")
				4: prefs.append("Surface")
				5: prefs.append("Substrate")
		env_prefs += ", ".join(prefs)
	
	var env_label = Label.new()
	env_label.text = env_prefs
	info_container.add_child(env_label)
	
	# Add wiki button
	var wiki_button = Button.new()
	wiki_button.text = "Visit VivOS Wiki"
	wiki_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wiki_button.custom_minimum_size = Vector2(150, 40)
	wiki_button.pressed.connect(func(): _show_external_link_warning("https://antipwr.github.io", animal.species_type))
	
	# Add some space before the button
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 20)
	info_container.add_child(button_spacer)
	
	info_container.add_child(wiki_button)
	
	return tab

# Create the needs tab content based on Planet Zoo's system
func _create_needs_tab(animal) -> Control:
	var tab = Control.new()
	
	# Create scrollable container for needs
	var scroll_container = ScrollContainer.new()
	scroll_container.size = Vector2(440, 260)
	scroll_container.position = Vector2(10, 10)
	tab.add_child(scroll_container)
	
	# Create vertical container for needs bars
	var needs_container = VBoxContainer.new()
	needs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(needs_container)
	
	# Add health need
	_add_need_bar(needs_container, "Health", animal.health, 100, Color(0.2, 0.8, 0.2))
	
	# Add hunger need (inverse of hunger value, as lower hunger is better)
	_add_need_bar(needs_container, "Nutrition", 100 - animal.hunger, 100, Color(0.9, 0.6, 0.1))
	
	# Add satisfaction need
	_add_need_bar(needs_container, "Happiness", animal.satisfaction, 100, Color(0.2, 0.6, 0.9))
	
	# Add environment needs based on species
	match animal.species_type:
		"Cherry Shrimp":
			_add_need_bar(needs_container, "Water Quality", 85, 100, Color(0.4, 0.7, 0.9))
			_add_need_bar(needs_container, "Plant Cover", 70, 100, Color(0.3, 0.8, 0.3))
			_add_need_bar(needs_container, "Social", 65, 100, Color(0.9, 0.4, 0.8))
		"Dream Guppy":
			_add_need_bar(needs_container, "Swimming Space", 90, 100, Color(0.5, 0.7, 0.9))
			_add_need_bar(needs_container, "Enrichment", 60, 100, Color(0.9, 0.8, 0.3))
			_add_need_bar(needs_container, "Social", 75, 100, Color(0.9, 0.4, 0.8))
		_:
			_add_need_bar(needs_container, "Habitat", 80, 100, Color(0.7, 0.7, 0.3))
	
	# Add feed button
	var feed_button = Button.new()
	feed_button.text = "Feed"
	feed_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	feed_button.pressed.connect(func(): _feed_animal(animal))
	needs_container.add_child(feed_button)
	
	# Add spacer at bottom
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	needs_container.add_child(spacer)
	
	return tab

# Helper function to add need bars
func _add_need_bar(container, label_text, current_value, max_value, bar_color):
	var label = Label.new()
	label.text = label_text
	container.add_child(label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.max_value = max_value
	progress_bar.value = current_value
	progress_bar.show_percentage = true
	
	# Set bar color
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bar_color
	progress_bar.add_theme_stylebox_override("fill", style_box)
	
	container.add_child(progress_bar)
	
	# Add description of need status
	var status_label = Label.new()
	status_label.text = _get_need_status_text(current_value, max_value)
	container.add_child(status_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	container.add_child(spacer)

# Get descriptive text for need status
func _get_need_status_text(value, max_value):
	var percentage = (value / max_value) * 100
	if percentage >= 90:
		return "Excellent"
	elif percentage >= 75:
		return "Good"
	elif percentage >= 50:
		return "Average"
	elif percentage >= 25:
		return "Poor"
	else:
		return "Critical"

# Create the custom tab content (placeholder)
func _create_custom_tab(_animal) -> Control:
	var tab = Control.new()
	
	var label = Label.new()
	label.text = "Customization options will be available here.\nStay tuned for future updates!"
	label.position = Vector2(20, 20)
	label.size = Vector2(400, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(label)
	
	var placeholder = Label.new()
	placeholder.text = "Coming Soon"
	placeholder.position = Vector2(20, 100)
	placeholder.size = Vector2(400, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(placeholder)
	
	return tab

# Show species information
func _show_species_info(species_type: String):
	print("VivUI1: Showing species info for " + species_type)
	
	# Find VivUI2
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	# Use VivUI2 to show info
	if viv_ui2 and viv_ui2.has_method("show_species_info"):
		viv_ui2.show_species_info(species_type)
	else:
		print("VivUI1: Could not find VivUI2 to show species info")

# Show external link warning
func _show_external_link_warning(url: String, species_name: String):
	print("VivUI1: Showing external link warning for " + url)
	
	# Find VivUI2
	var viv_ui2 = get_node_or_null("/root/VivUI2")
	if !viv_ui2:
		var global_registry = get_node_or_null("/root/Registry")
		if global_registry and global_registry.has_method("get_viv_ui2"):
			viv_ui2 = global_registry.get_viv_ui2()
	
	# Use VivUI2 to show warning
	if viv_ui2 and viv_ui2.has_method("show_external_link_warning"):
		viv_ui2.show_external_link_warning(url, species_name)
	else:
		# Create a simple dialog as fallback
		_create_simple_link_warning(url, species_name)

# Create a simple link warning dialog
func _create_simple_link_warning(url: String, species_name: String):
	var dialog = AcceptDialog.new()
	dialog.title = "External Link"
	
	# Use the species_name in the dialog text if provided
	var dialog_text = "You are about to visit an external website:"
	if species_name != "":
		dialog_text = "You are about to visit the " + species_name + " wiki page:"
	
	dialog.dialog_text = dialog_text + "\n" + url + "\n\nDo you want to continue?"
	dialog.add_button("Cancel", true, "cancel")
	dialog.add_button("Continue", false, "continue")
	
	dialog.confirmed.connect(func(): OS.shell_open(url))
	control_node.add_child(dialog)
	dialog.popup_centered()

# Feed the animal
func _feed_animal(animal):
	if animal.has_method("feed"):
		animal.feed()
		print("VivUI1: Fed " + animal.get_creature_name())
	else:
		print("VivUI1: Cannot feed this animal")

# Check if naming dialog feature is available - now just checks if we can create our own
func has_naming_dialog_available():
	return true # We always can create a simple naming dialog directly

# Add a new button handler for settings
func _on_settings_button_pressed():
	print("VivUI1: Settings button pressed")
	show_settings()

# New function to show settings
func show_settings():
	print("VivUI1: Showing settings panel")
	
	# Check if there's already a settings panel
	var existing_panel = get_tree().get_root().find_child("Settings", true, false)
	if existing_panel:
		print("VivUI1: Using existing settings panel")
		existing_panel.visible = true
		return existing_panel
	
	# Load the settings scene
	var settings_scene = load("res://modules/ui/settings.tscn")
	if settings_scene:
		var settings_panel = settings_scene.instantiate()
		if settings_panel:
			settings_panel.name = "Settings"
			# Add panel to scene tree
			get_tree().get_root().add_child(settings_panel)
			
			# Center the panel
			var viewport_size = get_viewport().get_visible_rect().size
			var panel_size = settings_panel.size
			settings_panel.position = (viewport_size - panel_size) / 2
			
			print("VivUI1: Created settings panel")
			return settings_panel
	
	print("VivUI1: Failed to create settings panel")
	return null
