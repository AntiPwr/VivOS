extends Node

# =============================
# MODULE: UIManager
# PURPOSE: Handles core UI functionality and panel management
# 
# PUBLIC API:
# - show_panel(panel_name: String) -> Control - Shows a UI panel
# - hide_panel(panel_name: String) -> void - Hides a UI panel
# - show_dialog(message: String, title: String = "Message") -> void - Shows a message dialog
# - show_naming_dialog(animal) -> void - Shows animal naming dialog
#
# SIGNALS:
# - panel_shown(panel_name) - Emitted when a panel is shown
# - panel_hidden(panel_name) - Emitted when a panel is hidden
# - dialog_confirmed(dialog_name) - Emitted when a dialog is confirmed
# - dialog_canceled(dialog_name) - Emitted when a dialog is canceled
# =============================

# Panel references
var _panels = {}
var _panel_scenes = {}

# Current UI state
var naming_dialog_active = false
var active_animal_for_naming = null

# Signals
signal panel_shown(panel_name)
signal panel_hidden(panel_name)
signal dialog_confirmed(dialog_name)
signal dialog_canceled(dialog_name)

func _ready():
    print("UIManager: Initializing...")
    
    # Preload common UI panels
    _preload_common_panels()
    
    # Connect to core signals
    _connect_to_event_bus()
    
    print("UIManager: Initialization complete")

# Preload commonly used panel scenes
func _preload_common_panels():
    # Animal Bio panel
    _panel_scenes["animal_bio"] = preload("res://modules/ui/panels/animal_bio_panel.tscn")
    
    # Hierarchy panel
    _panel_scenes["hierarchy"] = preload("res://modules/ui/panels/hierarchy_panel.tscn")
    
    # Settings panel
    _panel_scenes["settings"] = preload("res://modules/ui/settings.tscn")
    
    # Naming dialog
    _panel_scenes["naming_dialog"] = preload("res://modules/ui/dialogs/naming_dialog.tscn")

# Connect to the event bus
func _connect_to_event_bus():
    var event_bus = get_node_or_null("/root/EventBus")
    if event_bus:
        event_bus.connect_event("animal_clicked", self, "_on_animal_clicked")
        event_bus.connect_event("animal_spawned", self, "_on_animal_spawned")
        print("UIManager: Connected to EventBus")

# Show a named panel (creating it if needed)
func show_panel(panel_name: String) -> Control:
    # If panel already exists and is valid, just show it
    if _panels.has(panel_name) and is_instance_valid(_panels[panel_name]):
        _panels[panel_name].visible = true
        emit_signal("panel_shown", panel_name)
        return _panels[panel_name]
    
    # Try to create the panel
    if _panel_scenes.has(panel_name):
        var panel = _panel_scenes[panel_name].instantiate()
        get_tree().current_scene.add_child(panel)
        
        # Store reference
        _panels[panel_name] = panel
        
        # Position panel
        _position_panel(panel)
        
        emit_signal("panel_shown", panel_name)
        return panel
    
    print("UIManager: Panel not found: " + panel_name)
    return null

# Hide a named panel
func hide_panel(panel_name: String) -> void:
    if _panels.has(panel_name) and is_instance_valid(_panels[panel_name]):
        _panels[panel_name].visible = false
        emit_signal("panel_hidden", panel_name)

# Show a simple dialog with a message
func show_dialog(message: String, title: String = "Message") -> void:
    var dialog = AcceptDialog.new()
    dialog.dialog_text = message
    dialog.title = title
    dialog.size = Vector2(300, 200)
    
    # Add to scene
    get_tree().current_scene.add_child(dialog)
    
    # Position dialog
    _position_panel(dialog)
    
    # Show dialog
    dialog.popup()
    
    # Connect close signal
    dialog.connect("confirmed", Callable(self, "_on_dialog_confirmed").bind("message_dialog"))

# Show naming dialog for an animal
func show_naming_dialog(animal) -> void:
    if naming_dialog_active:
        print("UIManager: Naming dialog already active")
        return
    
    naming_dialog_active = true
    active_animal_for_naming = animal
    
    var dialog
    if _panel_scenes.has("naming_dialog"):
        dialog = _panel_scenes["naming_dialog"].instantiate()
    else:
        # Fallback to create a simple naming dialog
        dialog = _create_simple_naming_dialog()
    
    # Add to scene
    get_tree().current_scene.add_child(dialog)
    
    # Set up dialog with animal
    if dialog.has_method("setup_for_animal"):
        dialog.setup_for_animal(animal)
    
    # Position dialog
    _position_panel(dialog)
    
    # Show dialog
    if dialog.has_method("popup"):
        dialog.popup()
    else:
        dialog.visible = true
    
    # Connect signals
    if dialog.has_signal("name_confirmed"):
        dialog.connect("name_confirmed", Callable(self, "_on_name_confirmed"))
    if dialog.has_signal("canceled"):
        dialog.connect("canceled", Callable(self, "_on_naming_canceled"))

