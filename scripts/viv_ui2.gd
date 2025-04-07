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

func _ready():
	# Find system references
	_find_system_references()
	
	# Connect signals
	_connect_signals()

	# Load settings
	_load_settings()
	
	# Try to load settings scene if not exported
	if settings_panel_scene == null:
		_settings_scene = load("res://scenes/settings.tscn")
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
	
	print("VivUI2: Initialization complete")

# Configure all buttons to only respond to mouse clicks, not spacebar
func _configure_buttons_for_mouse_only():
	# Collect all buttons from the UI hierarchy
	var all_buttons = _find_all_buttons(self)
	
	# Configure each button to ignore spacebar
	for button in all_buttons:
		if button is Button:
			button.focus_mode = Control.FOCUS_NONE  # Prevent keyboard focus
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE  # Only respond to clicks
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # Better cursor feedback
	
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
	
	# Find background sprite within the vivarium
	if vivarium:
		background_sprite = vivarium.find_child("Background", true, false)
		if not background_sprite:
			background_sprite = vivarium.find_child("GlassBackground", true, false)

func _connect_signals():
	# Connect to VivUI1 signals if found
	if viv_ui:
		if viv_ui.has_signal("animal_selected"):
			viv_ui.animal_selected.connect(_on_animal_selected)
		if viv_ui.has_signal("animal_deselected"):
			viv_ui.animal_deselected.connect(_on_animal_deselected)

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
	# Show bio UI for selected animal
	if bio_tool_active:
		show_bio_ui(animal)

func _on_animal_deselected(_animal):
	# Hide bio UI
	if active_bio_ui and is_instance_valid(active_bio_ui):
		active_bio_ui.visible = false
		active_bio_ui.queue_free()
		active_bio_ui = null

func show_bio_ui(animal):
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
	
	# Store reference
	active_bio_ui = panel
	
	return panel

func _on_feed_clicked(animal):
	emit_signal("animal_interacted", animal, "feed")

func _on_pet_clicked(animal):
	emit_signal("animal_interacted", animal, "pet")

func _on_info_clicked(animal):
	# Forward to VivUI1 if available, otherwise create our own
	if viv_ui and viv_ui.has_method("show_info_panel"):
		viv_ui.show_info_panel(animal)
	else:
		show_info_panel(animal)

func _on_bio_ui_closed():
	if viv_ui and viv_ui.has_method("deselect_animal"):
		viv_ui.deselect_animal()

# Show info panel (fallback implementation if VivUI1 not available)
func show_info_panel(animal):
	# Create info panel directly
	var panel = Panel.new()
	panel.name = "InfoPanel"
	panel.size = Vector2(600, 500)
	panel.position = Vector2(50, 50)
	
	# Add controls
	var title = Label.new()
	title.text = "Species Information: " + animal.species_type
	title.position = Vector2(20, 20)
	title.size = Vector2(560, 30)
	panel.add_child(title)
	
	# Add description
	var desc = RichTextLabel.new()
	desc.position = Vector2(20, 60)
	desc.size = Vector2(560, 400)
	desc.text = "Species information would appear here."
	panel.add_child(desc)
	
	# Add close button
	var close = Button.new()
	close.text = "Close"
	close.position = Vector2(500, 460)
	close.size = Vector2(80, 30)
	close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)
	
	# Add to scene
	get_tree().get_root().add_child(panel)
	active_info_panel = panel
	
	return panel

# Show species information
func show_species_info(species_type: String):
	print("VivUI2: Showing species info for " + species_type)
	
	# Check if we have data for this species
	if !species_database.has(species_type):
		print("VivUI2: No species data found for " + species_type)
		return
	
	# Close any existing info panel
	if active_info_panel and is_instance_valid(active_info_panel):
		active_info_panel.queue_free()
	
	# Create species info panel
	var info_panel = BioInfoPanel.new()
	info_panel.setup(species_type, species_database[species_type])
	
	# Add to InfoPanelsContainer
	var container = $InfoPanelsContainer
	if is_instance_valid(container):
		container.add_child(info_panel)
	else:
		add_child(info_panel)
	
	# Store reference
	active_info_panel = info_panel
