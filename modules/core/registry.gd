extends Node

# =============================
# MODULE: Registry
# PURPOSE: Central access point for game systems
# 
# PUBLIC API:
# - get_animal_manager() -> Node - Returns the animal management system
# - get_save_system() -> Node - Returns the save system
# - get_ui_manager() -> Node - Returns the UI manager
# - get_camera_manager() -> Node - Returns the camera manager
# - register_system(name: String, system: Node) -> void - Registers a system
#
# SIGNALS:
# - system_registered(name) - Emitted when a new system is registered
# =============================

# System references
var _systems = {}

# Signals
signal system_registered(system_name)

func _ready():
    print("Registry: Initializing...")
    
    # Register self first
    _systems["registry"] = self
    
    # Look for and register autoload singletons
    _register_autoloads()
    
    print("Registry: Initialization complete")

# Register standard autoloads if they exist
func _register_autoloads():
    var root = get_tree().get_root()
    
    # Check for common autoloads and register them
    var autoloads = [
        "AnimalManager",
        "CameraManager",
        "SaveSystem",
        "SettingsManager",
        "DebugManager",
        "UIManager",
        "VivManager",
        "VivariumManager"
    ]
    
    for autoload in autoloads:
        var node = root.get_node_or_null(autoload)
        if node:
            register_system(autoload.to_lower(), node)
            
    # Also look for UI specific nodes in the scene tree
    var viv_ui2 = root.find_child("VivUI2", true, false)
    if viv_ui2:
        register_system("vivui2", viv_ui2)
        
    var viv_ui1 = root.find_child("VivUI1", true, false)
    if viv_ui1:
        register_system("vivui1", viv_ui1)

# Register a system for retrieval later
func register_system(system_name: String, system: Node) -> void:
    _systems[system_name.to_lower()] = system
    emit_signal("system_registered", system_name.to_lower())
    print("Registry: Registered system: " + system_name)

# Generic getter for any registered system
func get_system(system_name: String) -> Node:
    var lowered_name = system_name.to_lower()
    
    if _systems.has(lowered_name):
        return _systems[lowered_name]
    
    print("Registry: System not found: " + system_name)
    return null

# Specialized getters for common systems
func get_animal_manager() -> Node:
    return get_system("animalmanager")

func get_save_system() -> Node:
    return get_system("savesystem")

func get_ui_manager() -> Node:
    return get_system("uimanager")

func get_camera_manager() -> Node:
    return get_system("cameramanager")

func get_settings_manager() -> Node:
    return get_system("settingsmanager")

# UI specific getters
func get_viv_ui1() -> Node:
    return get_system("vivui1")
    
func get_viv_ui2() -> Node:
    return get_system("vivui2")

# Get hierarchy panel instance if it exists
func get_hierarchy_panel() -> Node:
    # First check if it exists as a registered system
    var panel = get_system("hierarchypanel")
    if panel:
        return panel
        
    # If not registered, try to find in scene tree
    var hierarchy_panel = get_tree().get_root().find_child("HierarchyPanel", true, false)
    if hierarchy_panel:
        # Register it for future use
        register_system("hierarchypanel", hierarchy_panel)
        return hierarchy_panel
    
    return null

# Get or create a system
func get_or_create_system(system_name: String, scene_path: String) -> Node:
    var system = get_system(system_name)
    if system:
        return system
    
    # Try to instantiate the system
    var scene = load(scene_path)
    if scene:
        var instance = scene.instantiate()
        get_tree().get_root().add_child(instance)
        register_system(system_name, instance)
        return instance
    
    return null