extends Panel

# Hierarchy panel for viewing and managing vivarium objects
# Provides a tree view of all objects in the vivarium with filtering options

# Node references
@onready var tree: Tree = $VBoxContainer/TreeContainer/Tree
@onready var refresh_button: Button = $VBoxContainer/ButtonsContainer/RefreshButton
@onready var focus_button: Button = $VBoxContainer/ButtonsContainer/FocusButton
@onready var close_button: Button = $VBoxContainer/ButtonsContainer/CloseButton
@onready var show_animals_check: CheckBox = $VBoxContainer/FilterContainer/ShowAnimalsCheck
@onready var show_plants_check: CheckBox = $VBoxContainer/FilterContainer/ShowPlantsCheck
@onready var show_decor_check: CheckBox = $VBoxContainer/FilterContainer/ShowDecorCheck

# Tree item references
var root_item: TreeItem
var animals_category: TreeItem
var plants_category: TreeItem
var decor_category: TreeItem

# Object references
var camera: Camera2D = null
var current_selection: Node = null

# Emit when panel is closed
signal panel_closed

func _ready():
	print("HierarchyPanel: Initializing...")
	
	# Connect button signals
	refresh_button.pressed.connect(_on_refresh_pressed)
	focus_button.pressed.connect(_on_focus_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Connect filter checkboxes
	show_animals_check.toggled.connect(_on_filter_toggled)
	show_plants_check.toggled.connect(_on_filter_toggled)
	show_decor_check.toggled.connect(_on_filter_toggled)
	
	# Connect tree signals
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	
	# Setup tree
	_setup_tree()
	
	# Find camera reference
	find_camera()
	
	# Initial population
	populate_tree()
	
	print("HierarchyPanel: Initialization complete")

# Find and set camera reference
func find_camera():
	# Look for camera in the scene
	camera = get_viewport().get_camera_2d()
	
	# If not found, try to find in CameraManager
	if !camera:
		var camera_manager = get_node_or_null("/root/CameraManager")
		if camera_manager and camera_manager.has_method("get_camera"):
			camera = camera_manager.get_camera()
	
	# If still not found, try a direct search in the scene tree
	if !camera:
		camera = get_tree().get_root().find_child("Camera2D", true, false)
	
	if camera:
		print("HierarchyPanel: Camera found")
	else:
		print("HierarchyPanel: Camera not found")

# Set up the initial tree structure
func _setup_tree():
	# Clear existing tree
	tree.clear()
	
	# Create root
	root_item = tree.create_item()
	root_item.set_text(0, "Vivarium")
	
	# Create categories
	animals_category = tree.create_item(root_item)
	animals_category.set_text(0, "Animals")
	
	plants_category = tree.create_item(root_item)
	plants_category.set_text(0, "Plants")
	
	decor_category = tree.create_item(root_item)
	decor_category.set_text(0, "Decorations")

# Populate the tree with objects from the scene
func populate_tree():
	print("HierarchyPanel: Populating tree...")
	
	# Clear existing items under categories
	_clear_category_items()
	
	# Get the current scene
	var _scene = get_tree().current_scene
	
	# Handle animals - find all nodes in 'animals' group
	var animals = get_tree().get_nodes_in_group("animals")
	if show_animals_check.button_pressed:
		for animal in animals:
			_add_animal_to_tree(animal)
	
	# Handle plants - find all nodes in 'plants' group if it exists
	var plants = get_tree().get_nodes_in_group("plants")
	if show_plants_check.button_pressed:
		for plant in plants:
			_add_plant_to_tree(plant)
	
	# Handle decorations - find all nodes in 'decorations' group if it exists
	var decorations = get_tree().get_nodes_in_group("decorations")
	if show_decor_check.button_pressed:
		for decoration in decorations:
			_add_decoration_to_tree(decoration)
	
	# Update visibility of categories based on content
	_update_category_visibility()
	
	print("HierarchyPanel: Tree populated with: " + str(animals.size()) + " animals, " + 
		str(plants.size()) + " plants, " + str(decorations.size()) + " decorations")

# Clear existing items under categories
func _clear_category_items():
	# Clear animal items
	var animal_child = animals_category.get_first_child()
	while animal_child:
		var next_child = animal_child.get_next()
		animal_child.free()
		animal_child = next_child
		
	# Clear plant items
	var plant_child = plants_category.get_first_child()
	while plant_child:
		var next_child = plant_child.get_next()
		plant_child.free()
		plant_child = next_child
		
	# Clear decoration items
	var decor_child = decor_category.get_first_child()
	while decor_child:
		var next_child = decor_child.get_next()
		decor_child.free()
		decor_child = next_child

# Update visibility of categories based on filter checkboxes
func _update_category_visibility():
	animals_category.visible = show_animals_check.button_pressed
	plants_category.visible = show_plants_check.button_pressed
	decor_category.visible = show_decor_check.button_pressed

# Add an animal to the tree
func _add_animal_to_tree(animal: Node):
	if not animal or not is_instance_valid(animal):
		return
		
	var item = tree.create_item(animals_category)
	
	# Get the name to display
	var display_name = ""
	if animal.has_method("get_creature_name"):
		display_name = animal.get_creature_name()
	elif "creature_name" in animal and not animal.creature_name.is_empty():
		display_name = animal.creature_name
	else:
		display_name = animal.name
	
	# Add species info if available
	if "species_type" in animal and not animal.species_type.is_empty():
		display_name += " (" + animal.species_type + ")"
	
	# Set the text and store the object reference
	item.set_text(0, display_name)
	item.set_metadata(0, animal)
	
	# Set custom icon if available - or use default
	if animal.has_node("Sprite2D") and animal.get_node("Sprite2D").texture:
		var sprite = animal.get_node("Sprite2D")
		if sprite.texture:
			var icon_size = Vector2i(16, 16)
			var icon = sprite.texture.get_image().get_rect(Rect2i(Vector2i.ZERO, sprite.texture.get_size()))
			icon.resize(icon_size.x, icon_size.y, Image.INTERPOLATE_BILINEAR)
			var icon_texture = ImageTexture.create_from_image(icon)
			item.set_icon(0, icon_texture)

# Add a plant to the tree
func _add_plant_to_tree(plant: Node):
	var item = tree.create_item(plants_category)
	
	# Get display name
	var display_name = plant.name
	if "plant_type" in plant:
		display_name += " (" + plant.plant_type + ")"
	
	# Set the text and store reference
	item.set_text(0, display_name)
	item.set_metadata(0, plant)

# Add a decoration to the tree
func _add_decoration_to_tree(decoration: Node):
	var item = tree.create_item(decor_category)
	
	# Get display name
	var display_name = decoration.name
	if "decor_type" in decoration:
		display_name += " (" + decoration.decor_type + ")"
	
	# Set the text and store reference
	item.set_text(0, display_name)
	item.set_metadata(0, decoration)

# Button event handlers
func _on_refresh_pressed():
	# Just repopulate the tree
	populate_tree()

func _on_focus_pressed():
	# Focus camera on selected item, if any
	focus_on_selected()

func _on_close_pressed():
	# Hide the panel and emit signal
	visible = false
	emit_signal("panel_closed")

# Filter checkbox event handler
func _on_filter_toggled(_toggled_on):
	# Repopulate the tree with current filter settings
	populate_tree()

# Tree item selection event handlers
func _on_item_selected():
	var selected_item = tree.get_selected()
	if selected_item:
		var obj = selected_item.get_metadata(0)
		if obj and is_instance_valid(obj):
			current_selection = obj
			print("HierarchyPanel: Selected " + obj.name)
			
			# For animals, show info panels
			if obj.is_in_group("animals"):
				_show_animal_info(obj)
				
			# Highlight the object
			_highlight_object(obj)

func _on_item_activated():
	# When item is double-clicked, focus on it
	focus_on_selected()

# Focus the camera on the selected object
func focus_on_selected():
	if not current_selection or not is_instance_valid(current_selection):
		print("HierarchyPanel: No valid selection to focus on")
		return
		
	print("HierarchyPanel: Focusing on " + current_selection.name)
	
	# Try to use the CameraManager first
	var camera_manager = get_node_or_null("/root/CameraManager")
	if camera_manager and camera_manager.has_method("focus_on"):
		camera_manager.focus_on(current_selection)
		return
	
	# Fallback to direct camera positioning
	if camera and is_instance_valid(camera):
		camera.position = current_selection.global_position
		print("HierarchyPanel: Camera moved to " + str(current_selection.global_position))

# Show information panel for an animal
func _show_animal_info(animal):
	# Try to find VivUI1 reference first
	var viv_ui1 = get_tree().get_root().find_child("VivUI1", true, false)
	if viv_ui1 and viv_ui1.has_method("show_animal_bio_panel"):
		viv_ui1.show_animal_bio_panel(animal)
		return
	
	# Try to use UIManager if VivUI1 not found
	var ui_manager = get_node_or_null("/root/UIManager")
	if ui_manager and ui_manager.has_method("show_animal_bio_panel"):
		ui_manager.show_animal_bio_panel(animal)
		return
	
	# Try to find VivUI2 reference if other methods fail
	var viv_ui2 = get_tree().get_root().find_child("VivUI2", true, false)
	if viv_ui2 and viv_ui2.has_method("show_bio_ui"):
		viv_ui2.show_bio_ui(animal)
		return
	
	# If all else fails, just print info to console
	print("HierarchyPanel: Animal Info - " + animal.name)
	if "health" in animal:
		print("Health: " + str(animal.health))
	if "satisfaction" in animal:
		print("Satisfaction: " + str(animal.satisfaction))
	if "hunger" in animal:
		print("Hunger: " + str(animal.hunger))

# Highlight the selected object
func _highlight_object(obj):
	# For animals, use their built-in selection mechanism if available
	if obj.is_in_group("animals"):
		if obj.has_method("select"):
			obj.select()
		elif "is_selected" in obj:
			obj.is_selected = true
			
		# Deselect any other animals
		var all_animals = get_tree().get_nodes_in_group("animals")
		for animal in all_animals:
			if animal != obj:
				if animal.has_method("deselect"):
					animal.deselect()
				elif "is_selected" in animal:
					animal.is_selected = false