#endregion

#region Scape Tool Functions
func activate_scape_tool():
	scape_tool_active = true
	bio_tool_active = false
	eco_tool_active = false
	emit_signal("tool_activated", "scape")

func deactivate_scape_tool():
	scape_tool_active = false
	emit_signal("tool_deactivated", "scape")

func set_scape_tool_mode(mode: int):
	current_scape_tool = mode

func set_brush_size(size: float):
	brush_size = size

func set_brush_strength(strength: float):
	brush_strength = strength

func set_brush_material(material: String):
	brush_material = material

func set_gravity_enabled(enabled: bool):
	gravity_enabled = enabled

func apply_material_at_position(position: Vector2):
	if scape_tool_active:
		is_applying = true
		last_apply_position = position
		emit_signal("material_applied", position, brush_material, brush_size)
	
func stop_applying():
	is_applying = false
#endregion

#region Eco Tool Functions
func activate_eco_tool():
	eco_tool_active = true
	bio_tool_active = false
	scape_tool_active = false
	emit_signal("tool_activated", "eco")

func deactivate_eco_tool():
	eco_tool_active = false
	emit_signal("tool_deactivated", "eco")

func set_background(background_name: String):
	if background_options.has(background_name) and background_sprite:
		var path = background_options[background_name]
		if ResourceLoader.exists(path):
			background_sprite.texture = load(path)
			print("EcoTool: Changed background to " + background_name)
#endregion

#region Naming Dialog Functions
func show_naming_dialog(animal = null):
	# Defer to VivUI1 for naming dialog
	if viv_ui and viv_ui.has_method("show_naming_dialog"):
		viv_ui.show_naming_dialog(animal)
	else:
		# Create naming dialog directly as fallback
		var dialog = Panel.new()
		dialog.name = "NamingDialog"
		dialog.size = Vector2(400, 200)
		
		var title = Label.new()
		title.text = "Name Your Animal"
		title.position = Vector2(20, 20)
		title.size = Vector2(360, 30)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialog.add_child(title)
		
		var input = LineEdit.new()
		input.position = Vector2(50, 70)
		input.size = Vector2(300, 40)
		input.placeholder_text = "Enter a name..."
		dialog.add_child(input)
		
		var confirm = Button.new()
		confirm.text = "Confirm"
		confirm.position = Vector2(100, 140)
		confirm.size = Vector2(100, 30)
		dialog.add_child(confirm)
		
		var cancel = Button.new()
		cancel.text = "Cancel" 
		cancel.position = Vector2(210, 140)
		dialog.add_child(cancel)
		
		# Connect signals
		confirm.pressed.connect(func(): 
			if animal and "creature_name" in animal:
				animal.creature_name = input.text
			dialog.queue_free()
		)
		
		cancel.pressed.connect(func(): dialog.queue_free())
		
		# Add to scene
		get_tree().get_root().add_child(dialog)
		
		# Center dialog
		var viewport_size = get_viewport().get_visible_rect().size
		dialog.position = (viewport_size - dialog.size) / 2
		
		active_naming_dialog = dialog
#endregion

#region External Link Warning Functions
func show_external_link_warning(url: String, species_name: String = ""):
	print("VivUI2: Showing external link warning for " + url)
	
	# Create a proper external link warning dialog
	if active_external_link_warning and is_instance_valid(active_external_link_warning):
		active_external_link_warning.queue_free()
	
	# Create an enhanced warning dialog
	var dialog = ExternalLinkWarning.new()
	dialog.setup(url, species_name)
	
	# Add to DialogsContainer or fallback to root
	var container = get_node_or_null("DialogsContainer")
	if container and is_instance_valid(container):
		container.add_child(dialog)
	else:
		add_child(dialog)
	
	# Store reference
	active_external_link_warning = dialog
#endregion

