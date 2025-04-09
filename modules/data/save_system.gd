extends Node

# =============================
# MODULE: SaveSystem
# PURPOSE: Handles saving and loading game state
# 
# PUBLIC API:
# - save_vivarium(name: String) -> bool - Saves current vivarium state
# - load_vivarium(name: String) -> bool - Loads a saved vivarium
# - get_saved_vivariums() -> Array - Returns list of saved vivariums
# - delete_vivarium(name: String) -> bool - Deletes a saved vivarium
#
# SIGNALS:
# - vivarium_saved - Emitted when a vivarium is successfully saved
# - vivarium_loaded - Emitted when a vivarium is successfully loaded
# =============================

# Vivarium data
var vivarium_name: String = "My Vivarium"
var vivarium_created_date: Dictionary
var last_saved_time: int = 0

# Signals
signal vivarium_loaded
signal vivarium_saved

func _ready():
    print("SaveSystem: Initializing...")
    vivarium_created_date = Time.get_datetime_dict_from_system()

# Set the name of the current vivarium
func set_vivarium_name(name: String):
    vivarium_name = name
    print("SaveSystem: Vivarium name set to " + name)

# Get the current vivarium name
func get_vivarium_name() -> String:
    return vivarium_name

# Save the current vivarium state
func save_vivarium() -> bool:
    print("SaveSystem: Saving vivarium: " + vivarium_name)
    
    # Create save data dictionary
    var save_data = {
        "name": vivarium_name,
        "created_date": vivarium_created_date,
        "save_date": Time.get_datetime_dict_from_system(),
        "water_params": _get_water_parameters(),
        "animals": _get_animals_data(),
        "plants": _get_plants_data(),
        "decorations": _get_decorations_data()
    }
    
    # Save to file
    var save_path = "user://saves/" + vivarium_name.replace(" ", "_") + ".save"
    
    # Create directory if it doesn't exist
    var dir = DirAccess.open("user://")
    if !dir.dir_exists("saves"):
        dir.make_dir("saves")
    
    # Save to file with error handling
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if file:
        file.store_var(save_data)
        last_saved_time = Time.get_ticks_msec()
        emit_signal("vivarium_saved")
        print("SaveSystem: Vivarium saved successfully")
        return true
    else:
        print("SaveSystem: Error saving vivarium: " + str(FileAccess.get_open_error()))
        return false

# Load a saved vivarium
func load_vivarium(name: String) -> bool:
    print("SaveSystem: Loading vivarium: " + name)
    
    # Set the vivarium name
    vivarium_name = name
    
    # Construct the save path
    var save_path = "user://saves/" + name.replace(" ", "_") + ".save"
    
    # Check if the file exists
    if !FileAccess.file_exists(save_path):
        print("SaveSystem: Save file not found: " + save_path)
        return false
    
    # Load the file
    var file = FileAccess.open(save_path, FileAccess.READ)
    if !file:
        print("SaveSystem: Error opening save file: " + str(FileAccess.get_open_error()))
        return false
    
    # Load and parse data
    var save_data = file.get_var()
    
    # Apply the loaded data
    if typeof(save_data) == TYPE_DICTIONARY:
        _apply_save_data(save_data)
        print("SaveSystem: Vivarium loaded successfully")
        emit_signal("vivarium_loaded")
        return true
    else:
        print("SaveSystem: Invalid save data format")
        return false

# Delete a saved vivarium
func delete_vivarium(name: String) -> bool:
    print("SaveSystem: Deleting vivarium: " + name)
    
    # Construct the save path
    var save_path = "user://saves/" + name.replace(" ", "_") + ".save"
    
    # Check if the file exists
    if !FileAccess.file_exists(save_path):
        print("SaveSystem: Save file not found: " + save_path)
        return false
    
    # Delete the file
    var err = DirAccess.remove_absolute(save_path)
    if err != OK:
        print("SaveSystem: Error deleting save file: " + str(err))
        return false
    
    print("SaveSystem: Vivarium deleted successfully")
    return true

# Get a list of all saved vivariums
func get_saved_vivariums() -> Array:
    var saves = []
    
    # Check if saves directory exists
    var dir = DirAccess.open("user://saves")
    if !dir:
        # Create the directory if it doesn't exist
        DirAccess.open("user://").make_dir("saves")
        return saves
    
    # List all save files
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if !dir.current_is_dir() and file_name.ends_with(".save"):
            # Extract vivarium name from filename
            var vivarium_name = file_name.replace(".save", "").replace("_", " ")
            saves.append(vivarium_name)
        file_name = dir.get_next()
    
    return saves

# Helper functions for data collection
func _get_water_parameters() -> Dictionary:
    var vivarium = get_tree().current_scene
    if vivarium and vivarium.has_method("get_water_parameters"):
        return vivarium.get_water_parameters()
    
    # Default values if method not found
    return {
        "temperature": 25.0,
        "ph": 7.0,
        "hardness": 7.0
    }

func _get_animals_data() -> Array:
    var animals_data = []
    
    var animal_manager = get_node_or_null("/root/AnimalManager")
    if animal_manager:
        var animals = get_tree().get_nodes_in_group("animals")
        for animal in animals:
            if animal.has_method("get_creature_name"):
                var animal_data = {
                    "name": animal.get_creature_name(),
                    "species": animal.species_type,
                    "position": {"x": animal.position.x, "y": animal.position.y},
                    "health": animal.health,
                    "hunger": animal.hunger,
                    "satisfaction": animal.satisfaction,
                    "age": animal.age
                }
                animals_data.append(animal_data)
    
    return animals_data

func _get_plants_data() -> Array:
    # Placeholder for future implementation
    return []

func _get_decorations_data() -> Array:
    # Placeholder for future implementation
    return []

# Apply loaded save data to current vivarium
func _apply_save_data(data: Dictionary):
    # Apply basic vivarium data
    if data.has("name"):
        vivarium_name = data.name
    
    if data.has("created_date"):
        vivarium_created_date = data.created_date
    
    # Apply water parameters
    if data.has("water_params"):
        var vivarium = get_tree().current_scene
        if vivarium and vivarium.has_method("set_water_parameters"):
            var wp = data.water_params
            vivarium.set_water_parameters(wp.temperature, wp.ph, wp.hardness)
    
    # Spawn animals from save data
    if data.has("animals"):
        var animal_manager = get_node_or_null("/root/AnimalManager")
        if animal_manager:
            # First clear existing animals
            animal_manager.clear_all_animals()
            
            # Spawn new animals from save data
            for animal_data in data.animals:
                var pos = Vector2(animal_data.position.x, animal_data.position.y)
                var animal = animal_manager.spawn_animal(animal_data.species, pos)
                
                # Apply saved properties
                if animal:
                    animal.set_creature_name(animal_data.name)
                    animal.is_named = true
                    animal.health = animal_data.health
                    animal.hunger = animal_data.hunger
                    animal.satisfaction = animal_data.satisfaction
                    animal.age = animal_data.age