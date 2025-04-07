extends Node2D
class_name ConsolidatedAnimal

#region Core Properties
# Identity
var creature_name: String = ""  # Empty by default, must be set by user
var is_named: bool = false  # New flag to track if animal has been properly named
@export var species_type: String = "Unknown"  # Used to determine which animal type to initialize

# References
@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var interaction_area: Area2D = $InteractionArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# Base stats
var health: float = 100.0
var satisfaction: float = 100.0
var hunger: float = 0.0
var age: float = 0.0  # In days
var age_state: String = "juvenile"  # juvenile, adult, elderly
#endregion

#region Movement Properties
# Movement variables
@export_range(0.0, 1.0, 0.1) var path_randomness: float = 0.5
@export var move_speed: float = 50.0
@export var min_move_distance: float = 100.0 
@export var max_move_distance: float = 500.0
@export var min_idle_time: float = 0.5
@export var max_idle_time: float = 3.0

# State machine
enum State {IDLE, MOVING, EATING, SLEEPING, PLAYING, BREEDING}
var current_state: int = State.IDLE 
var target_position: Vector2
var path: Array = []
var current_path_point: int = 0
var has_custom_path: bool = false

# Movement boundaries
var boundary_min: Vector2 = Vector2(200, 200)
var boundary_max: Vector2 = Vector2(1720, 880)

# Timers and state tracking
var idle_timer: float = 0.0
var is_flipped: bool = false
#endregion

#region Traits System (From animal_traits.gd)
# Behavior traits
enum BehaviorType {
	SCHOOLING,     # Animal tends to swim in groups
	PREDATOR,      # Animal hunts other animals
	PREY,          # Animal is hunted by predators
	TERRITORIAL,   # Animal defends specific areas
	SCAVENGER,     # Animal eats leftovers/detritus
	NOCTURNAL,     # Animal is more active at night
	DIURNAL,       # Animal is more active during day
	BOTTOM_DWELLER # Animal stays near the bottom
}

# Environment preferences
enum EnvironmentPreference {
	OPEN_WATER,    # Prefers swimming in open areas
	PLANT_COVER,   # Prefers areas with plants
	ROCKS,         # Prefers rocky areas
	CAVES,         # Prefers caves and hiding spots
	SURFACE,       # Prefers swimming near the surface
	SUBSTRATE      # Prefers staying near the bottom
}

# Feeding types
enum FeedingType {
	CARNIVORE,     # Eats other animals
	HERBIVORE,     # Eats plants
	OMNIVORE,      # Eats both plants and animals
	DETRITIVORE,   # Eats detritus and waste
	FILTER_FEEDER  # Filters food particles from water
}

# Animal traits
var behaviors: Array = []
var environment_prefs: Array = []
var feeding_type: int = FeedingType.OMNIVORE
var compatible_species: Array = []
var incompatible_species: Array = []

# Water parameter preferences
var min_temp: float = 18.0
var max_temp: float = 28.0
var min_ph: float = 6.0
var max_ph: float = 8.0
var min_hardness: float = 5.0
var max_hardness: float = 15.0
#endregion

#region Species-specific Properties
# Common variables that differ between species
var fins_length: float = 1.0  # For fish with fins
var shell_hardness: float = 1.0  # For crustaceans
var color_brightness: float = 1.0  # For colorful species
var is_male: bool = true  # Gender-specific traits
#endregion

#region Interaction Variables
# Selection and UI
var is_selected: bool = false
# Removed ui_panel and ui_scene references

# Dragging
var is_being_dragged: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_z_index: int = 0
var drag_z_index: int = 100  # Ensure dragged animals appear on top

# Rate of decay for different needs
var satisfaction_decay_rate: float = 1.0  # Units per second
var hunger_increase_rate: float = 0.5     # Units per second
#endregion

# Signals
signal selected(animal)
signal deselected(animal)
signal health_changed(new_value)
signal satisfaction_changed(new_value)
signal hunger_changed(new_value)
signal state_changed(new_state)
signal died()

func _ready():
	print("ConsolidatedAnimal: Initializing...")
	
	# Add to animals group
	add_to_group("animals")
	
	# No automatic naming - creature starts unnamed
	if name_label:
		name_label.text = ""
	
	# Initialize based on species type
	_initialize_species(species_type)
	
	# If sprite has no texture after initialization, try to load it
	if sprite and not sprite.texture:
		_load_default_texture()
	
	# Set up interaction area
	_setup_interaction_area()
	
	# Start in idle state
	enter_idle_state()
	
	print("ConsolidatedAnimal: " + get_creature_name() + " initialized as " + species_type)