#region Draggable Panel Base Class
class DraggablePanel extends Panel:
	# Panel properties
	var title: String = "Panel"
	var min_size: Vector2 = Vector2(200, 100)
	var can_dock: bool = false
	var is_dragging: bool = false
	var drag_offset: Vector2 = Vector2.ZERO

	# References
	var title_bar = null
	var title_label = null
	var close_button = null

	# Signals
	signal panel_closed

	func _ready():
		# Ensure title bar exists
		if !title_bar:
			title_bar = Panel.new()
			title_bar.name = "TitleBar"
			title_bar.custom_minimum_size = Vector2(0, 30)
			title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
			add_child(title_bar)
		
		# Ensure title label exists
		if !title_label:
			title_label = Label.new()
			title_label.name = "TitleLabel"
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			title_label.text = title
			title_label.position = Vector2(10, 0)
			title_label.size = Vector2(title_bar.size.x - 40, title_bar.size.y)
			title_bar.add_child(title_label)
		
		# Ensure close button exists
		if !close_button:
			close_button = Button.new()
			close_button.name = "CloseButton"
			close_button.text = "×"
			close_button.size = Vector2(30, 30)
			close_button.position = Vector2(title_bar.size.x - 30, 0)
			title_bar.add_child(close_button)
		
		# Set minimum size
		custom_minimum_size = min_size
		
		# Connect signals
		title_bar.gui_input.connect(_on_title_bar_gui_input)
		close_button.pressed.connect(_on_close_button_pressed)
		
		# Set the title
		if title_label:
			title_label.text = title

	func _process(_delta):
		if is_dragging:
			var new_position = get_global_mouse_position() - drag_offset
			
			# Get viewport boundaries
			var viewport_size = get_viewport_rect().size
			var panel_size = size
			
			# Keep panel within viewport bounds
			new_position.x = clamp(new_position.x, 0, viewport_size.x - panel_size.x)
			new_position.y = clamp(new_position.y, 0, viewport_size.y - panel_size.y)
			
			# Update position
			global_position = new_position

	func _on_title_bar_gui_input(event):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_dragging = true
					drag_offset = get_local_mouse_position()
				else:
					is_dragging = false

	func _on_close_button_pressed():
		panel_closed.emit()
		visible = false

	func set_title_text(new_title: String):
		title = new_title
		if title_label:
			title_label.text = new_title
#endregion

#region Settings Management
# Initialize settings UI panel
func show_settings_panel():
	# Hide any existing panel
	if active_settings_panel and is_instance_valid(active_settings_panel):
		active_settings_panel.queue_free()
		active_settings_panel = null
	
	# Create settings panel
	if _settings_scene:
		active_settings_panel = _settings_scene.instantiate()
		
		# Add panel to the settings container
		var container = $SettingsContainer
		if container and is_instance_valid(container):
			container.add_child(active_settings_panel)
		else:
			# Fallback to adding directly to this node
			add_child(active_settings_panel)
		
		# Connect to the settings_closed signal
		if active_settings_panel.has_signal("settings_closed"):
			active_settings_panel.connect("settings_closed", _on_settings_panel_closed)
		
		# Show the panel
		active_settings_panel.visible = true
		settings_panel_visible = true
		
		# Center the panel
		var viewport_size = get_viewport().get_visible_rect().size
		active_settings_panel.position = (viewport_size - active_settings_panel.size) / 2
		
		print("VivUI2: Settings panel created and shown")
	else:
		print("VivUI2: Could not create settings panel - scene not found")

# Handle settings panel closed
func _on_settings_panel_closed():
	settings_panel_visible = false
	if active_settings_panel:
		active_settings_panel.queue_free()
		active_settings_panel = null

# Hide settings panel
func hide_settings_panel():
	if active_settings_panel and is_instance_valid(active_settings_panel):
		active_settings_panel.visible = false
		active_settings_panel.queue_free()
		active_settings_panel = null
	
	settings_panel_visible = false

# Toggle settings panel visibility
func toggle_settings_panel():
	if settings_panel_visible:
		hide_settings_panel()
	else:
		show_settings_panel()

# Following functions will now just pass through to the settings system
# Set difficulty level
func set_difficulty(level: int):
	current_difficulty = level
	_save_settings()

# Set productivity target hours
func set_productivity_hours(hours: int):
	productivity_hours = hours
	_save_settings()

