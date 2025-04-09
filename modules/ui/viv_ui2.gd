extends Node

# VivUI2: Tools and panels management
# Handles specialized functionality while VivUI1 manages core UI

# Settings scene reference
@export var settings_panel_scene: PackedScene
# If not exported, try to load it at runtime
var _settings_scene = null

# Remove all exports for non-existent scenes

#region Specialized UI Resources
# Active UI instances
var active_info_panel = null
var active_bio_ui = null
var active_naming_dialog = null
var active_external_link_warning = null
var active_settings = null  # Reference to active settings panel
#endregion

#region System References
var vivarium: Node2D = null
var camera: Camera2D = null
var viv_ui: CanvasLayer = null  # Reference to VivUI1
#endregion

#region Tools States
# Bio Tool
var bio_tool_active = false

# Scape Tool
var scape_tool_active = false
var current_scape_tool: int = 0  # 0: Brush, 1: Pen, 2: Shape
var brush_size: float = 20.0
var brush_strength: float = 1.0
var brush_material: String = "Sand"
var gravity_enabled: bool = true
var is_applying: bool = false
var last_apply_position: Vector2 = Vector2.ZERO

# Eco Tool
var eco_tool_active = false
var background_options = {
	"Glass Background": "res://assets/backgrounds/glass_background.png",
	"Jungle Background": "res://assets/backgrounds/jungle_background.png"
}
var background_sprite: Sprite2D = null
#endregion

# Species database for info panel
var species_database = {
	"Cherry Shrimp": {
		"image": "res://assets/Cherry Shrimp.png",
		"scientific_name": "Neocaridina davidi",
		"description": "Cherry shrimp (Neocaridina davidi) are small freshwater shrimp known for their bright red coloration. They originated from Taiwan and are one of the most popular invertebrates in the aquarium hobby due to their vibrant colors, peaceful nature, and beneficial algae-eating habits.",
		"care": "[b]Tank Size:[/b] Minimum 5 gallons\n[b]Temperature:[/b] 65-85°F (18-29°C)\n[b]pH:[/b] 6.5-8.0\n[b]GH:[/b] 4-8 dGH\n[b]TDS:[/b] 150-250 ppm\n[b]Diet:[/b] Omnivorous - algae, biofilm, plant matter, and commercial shrimp foods\n[b]Lifespan:[/b] 1-2 years\n\nCherry shrimp are relatively easy to care for, making them excellent for beginners. They thrive in planted tanks with plenty of hiding spaces like moss, driftwood, and live plants. Avoid copper-based medications as they are toxic to all invertebrates.",
		"facts": "• Cherry shrimp come in different color grades, with higher grades having more solid, intense coloration\n• They are excellent tank cleaners, consuming algae and detritus\n• Females are typically larger and more colorful than males\n• They breed readily in captivity without special conditions\n• A female shrimp can carry 20-30 eggs at once\n• Young shrimp are fully formed miniature versions of adults\n• They molt regularly as they grow, leaving behind a transparent exoskeleton"
	},
	"Dream Guppy": {
		"image": "res://assets/Dreamfish.png",
		"scientific_name": "Poecilia phantasma",
		"description": "The Dream Guppy (Poecilia phantasma) is a mesmerizing fantasy fish species known for its ethereal appearance and unique ability to change colors based on its mood and surroundings. First discovered in the mythical crystalline waters of the Lumina Depths, these fish have fins that seem to flow like liquid silk, refracting light in hypnotic patterns that are said to induce vivid dreams in those who observe them for prolonged periods.",
		"care": "[b]Tank Size:[/b] Minimum 10 gallons\n[b]Temperature:[/b] 72-82°F (22-28°C)\n[b]pH:[/b] 7.0-8.2\n[b]Moonlight Exposure:[/b] Requires at least 4 hours of moonlight or simulated moonlight per night\n[b]Diet:[/b] Specialized diet including standard tropical flakes supplemented with 'dream dust' (a mixture of spirulina, daphnia, and crushed flower petals)\n[b]Lifespan:[/b] 3-5 years\n\nDream Guppies require tanks with open swimming areas combined with plenty of hiding spots. They are particularly fond of plants that flower underwater. A small piece of amethyst or quartz in the tank is believed to enhance their color-changing abilities. They are social fish and should be kept in groups of at least 5, with a ratio of 2-3 females to each male.",
		"facts": "• Dream Guppies produce a subtle bioluminescence when kept in total darkness\n• Their color patterns are unique to each individual, like fingerprints\n• They perform an elaborate 'dream dance' during mating rituals\n• Legends say that keeping Dream Guppies near your bedside can protect against nightmares\n• They communicate with each other through patterns of light reflected from their scales\n• Once a year, they enter a 'dream state' where they appear to sleep for 2-3 days while hovering in place\n• Their scales are highly prized for making dreamcatchers in certain cultures"
	}
}