func _initialize_species(species_name: String):
	match species_name:
		"Cherry Shrimp":
			_setup_cherry_shrimp()
		"Dream Guppy":
			_setup_dream_guppy()
		_:
			print("ConsolidatedAnimal: Unknown species type: " + species_name)
	
	# Fallback texture check after species initialization
	if sprite and not sprite.texture:
		_load_default_texture()

func _setup_cherry_shrimp():
	species_type = "Cherry Shrimp"
	
	# Movement properties
	move_speed = 30.0
	min_idle_time = 1.0
	max_idle_time = 5.0
	
	# Traits
	behaviors = [BehaviorType.PREY, BehaviorType.BOTTOM_DWELLER, BehaviorType.SCAVENGER]
	environment_prefs = [EnvironmentPreference.PLANT_COVER, EnvironmentPreference.SUBSTRATE]
	feeding_type = FeedingType.DETRITIVORE
	
	# Water preferences
	min_temp = 20.0
	max_temp = 28.0
	min_ph = 6.5
	max_ph = 8.0
	
	# Visual setup
	if sprite:
		# Get texture from animal manager
		var animal_manager = get_node_or_null("/root/AnimalManager")
		if animal_manager and animal_manager.animal_textures.has("Cherry Shrimp"):
			sprite.texture = animal_manager.animal_textures["Cherry Shrimp"]
		
		sprite.modulate = Color(1, 0.3, 0.3, 1)
		
	# Adjust boundaries to stay lower in tank
	boundary_min.y = (boundary_max.y - boundary_min.y) * 0.5 + boundary_min.y

func _setup_dream_guppy():
	species_type = "Dream Guppy"
	
	# Movement properties
	move_speed = 70.0
	min_idle_time = 0.5
	max_idle_time = 3.0
	
	# Traits
	behaviors = [BehaviorType.SCHOOLING, BehaviorType.PREY]
	environment_prefs = [EnvironmentPreference.OPEN_WATER, EnvironmentPreference.PLANT_COVER]
	feeding_type = FeedingType.OMNIVORE
	compatible_species = ["Cherry Shrimp"]
	
	# Water preferences
	min_temp = 22.0
	max_temp = 28.0
	
	# Visual setup
	if sprite:
		# Get texture from animal manager
		var animal_manager = get_node_or_null("/root/AnimalManager")
		if animal_manager and animal_manager.animal_textures.has("Dream Guppy"):
			sprite.texture = animal_manager.animal_textures["Dream Guppy"]
			
		# Gender dimorphism
		if is_male:
			sprite.modulate = Color(0.8, 0.9, 1.0, 1.0)
		else:
			sprite.modulate = Color(0.7, 0.7, 0.8, 1.0)

# Helper to load default texture if none was assigned
func _load_default_texture():
	if not sprite:
		return
		
	# Try to get the texture from the AnimalManager singleton
	var animal_manager = get_node_or_null("/root/AnimalManager")
	if animal_manager and animal_manager.animal_textures.has(species_type):
		sprite.texture = animal_manager.animal_textures[species_type]
		print("ConsolidatedAnimal: Loaded default texture for " + species_type)
	else:
		print("ConsolidatedAnimal: Warning - Could not find default texture for " + species_type)

#region State Management
func _process(delta):
	# Update needs over time
	_update_needs(delta)
	
	# State machine processing
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.EATING:
			_process_eating(delta)
		State.SLEEPING:
			_process_sleeping(delta)
		State.PLAYING:
			_process_playing(delta)
		State.BREEDING:
			_process_breeding(delta)

func _update_needs(delta):
	# Update satisfaction
	var old_satisfaction = satisfaction
	satisfaction -= satisfaction_decay_rate * delta
	satisfaction = clamp(satisfaction, 0.0, 100.0)
	if old_satisfaction != satisfaction:
		emit_signal("satisfaction_changed", satisfaction)
	
	# Update hunger
	var old_hunger = hunger
	hunger += hunger_increase_rate * delta
	hunger = clamp(hunger, 0.0, 100.0)
	if old_hunger != hunger:
		emit_signal("hunger_changed", hunger)
	
	# Health decreases if hunger is too high
	if hunger > 80.0:
		var old_health = health
		health -= (0.5 * (hunger - 80.0) / 20.0) * delta
		health = clamp(health, 0.0, 100.0)
		if old_health != health:
			emit_signal("health_changed", health)
		
		# Check for death
		if health <= 0:
			_die()

func _die():
	print("ConsolidatedAnimal: " + creature_name + " has died")
	emit_signal("died")
	# Could add a death animation here
	queue_free()

func _process_idle(delta):
	idle_timer -= delta
	if idle_timer <= 0:
		enter_moving_state()

