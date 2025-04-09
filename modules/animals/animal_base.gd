extends Node2D
class_name AnimalBase

# =============================
# MODULE: AnimalBase
# PURPOSE: Base class for all animal entities
# 
# PUBLIC API:
# - get_creature_name() -> String - Returns the animal's name
# - set_creature_name(name: String) -> void - Sets the animal's name
# - has_been_named() -> bool - Returns if the animal has been named
# - feed() -> void - Feed the animal
# - pet() -> void - Pet the animal
# - select() -> void - Select the animal
# - deselect() -> void - Deselect the animal
#
# SIGNALS:
# - selected(animal) - Emitted when animal is selected
# - deselected(animal) - Emitted when animal is deselected
# - health_changed(new_value) - Emitted when health changes
# - satisfaction_changed(new_value) - Emitted when satisfaction changes
# - hunger_changed(new_value) - Emitted when hunger changes
# - state_changed(new_state) - Emitted when state changes
# - died() - Emitted when animal dies
# =============================

#region Core Properties
# Identity
var creature_name: String = ""
var is_named: bool = false
@export var species_type: String = "Unknown"

# References
@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var interaction_area: Area2D = $InteractionArea

# Base stats
var health: float = 100.0
var satisfaction: float = 100.0
var hunger: float = 0.0
var age: float = 0.0
var age_state: String = "juvenile"  # juvenile, adult, elderly
#endregion

#region Movement Properties
# State machine
enum State {IDLE, MOVING, EATING, SLEEPING, PLAYING, BREEDING}
var current_state: int = State.IDLE 
var target_position: Vector2
var is_flipped: bool = false

# Movement properties
@export var move_speed: float = 50.0
@export var min_idle_time: float = 0.5
@export var max_idle_time: float = 3.0

# Movement boundaries
var boundary_min: Vector2 = Vector2(200, 200)
var boundary_max: Vector2 = Vector2(1720, 880)

# Timers
var idle_timer: float = 0.0
#endregion

#region Traits System
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

# Water parameter preferences
var min_temp: float = 18.0
var max_temp: float = 28.0
var min_ph: float = 6.0
var max_ph: float = 8.0
var min_hardness: float = 5.0
var max_hardness: float = 15.0
#endregion

# Interaction state
var is_selected: bool = false

# Signals
signal selected(animal)
signal deselected(animal)
signal health_changed(new_value)
signal satisfaction_changed(new_value)
signal hunger_changed(new_value)
signal state_changed(new_state)
signal died()

func _ready():
    print("AnimalBase: Initializing...")
    
    # Add to animals group
    add_to_group("animals")
    
    # Initialize name label
    if name_label:
        name_label.text = ""
    
    # Set up interaction area
    _setup_interaction_area()
    
    # Start in idle state
    enter_idle_state()

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

# Core functions
func _update_needs(delta):
    # Override in specific animal implementations
    pass

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

# State management
func enter_idle_state():
    current_state = State.IDLE
    
    var rng = RandomNumberGenerator.new()
    idle_timer = rng.randf_range(min_idle_time, max_idle_time)
    
    emit_signal("state_changed", current_state)

func enter_moving_state():
    current_state = State.MOVING
    emit_signal("state_changed", current_state)
    
    # Override in specific animal implementations

func enter_eating_state():
    current_state = State.EATING
    idle_timer = 3.0
    emit_signal("state_changed", current_state)

func enter_sleeping_state():
    current_state = State.SLEEPING
    idle_timer = 10.0
    emit_signal("state_changed", current_state)

func enter_playing_state():
    current_state = State.PLAYING
    idle_timer = 5.0
    emit_signal("state_changed", current_state)

# State processing
func _process_idle(delta):
    idle_timer -= delta
    if idle_timer <= 0:
        enter_moving_state()

func _process_moving(delta):
    # Override in specific animal implementations
    pass

func _process_eating(delta):
    # Override in specific animal implementations
    pass

func _process_sleeping(delta):
    # Override in specific animal implementations
    pass

func _process_playing(delta):
    # Override in specific animal implementations
    pass

func _process_breeding(_delta):
    # Override in specific animal implementations
    pass

# User interaction handling
func _on_interaction_area_input(_viewport, event, _shape_idx):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        emit_signal("selected", self)
        
        if !is_selected:
            select()

func _on_mouse_entered():
    if !is_selected and sprite:
        sprite.modulate = sprite.modulate * 1.1

func _on_mouse_exited():
    if !is_selected and sprite:
        sprite.modulate = sprite.modulate / 1.1

func select():
    if is_selected:
        return
    
    is_selected = true
    
    if sprite:
        sprite.modulate = sprite.modulate * 1.2
    
    emit_signal("selected", self)

func deselect():
    if !is_selected:
        return
    
    is_selected = false
    
    if sprite:
        sprite.modulate = sprite.modulate / 1.2
    
    emit_signal("deselected", self)

# Public methods
func get_creature_name() -> String:
    if creature_name.is_empty():
        return "[Unnamed " + species_type + "]"
    return creature_name

func set_creature_name(new_name: String) -> void:
    if new_name.strip_edges().is_empty():
        return
        
    creature_name = new_name
    is_named = true
    
    if name_label and is_instance_valid(name_label):
        name_label.text = new_name

func has_been_named() -> bool:
    return is_named

func get_species_name() -> String:
    return species_type

func feed():
    print(get_creature_name() + " is being fed!")
    hunger = max(0, hunger - 30)
    satisfaction += 20
    satisfaction = min(100, satisfaction)
    enter_eating_state()
    
    emit_signal("hunger_changed", hunger)
    emit_signal("satisfaction_changed", satisfaction)

func pet():
    print(get_creature_name() + " is being petted!")
    satisfaction += 15
    satisfaction = min(100, satisfaction)
    enter_playing_state()
    
    emit_signal("satisfaction_changed", satisfaction)

# Helper to flip the sprite
func flip_sprite():
    if sprite:
        sprite.scale.x = -sprite.scale.x
        is_flipped = !is_flipped

# Utility functions
func generate_name_suggestion() -> String:
    var names = [
        "Bubbles", "Whiskers", "Goldie", "Flash", "Shadow", 
        "Luna", "Ripple", "Neptune", "Marina", "Pearl"
    ]
    
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    return names[rng.randi_range(0, names.size() - 1)]