# Signals
signal tool_activated(tool_name)
signal tool_deactivated(tool_name)
signal animal_interacted(animal, action)
signal material_applied(position, material_type, size)

#region Settings References and Variables
# Settings state
var current_difficulty = 1  # 0: Easy, 1: Normal, 2: Hard
var music_volume = 0.5
var sfx_volume = 0.7
var is_fullscreen = false
var productivity_hours = 8
var today_productivity = 0.0

# Settings accessibility
var settings_panel_visible = false
var active_settings_panel = null
#endregion

#region Scape Tool Properties
# Enhanced scape tool properties
const BRUSH_MODE = 0
const PEN_MODE = 1

# Textures (loaded dynamically)
var sand_texture = null
var current_material_texture = null

# Brush properties
var brush_min_size = 5.0
var brush_max_size = 100.0
var brush_size_increment = 5.0

# Layer management
var terrain_system = null
var sand_layer = null
var material_layers = {}

# Material properties
enum MaterialType {
	SAND = 0
}

var material_colors = {
	MaterialType.SAND: Color(0.9, 0.8, 0.5, 1.0) # Sand color
}

var material_names = {
	MaterialType.SAND: "Sand"
}

var current_material_type = MaterialType.SAND
#endregion

# Class for Bio Animal Panel
class BioAnimalPanel extends Panel:
	# References to UI elements
	var name_label: Label
	var species_label: Label
	var health_bar: ProgressBar
	var satisfaction_bar: ProgressBar
	var hunger_bar: ProgressBar
	var name_edit: LineEdit
	var confirm_button: Button
	var animal: Node # Reference to the animal
	var parent_ui: Node # Reference to VivUI2
	
	# Initialize the panel
	func _init():
		# Set up panel properties
		custom_minimum_size = Vector2(300, 400)
		size_flags_horizontal = SIZE_FILL
		size_flags_vertical = SIZE_FILL
		
		# Create a VBox to hold all content
		var vbox = VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.custom_minimum_size = Vector2(280, 380)
		vbox.position = Vector2(10, 10)
		add_child(vbox)
		
		# Add header
		var header = Label.new()
		header.text = "Animal Information"
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 18)
		vbox.add_child(header)
		
		# Add species info
		species_label = Label.new()
		species_label.text = "Species: Unknown"
		vbox.add_child(species_label)
		
		# Add name section
		var name_hbox = HBoxContainer.new()
		name_hbox.size_flags_horizontal = SIZE_FILL
		vbox.add_child(name_hbox)
		
		var name_title = Label.new()
		name_title.text = "Name: "
		name_hbox.add_child(name_title)
		
		name_edit = LineEdit.new()
		name_edit.placeholder_text = "Enter name..."
		name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
		name_hbox.add_child(name_edit)
		
		# Add name confirmation button
		confirm_button = Button.new()
		confirm_button.text = "Confirm Name"
		vbox.add_child(confirm_button)
		
		# Add stats section
		vbox.add_child(HSeparator.new())
		
		var stats_label = Label.new()
		stats_label.text = "Stats"
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_label)
		
		# Health bar
		var health_hbox = HBoxContainer.new()
		health_hbox.size_flags_horizontal = SIZE_FILL
		vbox.add_child(health_hbox)
		
		var health_label = Label.new()
		health_label.text = "Health: "
		health_label.custom_minimum_size = Vector2(60, 0)
		health_hbox.add_child(health_label)
		
		health_bar = ProgressBar.new()
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = 100
		health_bar.size_flags_horizontal = SIZE_EXPAND_FILL
		health_hbox.add_child(health_bar)
		
		# Satisfaction bar
		var satisfaction_hbox = HBoxContainer.new()
		satisfaction_hbox.size_flags_horizontal = SIZE_FILL
		vbox.add_child(satisfaction_hbox)
		
		var satisfaction_label = Label.new()
		satisfaction_label.text = "Happy: "
		satisfaction_label.custom_minimum_size = Vector2(60, 0)
		satisfaction_hbox.add_child(satisfaction_label)
		
		satisfaction_bar = ProgressBar.new()
		satisfaction_bar.min_value = 0
		satisfaction_bar.max_value = 100
		satisfaction_bar.value = 100
		satisfaction_bar.size_flags_horizontal = SIZE_EXPAND_FILL
		satisfaction_hbox.add_child(satisfaction_bar)
		
		# Hunger bar
		var hunger_hbox = HBoxContainer.new()
		hunger_hbox.size_flags_horizontal = SIZE_FILL
		vbox.add_child(hunger_hbox)
		
		var hunger_label = Label.new()
		hunger_label.text = "Hunger: "
		hunger_label.custom_minimum_size = Vector2(60, 0)
		hunger_hbox.add_child(hunger_label)
		
		hunger_bar = ProgressBar.new()
		hunger_bar.min_value = 0
		hunger_bar.max_value = 100
		hunger_bar.value = 0
		hunger_bar.size_flags_horizontal = SIZE_EXPAND_FILL
		hunger_hbox.add_child(hunger_bar)
		
		# Action buttons
		vbox.add_child(HSeparator.new())
		
		var buttons_hbox = HBoxContainer.new()
		buttons_hbox.size_flags_horizontal = SIZE_FILL
		vbox.add_child(buttons_hbox)
		
		var feed_button = Button.new()
		feed_button.text = "Feed"
		feed_button.size_flags_horizontal = SIZE_EXPAND_FILL
		feed_button.pressed.connect(func(): _on_feed_pressed())
		buttons_hbox.add_child(feed_button)
		
		var pet_button = Button.new()
		pet_button.text = "Pet"
		pet_button.size_flags_horizontal = SIZE_EXPAND_FILL
		pet_button.pressed.connect(func(): _on_pet_pressed())
		buttons_hbox.add_child(pet_button)
		
		# Close button
		var close_button = Button.new()
		close_button.text = "Close"
		close_button.size_flags_horizontal = SIZE_EXPAND_FILL
		close_button.pressed.connect(func(): queue_free())
		vbox.add_child(close_button)
		
		# Make sure panel is visible
		visible = true
	
	# Setup with animal reference and connect signals
	func setup(animal_ref, ui_ref):
		animal = animal_ref
		parent_ui = ui_ref
		
		# Set species info
		species_label.text = "Species: " + animal.get_species_name()
		
		# Set name field
		if animal.has_been_named():
			name_edit.text = animal.get_creature_name()
		else:
			name_edit.text = animal.generate_name_suggestion()
			name_edit.select_all()
		
		# Set initial stats
		update_stats()
		
		# Connect signals
		confirm_button.pressed.connect(func(): _on_confirm_name())
		animal.health_changed.connect(func(value): health_bar.value = value)
		animal.satisfaction_changed.connect(func(value): satisfaction_bar.value = value)
		animal.hunger_changed.connect(func(value): hunger_bar.value = value)
	
	func update_stats():
		if animal:
			health_bar.value = animal.health
			satisfaction_bar.value = animal.satisfaction
			hunger_bar.value = animal.hunger
	
	func _on_confirm_name():
		if animal and name_edit.text.strip_edges() != "":
			animal.set_creature_name(name_edit.text.strip_edges())
			confirm_button.text = "Name Updated!"
			await get_tree().create_timer(1.0).timeout
			confirm_button.text = "Confirm Name"
	
	func _on_feed_pressed():
		if animal and animal.has_method("feed"):
			animal.feed()
	
	func _on_pet_pressed():
		if animal and animal.has_method("pet"):
			animal.pet()