# Set music volume
func set_music_volume(volume: float):
	music_volume = volume
	_save_settings()

# Set SFX volume
func set_sfx_volume(volume: float):
	sfx_volume = volume
	_save_settings()

# Set fullscreen mode
func set_fullscreen(enabled: bool):
	is_fullscreen = enabled
	_save_settings()

# Save settings to config file
func _save_settings():
	var config = ConfigFile.new()
	
	# Game settings
	config.set_value("game", "difficulty", current_difficulty)
	config.set_value("game", "productivity_hours", productivity_hours)
	config.set_value("game", "today_productivity", today_productivity)
	
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
	
	# Audio settings
	music_volume = config.get_value("audio", "music_volume", 0.5)
	sfx_volume = config.get_value("audio", "sfx_volume", 0.7)
	
	# Video settings
	is_fullscreen = config.get_value("video", "fullscreen", false)
	
	print("VivUI2: Loaded settings")
#endregion

# Process function
func _process(_delta):
	# Update active UIs if needed
	if active_bio_ui and is_instance_valid(active_bio_ui):
		if active_bio_ui.has_method("refresh_stats"):
			active_bio_ui.refresh_stats()
	
	# Handle scape tool continuous application
	if scape_tool_active and is_applying:
		var mouse_pos = get_viewport().get_mouse_position()
		var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
		
		# Apply only if moved enough to avoid excessive spam
		if world_pos.distance_to(last_apply_position) > brush_size * 0.25:
			last_apply_position = world_pos
			emit_signal("material_applied", world_pos, brush_material, brush_size)

#region Enhanced UI Classes
# Enhanced Bio Info Panel class
class BioInfoPanel extends Panel:
	# Panel properties
	var title_label: Label
	var image_rect: TextureRect
	var scientific_label: Label
	var description_text: RichTextLabel
	var care_text: RichTextLabel
	var facts_text: RichTextLabel
	var wiki_button: Button
	var close_button: Button
	var tabs: TabContainer
	
	# Setup the panel with species data
	func setup(species_name: String, data: Dictionary):
		# Set panel properties
		name = species_name + "InfoPanel"
		size = Vector2(800, 600)
		
		# Set up title
		title_label = Label.new()
		title_label.text = species_name + " Information"
		title_label.position = Vector2(20, 20)
		title_label.size = Vector2(760, 30)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 24)
		add_child(title_label)
		
		# Set up image if available
		if data.has("image") and ResourceLoader.exists(data.image):
			image_rect = TextureRect.new()
			image_rect.texture = load(data.image)
			image_rect.position = Vector2(20, 60)
			image_rect.size = Vector2(200, 200)
			image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			add_child(image_rect)
		
		# Set up scientific name
		if data.has("scientific_name"):
			scientific_label = Label.new()
			scientific_label.text = "Scientific name: " + data.scientific_name
			scientific_label.position = Vector2(240, 60)
			scientific_label.size = Vector2(540, 30)
			scientific_label.add_theme_font_size_override("font_size", 18)
			scientific_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			add_child(scientific_label)
		
		# Set up tabs
		tabs = TabContainer.new()
		tabs.position = Vector2(20, 270)
		tabs.size = Vector2(760, 280)
		add_child(tabs)
		
		# Description tab
		if data.has("description"):
			var description_container = VBoxContainer.new()
			description_container.name = "Description"
			description_text = RichTextLabel.new()
			description_text.text = data.description
			description_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
			description_container.add_child(description_text)
			tabs.add_child(description_container)
		
		# Care tab
		if data.has("care"):
			var care_container = VBoxContainer.new()
			care_container.name = "Care Guide"
			care_text = RichTextLabel.new()
			care_text.text = data.care
			care_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
			care_text.bbcode_enabled = true
			care_container.add_child(care_text)
			tabs.add_child(care_container)
		
		# Facts tab
		if data.has("facts"):
			var facts_container = VBoxContainer.new()
			facts_container.name = "Interesting Facts"
			facts_text = RichTextLabel.new()
			facts_text.text = data.facts
			facts_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
			facts_container.add_child(facts_text)
			tabs.add_child(facts_container)
		
		# Wiki button
		wiki_button = Button.new()
		wiki_button.text = "Visit Wiki"
		wiki_button.position = Vector2(580, 560)
		wiki_button.size = Vector2(100, 30)
		wiki_button.pressed.connect(_on_wiki_pressed)
		add_child(wiki_button)
		
		# Close button
		close_button = Button.new()
		close_button.text = "Close"
		close_button.position = Vector2(690, 560)
		close_button.size = Vector2(90, 30)
		close_button.pressed.connect(_on_close_pressed)
		add_child(close_button)
		
		# Center in viewport
		_center_in_viewport()
	
	# Center the panel in the viewport
	func _center_in_viewport():
		if get_viewport():
			var viewport_size = get_viewport().get_visible_rect().size
			position = (viewport_size - size) / 2
	
	# Wiki button handler
	func _on_wiki_pressed():
		# Get parent VivUI2
		var parent_ui = get_parent()
		while parent_ui and parent_ui.get_class() != "VivUI2" and not "show_external_link_warning" in parent_ui:
			parent_ui = parent_ui.get_parent()
		
		# Show external link warning
		if parent_ui and parent_ui.has_method("show_external_link_warning"):
			parent_ui.show_external_link_warning("https://antipwr.github.io", name.replace("InfoPanel", ""))
		else:
			# Fallback
			OS.shell_open("https://antipwr.github.io")
	
	# Close button handler
	func _on_close_pressed():
		queue_free()

