extends Node2D

# =============================
# MODULE: Vivarium
# PURPOSE: Environment container for aquatic life
# 
# PUBLIC API:
# - get_animals_container() -> Node - Returns the container for animals
# - get_water_parameters() -> Dictionary - Returns current water parameters
# - set_water_parameters(temp, ph, hardness) -> void - Updates water parameters
# - add_animal(animal) -> void - Adds an animal to the vivarium
#
# SIGNALS:
# - vivarium_ready - Emitted when the vivarium is fully initialized
# - water_parameters_changed(temp, ph, hardness) - Emitted when water params change
# =============================

# References to key components
var animals_container: Node2D
var plants_container: Node2D 
var decorations_container: Node2D
var water: Node2D
var background: Sprite2D

# UI References
var viv_ui1: CanvasLayer
var viv_ui2: Node

# Water parameters
var water_temperature: float = 25.0  # in Celsius
var water_ph: float = 7.0            # pH scale
var water_hardness: float = 7.0      # GH scale

# Signals
signal vivarium_ready
signal water_parameters_changed(temp, ph, hardness)

func _ready():
    print("Vivarium: Initializing environment...")
    
    # Find or create containers
    _setup_containers()
    
    # Find background
    background = get_node_or_null("GlassBackground")
    
    # Initialize water
    _setup_water()
    
    # Instantiate UI systems
    _instantiate_ui_systems()
    
    # Instantiate other necessary managers
    _instantiate_additional_managers()
    
    # Tell other systems we're ready
    emit_signal("vivarium_ready")
    
    print("Vivarium: Environment ready")

# Instantiate UI systems that should be present in the vivarium
func _instantiate_ui_systems():
    print("Vivarium: Setting up UI systems...")
    
    # Check if VivUI1 already exists
    viv_ui1 = get_node_or_null("VivUI1")
    
    # If not found, try to find it in the scene tree
    if not viv_ui1:
        viv_ui1 = get_tree().get_root().find_child("VivUI1", true, false)
    
    # If still not found, instantiate it
    if not viv_ui1:
        var viv_ui1_scene = load("res://modules/ui/viv_ui1.tscn")
        if viv_ui1_scene:
            viv_ui1 = viv_ui1_scene.instantiate()
            viv_ui1.name = "VivUI1"
            add_child(viv_ui1)
            print("Vivarium: VivUI1 instantiated")
        else:
            push_error("Vivarium: Could not load VivUI1 scene")
    
    # Check if VivUI2 already exists
    viv_ui2 = get_node_or_null("VivUI2")
    
    # If not found, try to find it in the scene tree
    if not viv_ui2:
        viv_ui2 = get_tree().get_root().find_child("VivUI2", true, false)
    
    # If still not found, instantiate it
    if not viv_ui2:
        var viv_ui2_scene = load("res://modules/ui/viv_ui2.tscn")
        if viv_ui2_scene:
            viv_ui2 = viv_ui2_scene.instantiate()
            viv_ui2.name = "VivUI2"
            add_child(viv_ui2)
            print("Vivarium: VivUI2 instantiated")
        else:
            push_error("Vivarium: Could not load VivUI2 scene")

# Instantiate additional manager nodes if needed
func _instantiate_additional_managers():
    print("Vivarium: Setting up additional managers...")
    
    # Check for Debug Manager and instantiate if needed
    var debug_manager = get_node_or_null("/root/DebugManager")
    if not debug_manager:
        var debug_manager_script = load("res://modules/core/debug_manager.gd")
        if debug_manager_script:
            debug_manager = Node.new()
            debug_manager.name = "DebugManager"
            debug_manager.set_script(debug_manager_script)
            add_child(debug_manager)
            print("Vivarium: DebugManager instantiated")
        else:
            print("Vivarium: DebugManager script not found")
    
    # Make sure hierarchy panel is loaded for VivUI1
    if viv_ui1:
        await get_tree().process_frame
        var hierarchy_button = viv_ui1.get_node_or_null("Control/VivPanel/HierarchyButton")
        if hierarchy_button and hierarchy_button.has_node("HierarchyPanel") == false:
            var hierarchy_panel_scene = load("res://modules/ui/panels/hierarchy_panel.tscn")
            if hierarchy_panel_scene:
                var hierarchy_panel = hierarchy_panel_scene.instantiate()
                hierarchy_panel.name = "HierarchyPanel"
                hierarchy_panel.visible = false
                hierarchy_button.add_child(hierarchy_panel)
                print("Vivarium: HierarchyPanel instantiated under HierarchyButton")
            else:
                print("Vivarium: Could not load HierarchyPanel scene")

# Set up container nodes for organization
func _setup_containers():
    # Animals container
    animals_container = get_node_or_null("Animals")
    if !animals_container:
        animals_container = Node2D.new()
        animals_container.name = "Animals"
        add_child(animals_container)
    
    # Plants container
    plants_container = get_node_or_null("Plants")
    if !plants_container:
        plants_container = Node2D.new()
        plants_container.name = "Plants"
        add_child(plants_container)
    
    # Decorations container
    decorations_container = get_node_or_null("Decorations")
    if !decorations_container:
        decorations_container = Node2D.new()
        decorations_container.name = "Decorations"
        add_child(decorations_container)

# Setup water properties
func _setup_water():
    water = get_node_or_null("Water")
    if !water:
        water = Node2D.new()
        water.name = "Water"
        add_child(water)

# Get the animals container for adding animals
func get_animals_container() -> Node:
    return animals_container

# Get the plants container for adding plants
func get_plants_container() -> Node:
    return plants_container

# Set water parameters
func set_water_parameters(temp: float, ph: float, hardness: float):
    water_temperature = temp
    water_ph = ph
    water_hardness = hardness
    emit_signal("water_parameters_changed", temp, ph, hardness)

# Get current water parameters
func get_water_parameters() -> Dictionary:
    return {
        "temperature": water_temperature,
        "ph": water_ph,
        "hardness": water_hardness
    }

# Change the background texture
func set_background(texture_path: String) -> bool:
    if !background:
        return false
        
    var texture = load(texture_path)
    if texture:
        background.texture = texture
        return true
    return false

# Add an animal to the vivarium
func add_animal(animal: Node2D) -> void:
    if animals_container and animal:
        animals_container.add_child(animal)

# Add a plant to the vivarium
func add_plant(plant: Node2D) -> void:
    if plants_container and plant:
        plants_container.add_child(plant)

# Add a decoration to the vivarium
func add_decoration(decoration: Node2D) -> void:
    if decorations_container and decoration:
        decorations_container.add_child(decoration)