extends Node

# =============================
# MODULE: SceneLoader
# PURPOSE: Handles loading of scenes with UI elements
# 
# PUBLIC API:
# - load_vivarium_scene() -> void - Loads the vivarium with all necessary UI components
# - ensure_ui_components(scene: Node) -> void - Makes sure a scene has all required UI components
# - has_ui_component(scene: Node, component_name: String) -> bool - Checks if a UI component exists
#
# SIGNALS:
# - scene_loading_started(scene_name) - Emitted when a scene starts loading
# - scene_loading_completed(scene_name) - Emitted when a scene is fully loaded
# =============================

# Signals
signal scene_loading_started(scene_name: String)
signal scene_loading_completed(scene_name: String)

func _ready():
	print("SceneLoader: Initialized")

# Load the vivarium scene with all necessary UI components
func load_vivarium_scene():
	print("SceneLoader: Loading vivarium scene")
	emit_signal("scene_loading_started", "vivarium")
	
	# First change to the vivarium scene
	get_tree().change_scene_to_file("res://modules/environment/vivarium.tscn")
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Ensure all UI components are present
	call_deferred("ensure_ui_components", get_tree().current_scene)
	
	# Wait a bit to make sure everything is loaded
	await get_tree().create_timer(0.2).timeout
	emit_signal("scene_loading_completed", "vivarium")

# Make sure all necessary UI components are in the scene
func ensure_ui_components(scene: Node) -> void:
	if !scene:
		print("SceneLoader: No scene provided")
		return
	
	print("SceneLoader: Ensuring UI components for scene: " + scene.name)
	
	# Check for VivUI1
	if !has_ui_component(scene, "VivUI1"):
		_add_viv_ui1(scene)
	
	# Check for VivUI2
	if !has_ui_component(scene, "VivUI2"):
		_add_viv_ui2(scene)
	
	# Check for necessary managers
	_ensure_managers()
	
	print("SceneLoader: All UI components ensured")

# Check if a UI component exists in the scene or globally
func has_ui_component(scene: Node, component_name: String) -> bool:
	# Check if the component is directly in the scene
	if scene.has_node(component_name):
		return true
	
	# Check if it's anywhere in the tree
	var component = scene.find_child(component_name, true, false)
	if component:
		return true
	
	# Check if it's a global singleton
	var global = get_node_or_null("/root/" + component_name)
	if global:
		return true
	
	return false

# Add VivUI1 to the scene
func _add_viv_ui1(scene: Node) -> void:
	var viv_ui1_scene = load("res://modules/ui/viv_ui1.tscn")
	if viv_ui1_scene:
		var viv_ui1 = viv_ui1_scene.instantiate()
		scene.add_child(viv_ui1)
		print("SceneLoader: Added VivUI1 to scene")
	else:
		push_error("SceneLoader: Could not load VivUI1 scene")

# Add VivUI2 to the scene
func _add_viv_ui2(scene: Node) -> void:
	var viv_ui2_scene = load("res://modules/ui/viv_ui2.tscn")
	if viv_ui2_scene:
		var viv_ui2 = viv_ui2_scene.instantiate()
		scene.add_child(viv_ui2)
		print("SceneLoader: Added VivUI2 to scene")
	else:
		push_error("SceneLoader: Could not load VivUI2 scene")

# Ensure necessary manager nodes exist
func _ensure_managers() -> void:
	# Dictionary of manager nodes to check and create if needed
	var managers = {
		"DebugManager": "res://modules/core/debug_manager.gd"
	}
	
	for manager_name in managers:
		if !get_node_or_null("/root/" + manager_name):
			var script_path = managers[manager_name]
			var script = load(script_path)
			if script:
				var manager = Node.new()
				manager.name = manager_name
				manager.set_script(script)
				get_tree().root.add_child(manager)
				print("SceneLoader: Added " + manager_name + " to scene")
			else:
				push_error("SceneLoader: Could not load script for " + manager_name)