# Bio Animal Panel class
class BioAnimalPanel extends Panel:
	# Panel properties
	var animal_ref: Node = null
	var viv_ui2_ref: Node = null
	var title_label: Label
	var stats_container: VBoxContainer
	var health_bar: ProgressBar
	var satisfaction_bar: ProgressBar
	var hunger_bar: ProgressBar
	var buttons_container: VBoxContainer
	
	# Setup the panel with animal reference
	func setup(animal, viv_ui2):
		# Store references
		animal_ref = animal
		viv_ui2_ref = viv_ui2
		
		# Set panel properties
		name = "BioAnimalPanel"
		size = Vector2(400, 500)
		
		# Create a title bar
		var title_bar = Panel.new()
		title_bar.name = "TitleBar"
		title_bar.custom_minimum_size = Vector2(0, 30)
		title_bar.position = Vector2(0, 0)
		title_bar.size = Vector2(400, 40)
		add_child(title_bar)
		
		# Add title
		title_label = Label.new()
		title_label.text = animal.get_creature_name() + " (" + animal.species_type + ")"
		title_label.position = Vector2(10, 5)
		title_label.size = Vector2(350, 30)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_bar.add_child(title_label)
		
		# Add a close button to title bar
		var close_button = Button.new()
		close_button.text = "×"
		close_button.position = Vector2(360, 5)
		close_button.size = Vector2(30, 30)
		close_button.pressed.connect(_on_close_pressed)
		title_bar.add_child(close_button)
		
		# Create stats container
		stats_container = VBoxContainer.new()
		stats_container.position = Vector2(20, 60)
		stats_container.size = Vector2(360, 150)
		add_child(stats_container)
		
		# Add health bar
		var health_label = Label.new()
		health_label.text = "Health:"
		stats_container.add_child(health_label)
		
		health_bar = ProgressBar.new()
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = animal.health if "health" in animal else 100
		health_bar.custom_minimum_size = Vector2(0, 20)
		stats_container.add_child(health_bar)
		
		# Add satisfaction bar
		var satisfaction_label = Label.new()
		satisfaction_label.text = "Satisfaction:"
		stats_container.add_child(satisfaction_label)
		
		satisfaction_bar = ProgressBar.new()
		satisfaction_bar.min_value = 0
		satisfaction_bar.max_value = 100
		satisfaction_bar.value = animal.satisfaction if "satisfaction" in animal else 100
		satisfaction_bar.custom_minimum_size = Vector2(0, 20)
		stats_container.add_child(satisfaction_bar)
		
		# Add hunger bar
		var hunger_label = Label.new()
		hunger_label.text = "Hunger:"
		stats_container.add_child(hunger_label)
		
		hunger_bar = ProgressBar.new()
		hunger_bar.min_value = 0
		hunger_bar.max_value = 100
		hunger_bar.value = animal.hunger if "hunger" in animal else 0
		hunger_bar.custom_minimum_size = Vector2(0, 20)
		stats_container.add_child(hunger_bar)
		
		# Create buttons container
		buttons_container = VBoxContainer.new()
		buttons_container.position = Vector2(20, 230)
		buttons_container.size = Vector2(360, 250)
		buttons_container.custom_minimum_size = Vector2(0, 200)
		add_child(buttons_container)
		
		# Add interaction buttons
		_add_button("Rename", _on_rename_pressed)
		_add_button("Feed", _on_feed_pressed)
		_add_button("Pet", _on_pet_pressed)
		_add_button("More Information", _on_info_pressed)
		_add_button("Visit Wiki", _on_wiki_pressed)
		
		# Connect animal signals if available
		if animal.has_signal("health_changed"):
			animal.health_changed.connect(_on_health_changed)
		
		if animal.has_signal("satisfaction_changed"):
			animal.satisfaction_changed.connect(_on_satisfaction_changed)
		
		if animal.has_signal("hunger_changed"):
			animal.hunger_changed.connect(_on_hunger_changed)
			
		# Center in viewport
		_center_in_viewport()
		
		# Update stats
		refresh_stats()
	
	# Helper to add buttons
	func _add_button(text: String, callback: Callable):
		var button = Button.new()
		button.text = text
		button.custom_minimum_size = Vector2(0, 35)
		button.pressed.connect(callback)
		buttons_container.add_child(button)
	
	# Center the panel in the viewport
	func _center_in_viewport():
		if get_viewport():
			var viewport_size = get_viewport().get_visible_rect().size
			position = (viewport_size - size) / 2
	
	# Update displayed stats
	func refresh_stats():
		if !is_instance_valid(animal_ref):
			return
		
		if health_bar:
			health_bar.value = animal_ref.health if "health" in animal_ref else 100
		
		if satisfaction_bar:
			satisfaction_bar.value = animal_ref.satisfaction if "satisfaction" in animal_ref else 100
		
		if hunger_bar:
			hunger_bar.value = animal_ref.hunger if "hunger" in animal_ref else 0
	
	# Signal handlers
	func _on_health_changed(value):
		if health_bar:
			health_bar.value = value
	
	func _on_satisfaction_changed(value):
		if satisfaction_bar:
			satisfaction_bar.value = value
	
	func _on_hunger_changed(value):
		if hunger_bar:
			hunger_bar.value = value
	
	# Button handlers
	func _on_rename_pressed():
		if viv_ui2_ref and viv_ui2_ref.has_method("show_naming_dialog"):
			viv_ui2_ref.show_naming_dialog(animal_ref)
	
	func _on_feed_pressed():
		if is_instance_valid(animal_ref) and animal_ref.has_method("feed"):
			animal_ref.feed()
			refresh_stats()
	
	func _on_pet_pressed():
		if is_instance_valid(animal_ref) and animal_ref.has_method("pet"):
			animal_ref.pet()
			refresh_stats()
	
	func _on_info_pressed():
		if is_instance_valid(animal_ref) and viv_ui2_ref and viv_ui2_ref.has_method("show_species_info"):
			viv_ui2_ref.show_species_info(animal_ref.species_type)
	
	func _on_wiki_pressed():
		if viv_ui2_ref and viv_ui2_ref.has_method("show_external_link_warning"):
			viv_ui2_ref.show_external_link_warning("https://antipwr.github.io", animal_ref.species_type)
	
	func _on_close_pressed():
		if is_instance_valid(animal_ref) and animal_ref.has_method("deselect"):
			animal_ref.deselect()
		queue_free()