func _ready():
	# Find system references
	_find_system_references()
	
	# Connect signals
	_connect_signals()

	# Load settings
	_load_settings()
	
	# Try to load settings scene if not exported
	if settings_panel_scene == null:
		_settings_scene = load("res://modules/ui/settings.tscn")
		if _settings_scene:
			print("VivUI2: Loaded settings scene from path")
		else:
			print("VivUI2: Failed to load settings scene")
	else:
		_settings_scene = settings_panel_scene
		print("VivUI2: Using exported settings scene")
	
	# Configure all buttons to ignore keyboard input
	_configure_buttons_for_mouse_only()
	
	# Initialize terrain manipulator
	_initialize_terrain_manipulator()
	
	# Initialize scape tool resources
	_initialize_scape_tool_resources()
	
	# Register self as VivUI2 globally for easier reference
	_register_global_vivui2()
	
	print("VivUI2: Initialization complete")

# Configure all buttons to only respond to mouse clicks, not spacebar
func _configure_buttons_for_mouse_only():
	# Collect all buttons from the UI hierarchy
	var all_buttons = _find_all_buttons(self)
	
	# Configure each button to ignore spacebar
	for button in all_buttons:
		if button is Button:
			button.focus_mode = Control.FOCUS_NONE
	
	print("VivUI2: Configured " + str(all_buttons.size()) + " buttons to ignore spacebar")

