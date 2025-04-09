extends "res://modules/animals/animal_base.gd"

# =============================
# MODULE: CherryShrimp
# PURPOSE: Species-specific implementation for Cherry Shrimp
# =============================

# Rate of decay for different needs
var satisfaction_decay_rate: float = 0.5  # Slower decay rate
var hunger_increase_rate: float = 0.3     # Units per second

func _ready():
    super._ready()
    
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
        var animal_manager = get_node_or_null("/root/AnimalManager")
        if animal_manager and animal_manager.animal_textures.has("Cherry Shrimp"):
            sprite.texture = animal_manager.animal_textures["Cherry Shrimp"]
        
        sprite.modulate = Color(1, 0.3, 0.3, 1)
        
    # Adjust boundaries to stay lower in tank
    boundary_min.y = (boundary_max.y - boundary_min.y) * 0.5 + boundary_min.y

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
            emit_signal("died")

func enter_moving_state():
    super.enter_moving_state()
    
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    
    # Generate random distance and angle
    var distance = rng.randf_range(50, 200)  # Smaller movement range
    var angle = rng.randf_range(0, 2 * PI)
    
    # Calculate target position
    var offset = Vector2(distance * cos(angle), distance * sin(angle))
    target_position = global_position + offset
    
    # Ensure target is within boundaries and prefers lower areas
    target_position.x = clamp(target_position.x, boundary_min.x, boundary_max.x)
    target_position.y = clamp(target_position.y, boundary_min.y, boundary_max.y)
    
    # Bottom dweller behavior - prefer lower areas
    target_position.y = lerp(target_position.y, boundary_max.y - 50, 0.7)
    
    # Update sprite direction
    if target_position.x < global_position.x and !is_flipped:
        flip_sprite()
    elif target_position.x > global_position.x and is_flipped:
        flip_sprite()

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

func _on_interact():
    # Make the shrimp move up and down a bit
    var original_pos = position
    var tween = create_tween()
    tween.tween_property(self, "position", position + Vector2(0, -10), 0.2)
    tween.tween_property(self, "position", original_pos, 0.2)
    print(get_creature_name() + " the Cherry Shrimp waves its antennae at you!")