# External Link Warning Class
class ExternalLinkWarning extends Panel:
	# Properties
	var url: String = ""
	var message_label: Label
	var warning_label: Label
	var continue_button: Button
	var cancel_button: Button
	
	# Setup the warning dialog
	func setup(link_url: String, species_name: String = ""):
		url = link_url
		name = "ExternalLinkWarning"
		size = Vector2(500, 250)
		
		# Add title label
		var title_label = Label.new()
		title_label.text = "External Link Warning"
		title_label.position = Vector2(20, 20)
		title_label.size = Vector2(460, 30)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 18)
		add_child(title_label)
		
		# Add message
		message_label = Label.new()
		message_label.text = "You are about to visit an external website:"
		message_label.position = Vector2(20, 60)
		message_label.size = Vector2(460, 30)
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(message_label)
		
		# Add URL
		var url_label = Label.new()
		url_label.text = url
		url_label.position = Vector2(20, 100)
		url_label.size = Vector2(460, 30)
		url_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(url_label)
		
		# Add warning
		warning_label = Label.new()
		warning_label.text = "This will open in your web browser."
		warning_label.position = Vector2(20, 140)
		warning_label.size = Vector2(460, 30)
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(warning_label)
		
		# Add confirm button
		continue_button = Button.new()
		continue_button.text = "Continue to Website"
		continue_button.position = Vector2(100, 190)
		continue_button.size = Vector2(150, 40)
		continue_button.pressed.connect(_on_continue_pressed)
		add_child(continue_button)
		
		# Add cancel button
		cancel_button = Button.new()
		cancel_button.text = "Cancel"
		cancel_button.position = Vector2(270, 190)
		cancel_button.size = Vector2(150, 40)
		cancel_button.pressed.connect(_on_cancel_pressed)
		add_child(cancel_button)
		
		# If species name is provided, update message
		if species_name:
			message_label.text = "You are about to visit the " + species_name + " wiki page:"
		
		# Center in viewport
		_center_in_viewport()
	
	# Center the panel in the viewport
	func _center_in_viewport():
		if get_viewport():
			var viewport_size = get_viewport().get_visible_rect().size
			position = (viewport_size - size) / 2
	
	# Button handlers
	func _on_continue_pressed():
		OS.shell_open(url)
		queue_free()
	
	func _on_cancel_pressed():
		queue_free()