# Recursively find all buttons in this UI tree
func _find_all_buttons(node: Node) -> Array:
	var buttons = []
	
	if node is Button:
		buttons.append(node)
	
	for child in node.get_children():
		buttons.append_array(_find_all_buttons(child))
	
	return buttons

func _find_system_references():
	# Find vivarium
	vivarium = get_tree().get_root().find_child("vivarium", true, false)
	if not vivarium:
		vivarium = get_tree().get_root().find_child("Vivarium", true, false)
	
	# Find camera
	camera = get_viewport().get_camera_2d()
	
	# Find viv_ui
	viv_ui = get_tree().get_root().find_child("VivUI1", true, false)
	if not viv_ui:
		viv_ui = get_tree().get_root().find_child("VivUI", true, false)
		
	if viv_ui:
		print("VivUI2: Found VivUI1 reference: ", viv_ui.name)
	else:
		print("VivUI2: VivUI1 not found")

func _connect_signals():
	# Connect to VivUI1 signals if found
	if viv_ui:
		print("VivUI2: Connecting signals to VivUI1")
	else:
		print("VivUI2: No VivUI1 found to connect signals")
	
	# Find and connect to animals in the scene
	_connect_to_animals()
	
	# Listen for new animals being added
	if get_tree():
		get_tree().node_added.connect(_on_node_added)

# Connect to existing animals in the scene
func _connect_to_animals():
	var animals = get_tree().get_nodes_in_group("animals")
	for animal in animals:
		_connect_animal_signals(animal)
	
	print("VivUI2: Connected to " + str(animals.size()) + " existing animals")

# Connect to an animal's signals
func _connect_animal_signals(animal):
	if animal.has_signal("selected") and !animal.is_connected("selected", Callable(self, "_on_animal_selected")):
		animal.connect("selected", Callable(self, "_on_animal_selected"))
	
	if animal.has_signal("deselected") and !animal.is_connected("deselected", Callable(self, "_on_animal_deselected")):
		animal.connect("deselected", Callable(self, "_on_animal_deselected"))