func _process_moving(delta):
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)
	
	if distance > 5: # Keep moving if not close enough
		global_position += direction * move_speed * delta
		
		# Update sprite direction
		if direction.x < 0 and !is_flipped:
			flip_sprite()
		elif direction.x > 0 and is_flipped:
			flip_sprite()
	else:
		# Enter idle when destination reached
		enter_idle_state()

func _process_eating(delta):
	# Example implementation
	satisfaction += 5 * delta
	hunger -= 10 * delta
	satisfaction = clamp(satisfaction, 0.0, 100.0)
	hunger = clamp(hunger, 0.0, 100.0)
	
	emit_signal("satisfaction_changed", satisfaction)
	emit_signal("hunger_changed", hunger)
	
	idle_timer -= delta
	if idle_timer <= 0:
		enter_idle_state()

func _process_sleeping(delta):
	# Example implementation
	satisfaction += 2 * delta
	satisfaction = clamp(satisfaction, 0.0, 100.0)
	emit_signal("satisfaction_changed", satisfaction)
	
	idle_timer -= delta
	if idle_timer <= 0:
		enter_idle_state()

func _process_playing(delta):
	# Example implementation
	satisfaction += 10 * delta
	hunger += 2 * delta
	satisfaction = clamp(satisfaction, 0.0, 100.0)
	hunger = clamp(hunger, 0.0, 100.0)
	
	emit_signal("satisfaction_changed", satisfaction)
	emit_signal("hunger_changed", hunger)
	
	idle_timer -= delta
	if idle_timer <= 0:
		enter_idle_state()

func _process_breeding(_delta):
	# Future implementation
	pass

func enter_idle_state():
	var old_state = current_state
	current_state = State.IDLE
	
	# Reset the idle timer
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	idle_timer = rng.randf_range(min_idle_time, max_idle_time)
	
	if old_state != current_state:
		emit_signal("state_changed", current_state)

func enter_moving_state():
	var old_state = current_state
	current_state = State.MOVING
	
	# Generate a random target position if no custom path exists
	if !has_custom_path:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		
		# Generate random distance and angle
		var distance = rng.randf_range(min_move_distance, max_move_distance)
		var angle = rng.randf_range(0, 2 * PI)
		
		# Calculate target position
		var offset = Vector2(distance * cos(angle), distance * sin(angle))
		target_position = global_position + offset
		
		# Ensure target is within boundaries
		target_position.x = clamp(target_position.x, boundary_min.x, boundary_max.x)
		target_position.y = clamp(target_position.y, boundary_min.y, boundary_max.y)
		
		# Apply bottom-dweller correction
		if behaviors.has(BehaviorType.BOTTOM_DWELLER):
			target_position.y = clamp(target_position.y, boundary_max.y - 200, boundary_max.y - 50)
	
	# Update sprite direction based on target position
	if target_position.x < global_position.x and !is_flipped:
		flip_sprite()
	elif target_position.x > global_position.x and is_flipped:
		flip_sprite()
		
	if old_state != current_state:
		emit_signal("state_changed", current_state)

func enter_eating_state():
	var old_state = current_state
	current_state = State.EATING
	idle_timer = 3.0  # Eat for 3 seconds
	
	if old_state != current_state:
		emit_signal("state_changed", current_state)

func enter_sleeping_state():
	var old_state = current_state
	current_state = State.SLEEPING
	idle_timer = 10.0  # Sleep for 10 seconds
	
	if old_state != current_state:
		emit_signal("state_changed", current_state)

func enter_playing_state():
	var old_state = current_state
	current_state = State.PLAYING
	idle_timer = 5.0  # Play for 5 seconds
	
	if old_state != current_state:
		emit_signal("state_changed", current_state)
#endregion

#region Interaction Handling
func _setup_interaction_area():
	if interaction_area:
		# Connect input events
		if !interaction_area.is_connected("input_event", Callable(self, "_on_interaction_area_input")):
			interaction_area.connect("input_event", Callable(self, "_on_interaction_area_input"))
		
		# Connect mouse enter/exit events
		if !interaction_area.is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
			interaction_area.connect("mouse_entered", Callable(self, "_on_mouse_entered"))
		if !interaction_area.is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
			interaction_area.connect("mouse_exited", Callable(self, "_on_mouse_exited"))
		
		# Enable monitoring and monitorable
		interaction_area.monitoring = true
		interaction_area.monitorable = true
		
	else:
		push_error("ConsolidatedAnimal: InteractionArea not found for " + creature_name)

func _on_interaction_area_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if !is_selected:
			select()
		else:
				# Simply notify that it was clicked again while selected
				emit_signal("selected", self)