#endregion

# Settings panel management
func show_settings():
	print("VivUI2: Showing settings panel")
	
	# Check if we already have an active settings panel
	if active_settings and is_instance_valid(active_settings):
		print("VivUI2: Settings panel already exists, toggling visibility")
		if active_settings.has_method("toggle_menu"):
			active_settings.toggle_menu()
		else:
			active_settings.visible = !active_settings.visible
		return
	
	# Load the settings scene with proper error handling
	var settings_scene = null
	if settings_panel_scene:
		settings_scene = settings_panel_scene
	elif _settings_scene:
		settings_scene = _settings_scene
	else:
		_settings_scene = load("res://scenes/settings.tscn")
		settings_scene = _settings_scene
	
	if settings_scene:
		# Create the panel in a deferred way
		call_deferred("_deferred_create_settings", settings_scene)
	else:
		print("VivUI2: ERROR - Could not load settings scene")

# Create settings panel in a deferred way to avoid Transform2D errors
func _deferred_create_settings(settings_scene):
	print("VivUI2: Creating settings panel (deferred)")
	
	# Create settings instance
	var settings = settings_scene.instantiate()
	get_tree().root.add_child(settings)
	
	# Store reference
	active_settings = settings
	
	# First, set a safe default position to prevent initial layout errors
	settings.position = Vector2(500, 300)
	
	# Wait a frame to allow the UI to initialize
	await get_tree().process_frame
	
	# Get viewport and panel sizes safely
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = settings.size
	
	# Use fallback size if the panel size is invalid
	if panel_size.x < 50 || panel_size.y < 50:
		panel_size = Vector2(800, 600)
	
	# Calculate safe center position
	var safe_pos = Vector2(
		max(0, (viewport_size.x - panel_size.x) / 2),
		max(0, (viewport_size.y - panel_size.y) / 2)
	)
	
	# Apply position
	settings.position = safe_pos
	
	# Show the panel as a menu
	if settings.has_method("toggle_menu"):
		settings.toggle_menu()
	
	# Connect to the closed signal if available
	if settings.has_signal("settings_closed"):
		if !settings.is_connected("settings_closed", _on_settings_closed):
			settings.connect("settings_closed", _on_settings_closed)
	
	print("VivUI2: Settings panel displayed at position: " + str(settings.position))