# Handle new nodes being added to the scene
func _on_node_added(node):
	# Check if the node is an animal
	if node.is_in_group("animals"):
		_connect_animal_signals(node)
		print("VivUI2: Connected to newly added animal")

# Try connecting signals again after a delay
func _delayed_signal_connect():
	print("VivUI2: Attempting delayed signal connections")
	_find_system_references()
	_connect_signals()

#region Bio Tool Functions
func activate_bio_tool():
	bio_tool_active = true
	scape_tool_active = false
	eco_tool_active = false
	emit_signal("tool_activated", "bio")

func deactivate_bio_tool():
	bio_tool_active = false
	emit_signal("tool_deactivated", "bio")

func _on_animal_selected(animal):
	print("VivUI2: Animal selected: " + animal.get_creature_name())
	# Display the bio UI
	show_bio_ui(animal)

func _on_animal_deselected(animal):
	print("VivUI2: Animal deselected: " + animal.get_creature_name())
	# Hide any existing bio UI if this animal was selected
	if active_bio_ui and is_instance_valid(active_bio_ui) and active_bio_ui.animal == animal:
		active_bio_ui.queue_free()
		active_bio_ui = null

# Show bio UI for an animal
func show_bio_ui(animal):
	print("VivUI2: Showing bio UI for ", animal.get_creature_name())
	
	# Hide any existing bio UI
	if active_bio_ui and is_instance_valid(active_bio_ui):
		active_bio_ui.queue_free()
		active_bio_ui = null
	
	# Create enhanced bio UI
	var panel = BioAnimalPanel.new()
	panel.name = "BioAnimalPanel"
	panel.setup(animal, self)
	
	# Add to InfoPanelsContainer or fallback to root
	var container = get_node_or_null("InfoPanelsContainer") 
	if container and is_instance_valid(container):
		container.add_child(panel)
	else:
		add_child(panel)
	
	# Position the panel near the animal
	var viewport = get_viewport()
	var screen_position
	
	if camera:
		# Calculate screen position using canvas transform
		var viewport_transform = viewport.get_canvas_transform()
		screen_position = viewport_transform * animal.global_position
	else:
		# Fallback if no camera
		screen_position = animal.global_position
	
	panel.position = screen_position + Vector2(50, -panel.size.y / 2)
	
	# Keep panel within screen bounds
	var viewport_size = viewport.get_visible_rect().size
	if panel.position.x < 10:
		panel.position.x = 10
	if panel.position.y < 10:
		panel.position.y = 10
	if panel.position.x + panel.size.x > viewport_size.x - 10:
		panel.position.x = viewport_size.x - panel.size.x - 10
	if panel.position.y + panel.size.y > viewport_size.y - 10:
		panel.position.y = viewport_size.y - panel.size.y - 10
	
	# Store reference
	active_bio_ui = panel
	
	return panel

# Function called when settings are loaded
func _load_settings():
	# Implementation for loading settings
	print("VivUI2: Loading settings")

# Initialize terrain manipulator
func _initialize_terrain_manipulator():
	# Implementation for terrain system
	print("VivUI2: Initializing terrain manipulator")

# Initialize scape tool resources
func _initialize_scape_tool_resources():
	# Implementation for scape tool resources
	print("VivUI2: Initializing scape tool resources")

# Register this instance globally for easier reference
func _register_global_vivui2():
	# Find the Registry autoload (from modules/core/registry.gd)
	var global_registry = get_node_or_null("/root/Registry")
	if global_registry:
		if global_registry.has_method("register_viv_ui2"):
			global_registry.register_viv_ui2(self)
			print("VivUI2: Registered with Registry (modules/core/registry.gd)")
		else:
			print("VivUI2: Registry (modules/core/registry.gd) doesn't have register_viv_ui2 method")
	else:
		print("VivUI2: Registry autoload (modules/core/registry.gd) not found, using local reference only")
	
	# Register self in scene tree using a unique group name
	add_to_group("viv_ui2_instances")
	
	print("VivUI2: Registration complete")
