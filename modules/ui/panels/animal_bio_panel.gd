extends Panel

# Animal Bio Panel for displaying and editing animal information
# Shows stats, allows naming, and provides interaction buttons

# Node references
@onready var title_label = $VBoxContainer/TitleLabel
@onready var species_label = $VBoxContainer/SpeciesLabel
@onready var name_edit = $VBoxContainer/NameContainer/NameEdit
@onready var confirm_name_button = $VBoxContainer/ConfirmNameButton
@onready var health_bar = $VBoxContainer/HealthContainer/HealthBar
@onready var satisfaction_bar = $VBoxContainer/SatisfactionContainer/SatisfactionBar
@onready var hunger_bar = $VBoxContainer/HungerContainer/HungerBar
@onready var info_tab_container = $VBoxContainer/InfoTabContainer
@onready var needs_content = $VBoxContainer/InfoTabContainer/Needs/NeedsScrollContainer/NeedsContent
@onready var info_content = $VBoxContainer/InfoTabContainer/Info/InfoScrollContainer/InfoContent
@onready var feed_button = $VBoxContainer/ButtonsContainer/FeedButton
@onready var pet_button = $VBoxContainer/ButtonsContainer/PetButton
@onready var close_button = $VBoxContainer/CloseButton

# Reference to the displayed animal
var animal = null
var follow_animal = false # New property to control following behavior

# Emit when the panel is closed
signal panel_closed
# Emit when animal name is confirmed
signal name_confirmed(name)

# Dictionary to track need bars for updating
var need_bars = {}