# Handle settings panel closed
func _on_settings_closed():
	print("VivUI2: Settings panel closed")
	if active_settings and is_instance_valid(active_settings):
		active_settings.queue_free()
		active_settings = null

# Initialize terrain manipulator system
func _initialize_terrain_manipulator():
	# Create terrain node if it doesn't exist
	if vivarium and !vivarium.has_node("TerrainSystem"):
		var terrain_system = Node2D.new()
		terrain_system.name = "TerrainSystem"
		# Use call_deferred to avoid error when parent node is busy
		vivarium.call_deferred("add_child", terrain_system)
		
		# Create sand layer - also deferred
		var sand_layer = Node2D.new()
		sand_layer.name = "SandLayer"
		# Store the reference for later use when the node is added
		var terrain_ref = terrain_system
		terrain_ref.call_deferred("add_child", sand_layer)
		
		print("VivUI2: Created terrain system")
	else:
		print("VivUI2: Terrain system already exists or vivarium not found")
	
	# Connect material applied signal
	if !material_applied.is_connected(_on_material_applied):
		material_applied.connect(_on_material_applied)

# Get the terrain system from the vivarium
func _get_terrain_system():
	if !vivarium:
		return null
		
	return vivarium.get_node_or_null("TerrainSystem")

# Input event processing for terrain manipulation
func _input(event):
	if !scape_tool_active:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start applying at mouse position
				var mouse_pos = get_viewport().get_mouse_position()
				var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
				apply_material_at_position(world_pos)
			else:
				# Stop applying
				stop_applying()
	
	if event is InputEventMouseMotion:
		if is_applying:
			# Continue applying at the new mouse position
			var mouse_pos = get_viewport().get_mouse_position()
			var world_pos = get_viewport().get_canvas_transform().affine_inverse() * mouse_pos
			apply_material_at_position(world_pos)

# Handle material applied
func _on_material_applied(position: Vector2, material_type: String, size: float):
	print("VivUI2: Applying " + material_type + " at " + str(position) + " with size " + str(size))
	
	# Get terrain system
	var terrain_system = _get_terrain_system()
	if !terrain_system:
		print("VivUI2: Cannot apply material - terrain system not found")
		return
		
	# Get correct layer based on material
	var layer = terrain_system.get_node_or_null(material_type + "Layer")
	if !layer:
		print("VivUI2: Cannot find layer for material: " + material_type)
		return
	
	# Create a new terrain particle at the position
	var particle = TerrainParticle.new()
	particle.position = position
	particle.size = size * brush_strength
	particle.material_type = material_type
	
	if current_scape_tool == 0: # Brush mode
		particle.set_shape(TerrainParticle.SHAPE_CIRCLE)
	elif current_scape_tool == 1: # Pen mode
		particle.set_shape(TerrainParticle.SHAPE_SQUARE)
	
	# Add to layer
	layer.add_child(particle)

# Terrain particle class for sand and other materials
class TerrainParticle extends Node2D:
	const SHAPE_CIRCLE = 0
	const SHAPE_SQUARE = 1
	
	var size: float = 20.0
	var material_type: String = "Sand"
	var shape_type: int = SHAPE_CIRCLE
	var color: Color = Color(0.9, 0.8, 0.5, 1.0) # Sand color
	
	func _ready():
		# Set color based on material type
		if material_type == "Sand":
			color = Color(0.9, 0.8, 0.5, 1.0) # Sand color
	
	func set_shape(shape: int):
		shape_type = shape
		queue_redraw()
	
	func _draw():
		if shape_type == SHAPE_CIRCLE:
			draw_circle(Vector2.ZERO, size, color)
		elif shape_type == SHAPE_SQUARE:
			var rect_size = Vector2(size * 2, size * 2)
			draw_rect(Rect2(-rect_size/2, rect_size), color, true)