func select():
	if is_selected:
		return
	
	is_selected = true
	
	# Show selection effect
	if sprite:
		sprite.modulate = sprite.modulate * 1.2
	
	emit_signal("selected", self)
	
	print(creature_name + " selected")
	
	# Animate on selection
	_on_interact()

func deselect():
	if !is_selected:
		return
	
	is_selected = false
	
	# Remove selection effect
	if sprite:
		sprite.modulate = sprite.modulate / 1.2
	
	emit_signal("deselected", self)
	
	print(creature_name + " deselected")

func _on_mouse_entered():
	if !is_selected and sprite:
		sprite.modulate = sprite.modulate * 1.1

func _on_mouse_exited():
	if !is_selected and sprite:
		sprite.modulate = sprite.modulate / 1.1

# Helper function to flip the sprite
func flip_sprite():
	if sprite:
		sprite.scale.x = -sprite.scale.x
		is_flipped = !is_flipped
#endregion

#region Species-specific Interactions
func _on_interact():
	match species_type:
		"Cherry Shrimp":
			# Make the shrimp move up and down a bit
			var original_pos = position
			var tween = create_tween()
			tween.tween_property(self, "position", position + Vector2(0, -10), 0.2)
			tween.tween_property(self, "position", original_pos, 0.2)
			print(creature_name + " the Cherry Shrimp waves its antennae at you!")
			
		"Dream Guppy":
			# Make the fish do a little spin
			var original_rotation = rotation
			var tween = create_tween()
			tween.tween_property(self, "rotation", original_rotation + 6.28, 0.5)
			tween.tween_property(self, "rotation", original_rotation, 0.3)
			print(creature_name + " the Dream Guppy swims excitedly!")
			
		_:
			print(creature_name + " notices you!")

func feed():
	print(creature_name + " is being fed!")
	hunger = max(0, hunger - 30)
	satisfaction += 20
	satisfaction = min(100, satisfaction)
	enter_eating_state()
	
	emit_signal("hunger_changed", hunger)
	emit_signal("satisfaction_changed", satisfaction)

func pet():
	print(creature_name + " is being petted!")
	satisfaction += 15
	satisfaction = min(100, satisfaction)
	enter_playing_state()
	
	emit_signal("satisfaction_changed", satisfaction)
#endregion

#region Utility Functions
# Helper function to generate a random name for the animal
func _generate_random_name() -> String:
	var adjectives = [
		"Swift", "Curious", "Playful", "Sleepy", "Happy", 
		"Lazy", "Brave", "Shy", "Gentle", "Clever",
		"Friendly", "Speedy", "Fluffy", "Tiny", "Big"
	]
	
	var nouns = [
		"Whiskers", "Bubbles", "Paws", "Spots", "Shadow",
		"Muffin", "Nibbles", "Blossom", "Scout", "Pebble",
		"Buddy", "Storm", "Pixel", "Dash", "Luna"
	]
	
	# Select random elements
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var adj_index = rng.randi_range(0, adjectives.size() - 1)
	var noun_index = rng.randi_range(0, nouns.size() - 1)
	
	# Combine to create the name
	return adjectives[adj_index] + " " + nouns[noun_index]

# Helper function to generate a random name suggestion for the animal
func generate_name_suggestion() -> String:
	var names = [
		"Bubbles", "Whiskers", "Goldie", "Flash", "Shadow", 
		"Luna", "Ripple", "Neptune", "Marina", "Pearl",
		"Coral", "Nemo", "Finn", "Shimmer", "Splash", 
		"Azure", "Indigo", "Jet", "Scarlet", "Ruby",
		"Amber", "Jade", "Opal", "Sapphire", "Crystal"
	]
	
	# Select random element
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var name_index = rng.randi_range(0, names.size() - 1)
	
	# Return the single name
	return names[name_index]

# Update the animal's name - can be called externally
func set_creature_name(new_name: String) -> void:
	if new_name.strip_edges().is_empty():
		return  # Don't allow empty names
		
	creature_name = new_name
	is_named = true
	
	if name_label and is_instance_valid(name_label):
		name_label.text = new_name
		print("ConsolidatedAnimal: Updated name label to: " + new_name)
	else:
		print("ConsolidatedAnimal: No name label found for: " + new_name)

# Allow other scripts to properly get the name
func get_creature_name() -> String:
	if creature_name.is_empty():
		return "[Unnamed " + species_type + "]"
	return creature_name

# Check if the animal has been properly named
func has_been_named() -> bool:
	return is_named

# Get species name
func get_species_name() -> String:
	return species_type

# Set a custom destination for the animal to move to
func set_destination(dest: Vector2):
	target_position = dest
	has_custom_path = true
	enter_moving_state()
#endregion