func _ready():
	# Connect button signals
	confirm_name_button.pressed.connect(_on_confirm_name_pressed)
	feed_button.pressed.connect(_on_feed_pressed)
	pet_button.pressed.connect(_on_pet_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Hide panel until it's populated
	visible = false

# Process function for following animals
func _process(delta):
	# Update panel position if following animal
	if follow_animal and animal and is_instance_valid(animal):
		update_panel_position()

# Set whether the panel should follow the animal
func set_follow_animal(should_follow: bool):
	follow_animal = should_follow

# Update the panel position to follow the animal
func update_panel_position():
	if not animal or not is_instance_valid(animal):
		return
		
	# Calculate screen position of the animal
	var viewport_transform = get_viewport().get_canvas_transform()
	var screen_position = viewport_transform * animal.global_position
	
	# Add offset to the right of the animal
	var offset = Vector2(30, -size.y / 2)
	position = screen_position + offset
	
	# Keep panel within screen bounds
	var viewport_size = get_viewport().get_visible_rect().size
	if position.x < 10:
		position.x = 10
	if position.y < 10:
		position.y = 10
	if position.x + size.x > viewport_size.x - 10:
		position.x = viewport_size.x - size.x - 10
	if position.y + size.y > viewport_size.y - 10:
		position.y = viewport_size.y - size.y - 10

# Set the animal and populate the panel
func set_animal(new_animal):
	if not new_animal or not is_instance_valid(new_animal):
		push_error("AnimalBioPanel: Invalid animal provided")
		return false
		
	print("AnimalBioPanel: Setting animal to " + new_animal.name)
	
	# Store reference
	animal = new_animal
	
	# Update panel title
	var creature_name = "Unnamed"
	if animal.has_method("get_creature_name"):
		creature_name = animal.get_creature_name()
	elif "creature_name" in animal:
		creature_name = animal.creature_name
	
	title_label.text = creature_name
	
	# Update species
	var species = "Unknown"
	if "species_type" in animal:
		species = animal.species_type
		
	species_label.text = "Species: " + species
	
	# Set name field
	name_edit.text = creature_name if creature_name != "Unnamed" else ""
	
	# Update stats
	_update_stats()
	
	# Build tabs
	_build_needs_tab()
	_build_info_tab()
	
	# Connect signals for updating
	_connect_animal_signals()
	
	# Show the panel
	visible = true
	return true

# Update the stats bars
func _update_stats():
	if not animal or not is_instance_valid(animal):
		return
		
	# Health
	if "health" in animal:
		health_bar.value = animal.health
	else:
		health_bar.value = 100
		
	# Satisfaction
	if "satisfaction" in animal:
		satisfaction_bar.value = animal.satisfaction
	else:
		satisfaction_bar.value = 100
		
	# Hunger
	if "hunger" in animal:
		hunger_bar.value = animal.hunger
	else:
		hunger_bar.value = 0

# Connect to animal signals
func _connect_animal_signals():
	if not animal:
		return
		
	# Disconnect any existing connections first
	_disconnect_animal_signals()
	
	# Connect to signals if available
	if animal.has_signal("health_changed"):
		animal.health_changed.connect(_on_health_changed)
		
	if animal.has_signal("satisfaction_changed"):
		animal.satisfaction_changed.connect(_on_satisfaction_changed)
		
	if animal.has_signal("hunger_changed"):
		animal.hunger_changed.connect(_on_hunger_changed)

# Disconnect from animal signals
func _disconnect_animal_signals():
	if not animal:
		return
		
	# Disconnect if connected
	if animal.has_signal("health_changed") and animal.is_connected("health_changed", Callable(self, "_on_health_changed")):
		animal.disconnect("health_changed", Callable(self, "_on_health_changed"))
		
	if animal.has_signal("satisfaction_changed") and animal.is_connected("satisfaction_changed", Callable(self, "_on_satisfaction_changed")):
		animal.disconnect("satisfaction_changed", Callable(self, "_on_satisfaction_changed"))
		
	if animal.has_signal("hunger_changed") and animal.is_connected("hunger_changed", Callable(self, "_on_hunger_changed")):
		animal.disconnect("hunger_changed", Callable(self, "_on_hunger_changed"))

# Build the needs tab content
func _build_needs_tab():
	# Clear existing content
	for child in needs_content.get_children():
		child.queue_free()
	
	need_bars.clear()
	
	# Add health need
	_add_need_bar("Health", animal.health if "health" in animal else 100, 100, Color(0.2, 0.8, 0.2))
	
	# Add hunger need (inverse of hunger value, as lower hunger is better)
	_add_need_bar("Nutrition", 100 - (animal.hunger if "hunger" in animal else 0), 100, Color(0.9, 0.6, 0.1))
	
	# Add satisfaction need
	_add_need_bar("Happiness", animal.satisfaction if "satisfaction" in animal else 100, 100, Color(0.2, 0.6, 0.9))
	
	# Add environment needs based on species
	if "species_type" in animal:
		match animal.species_type:
			"Cherry Shrimp":
				_add_need_bar("Water Quality", 85, 100, Color(0.4, 0.7, 0.9))
				_add_need_bar("Plant Cover", 70, 100, Color(0.3, 0.8, 0.3))
				_add_need_bar("Social", 65, 100, Color(0.9, 0.4, 0.8))
			"Dream Guppy":
				_add_need_bar("Swimming Space", 90, 100, Color(0.5, 0.7, 0.9))
				_add_need_bar("Enrichment", 60, 100, Color(0.9, 0.8, 0.3))
				_add_need_bar("Social", 75, 100, Color(0.9, 0.4, 0.8))
			_:
				_add_need_bar("Habitat", 80, 100, Color(0.7, 0.7, 0.3))

# Build the info tab content - Fix for Integer Division Warnings
func _build_info_tab():
	# Clear existing content
	for child in info_content.get_children():
		child.queue_free()
	
	# Add age information
	var age_label = Label.new()
	
	if "age" in animal:
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
		
		age_label.text = "Age: " + age_text
	else:
		age_label.text = "Age: Unknown"
		
	info_content.add_child(age_label)
	
	# Add life stage if available
	if "age_state" in animal:
		var age_state_label = Label.new()
		age_state_label.text = "Life Stage: " + animal.age_state.capitalize()
		info_content.add_child(age_state_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	info_content.add_child(spacer)
	
	# Add feeding type
	var feeding_label = Label.new()
	
	if "feeding_type" in animal:
		var feeding_type = "Unknown"
		match animal.feeding_type:
			0: feeding_type = "Carnivore"
			1: feeding_type = "Herbivore"
			2: feeding_type = "Omnivore"
			3: feeding_type = "Detritivore"
			4: feeding_type = "Filter Feeder"
		
		feeding_label.text = "Diet: " + feeding_type
	else:
		feeding_label.text = "Diet: Unknown"
		
	info_content.add_child(feeding_label)
	
	# Add environmental preferences
	var env_label = Label.new()
	
	if "environment_prefs" in animal and animal.environment_prefs is Array:
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
			
		env_label.text = env_prefs
	else:
		env_label.text = "Environmental Preferences: Unknown"
		
	info_content.add_child(env_label)
	
	# Add wiki button
	var wiki_button = Button.new()
	wiki_button.text = "Visit VivOS Wiki"
	wiki_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wiki_button.custom_minimum_size = Vector2(150, 40)
	wiki_button.pressed.connect(_on_wiki_button_pressed)
	
	# Add some space before the button
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(0, 20)
	info_content.add_child(button_spacer)
	
	info_content.add_child(wiki_button)

# Helper function to add need bars
func _add_need_bar(label_text, current_value, max_value, bar_color):
	# Add label
	var label = Label.new()
	label.text = label_text
	needs_content.add_child(label)
	
	# Add progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.max_value = max_value
	progress_bar.value = current_value
	progress_bar.show_percentage = true
	
	# Set bar color
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bar_color
	progress_bar.add_theme_stylebox_override("fill", style_box)
	
	needs_content.add_child(progress_bar)
	
	# Store reference for updating
	need_bars[label_text.to_lower()] = progress_bar
	
	# Add description of need status
	var status_label = Label.new()
	status_label.text = _get_need_status_text(current_value, max_value)
	needs_content.add_child(status_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	needs_content.add_child(spacer)

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

# Button event handlers
func _on_confirm_name_pressed():
	if not animal or not is_instance_valid(animal):
		return
		
	var new_name = name_edit.text.strip_edges()
	if new_name.is_empty():
		# Show error
		var error_dialog = AcceptDialog.new()
		error_dialog.title = "Naming Error"
		error_dialog.dialog_text = "Please enter a name for your animal."
		add_child(error_dialog)
		error_dialog.popup_centered()
		return
	
	# Set the name
	if animal.has_method("set_creature_name"):
		animal.set_creature_name(new_name)
	elif "creature_name" in animal:
		animal.creature_name = new_name
	
	# Update title
	title_label.text = new_name
	
	# Notify about confirmation
	emit_signal("name_confirmed", new_name)
	
	# Show confirmation
	confirm_name_button.text = "Name Updated!"
	await get_tree().create_timer(1.0).timeout
	confirm_name_button.text = "Confirm Name"
	
	# Automatically close the panel if this was for naming a new animal
	if not animal.has_been_named():
		_on_close_pressed()

func _on_feed_pressed():
	if not animal or not is_instance_valid(animal):
		return
		
	if animal.has_method("feed"):
		animal.feed()
		print("AnimalBioPanel: Fed animal")
	else:
		print("AnimalBioPanel: Animal does not have feed method")

func _on_pet_pressed():
	if not animal or not is_instance_valid(animal):
		return
		
	if animal.has_method("pet"):
		animal.pet()
		print("AnimalBioPanel: Petted animal")
	else:
		print("AnimalBioPanel: Animal does not have pet method")

func _on_close_pressed():
	print("AnimalBioPanel: Closed")
	visible = false
	emit_signal("panel_closed")

func _on_wiki_button_pressed():
	if not animal:
		return
		
	var species_name = "Unknown"
	if "species_type" in animal:
		species_name = animal.species_type
	
	# Find UI manager to show warning
	var ui_manager = get_node_or_null("/root/UIManager")
	if ui_manager and ui_manager.has_method("show_external_link_warning"):
		ui_manager.show_external_link_warning("https://antipwr.github.io", species_name)
	else:
		# Find viv_ui1 to show warning
		var viv_ui1 = get_tree().get_root().find_child("VivUI1", true, false)
		if viv_ui1 and viv_ui1.has_method("_show_external_link_warning"):
			viv_ui1._show_external_link_warning("https://antipwr.github.io", species_name)
		else:
			# Fallback to direct opening
			OS.shell_open("https://antipwr.github.io")

# Signal handlers for animal stats
func _on_health_changed(value):
	health_bar.value = value

func _on_satisfaction_changed(value):
	satisfaction_bar.value = value

func _on_hunger_changed(value):
	hunger_bar.value = value
	
	# Update nutrition bar if it exists
	if need_bars.has("nutrition"):
		need_bars["nutrition"].value = 100 - value
