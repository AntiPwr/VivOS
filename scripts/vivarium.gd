extends Node2D

# Base Vivarium script
# Handles core vivarium functionality

# References
@onready var animals_container = $Animals
@onready var glass_background = $GlassBackground

# Signals
signal animal_added(animal)
signal animal_removed(animal)

func _ready():
	print("Vivarium: Initializing...")
	
	# Connect to the animal manager for spawned animals
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if animal_manager:
		animal_manager.animal_spawned.connect(_on_animal_spawned)
	
	print("Vivarium: Initialization complete")

# Handle animal spawned by the animal manager
func _on_animal_spawned(animal):
	print("Vivarium: Animal added: " + animal.get_creature_name())
	emit_signal("animal_added", animal)

# Spawn an animal at a specific position
func spawn_animal(species_type: String, position: Vector2):
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if animal_manager:
		return animal_manager.spawn_animal(species_type, position, animals_container)
	return null

# Get the list of all animals in the vivarium
func get_animals():
	if animals_container:
		return animals_container.get_children()
	return []

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var settings_panel = get_node_or_null("SettingsPanel")
		if settings_panel:
			if settings_panel.has_method("toggle_menu"):
				settings_panel.toggle_menu()
			else:
				settings_panel.visible = !settings_panel.visible
				get_tree().paused = settings_panel.visible