# Create a simple naming dialog as fallback
func _create_simple_naming_dialog() -> Control:
    var dialog = AcceptDialog.new()
    dialog.title = "Name Your Animal"
    
    var vbox = VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
    
    var label = Label.new()
    label.text = "Enter a name for your animal:"
    vbox.add_child(label)
    
    var line_edit = LineEdit.new()
    line_edit.name = "NameInput"
    line_edit.placeholder_text = "Enter name..."
    vbox.add_child(line_edit)
    
    dialog.add_child(vbox)
    
    # Add custom signals to match the interface
    dialog.add_user_signal("name_confirmed", [{"name": "animal_name", "type": TYPE_STRING}])
    dialog.add_user_signal("canceled")
    
    # Connect the dialog signals to our custom ones
    dialog.connect("confirmed", Callable(self, "_relay_name_confirmed").bind(dialog))
    dialog.connect("canceled", Callable(self, "_relay_naming_canceled"))
    
    return dialog

# Helper to position a panel in the center of the viewport
func _position_panel(panel: Control) -> void:
    var viewport_size = get_viewport().get_visible_rect().size
    var panel_size = panel.size
    panel.position = (viewport_size - panel_size) / 2

# Signal handlers
func _on_dialog_confirmed(dialog_name: String) -> void:
    emit_signal("dialog_confirmed", dialog_name)

func _on_name_confirmed(name: String) -> void:
    if active_animal_for_naming and is_instance_valid(active_animal_for_naming):
        active_animal_for_naming.set_creature_name(name)
        
        var event_bus = get_node_or_null("/root/EventBus")
        if event_bus:
            event_bus.emit_event("animal_named", {"animal": active_animal_for_naming, "name": name})
    
    naming_dialog_active = false
    active_animal_for_naming = null

func _on_naming_canceled() -> void:
    naming_dialog_active = false
    
    var animal_manager = get_node_or_null("/root/AnimalManager")
    if animal_manager and active_animal_for_naming and is_instance_valid(active_animal_for_naming):
        # Only remove the animal if it was just spawned and hasn't been named yet
        if not active_animal_for_naming.has_been_named():
            animal_manager.remove_animal(active_animal_for_naming)
    
    active_animal_for_naming = null

# Helper functions for simple dialog signals
func _relay_name_confirmed(dialog: AcceptDialog) -> void:
    var name_input = dialog.get_node_or_null("NameInput")
    if name_input:
        var name_text = name_input.text
        if not name_text.is_empty():
            dialog.emit_signal("name_confirmed", name_text)

func _relay_naming_canceled() -> void:
    emit_signal("canceled")

# Event handlers
func _on_animal_clicked(animal) -> void:
    show_animal_bio_panel(animal)

func _on_animal_spawned(animal) -> void:
    if animal and not animal.has_been_named():
        show_naming_dialog(animal)

# Show bio panel for an animal
func show_animal_bio_panel(animal) -> void:
    var panel = show_panel("animal_bio")
    if panel and panel.has_method("set_animal"):
        panel.set_animal(animal)
        
# Show hierarchy panel
func show_hierarchy_panel() -> void:
    var panel = show_panel("hierarchy")
    if panel and panel.has_method("populate_tree"):
        panel.populate_tree()
        
# Show external link warning
func show_external_link_warning(url: String, species_name: String = "") -> void:
    var dialog = AcceptDialog.new()
    dialog.title = "External Link"
    
    # Use the species_name in the dialog text if provided
    var dialog_text = "You are about to visit an external website:"
    if species_name != "":
        dialog_text = "You are about to visit the " + species_name + " wiki page:"
    
    dialog.dialog_text = dialog_text + "\n" + url + "\n\nDo you want to continue?"
    dialog.add_button("Cancel", true, "cancel")
    dialog.add_button("Continue", false, "continue")
    
    dialog.confirmed.connect(func(): OS.shell_open(url))
    get_tree().current_scene.add_child(dialog)
    dialog.popup_centered()