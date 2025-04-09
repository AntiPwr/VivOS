extends Node

# =============================
# MODULE: EventBus
# PURPOSE: Centralized event dispatching system
# 
# PUBLIC API:
# - register_event(event_name: String) -> void - Register a new event type
# - emit_event(event_name: String, args: Dictionary = {}) -> void - Emit an event
# - connect_event(event_name: String, target: Object, method: String) -> void - Connect to an event
#
# SIGNALS:
# - Many dynamic signals created at runtime
# =============================

# Registered events
var _registered_events = {}

func _ready():
    print("EventBus: Initializing...")
    
    # Register standard events
    register_standard_events()
    
    print("EventBus: Initialization complete")

# Register common events used throughout the game
func register_standard_events():
    # Animal events
    register_event("animal_spawned")
    register_event("animal_selected")
    register_event("animal_clicked")
    register_event("animal_died")
    register_event("animal_named")
    
    # Environment events
    register_event("water_parameters_changed")
    register_event("vivarium_loaded")
    register_event("vivarium_saved")
    
    # UI events
    register_event("panel_opened")
    register_event("panel_closed")
    register_event("settings_changed")
    
    # System events
    register_event("game_saved")
    register_event("game_loaded")
    register_event("scene_changed")

# Register a new event type
func register_event(event_name: String) -> void:
    if not _registered_events.has(event_name):
        _registered_events[event_name] = []
        add_user_signal(event_name)
        print("EventBus: Registered event: " + event_name)

# Emit an event with optional arguments
func emit_event(event_name: String, args: Dictionary = {}) -> void:
    if _registered_events.has(event_name):
        if args.is_empty():
            emit_signal(event_name)
        else:
            # Convert dictionary to array for emit_signal
            var args_array = []
            for arg_value in args.values():
                args_array.append(arg_value)
            
            callv("emit_signal", [event_name] + args_array)
    else:
        push_warning("EventBus: Event not registered: " + event_name)

# Connect to an event
func connect_event(event_name: String, target: Object, method: String) -> void:
    if not _registered_events.has(event_name):
        register_event(event_name)
    
    if not is_connected(event_name, Callable(target, method)):
        connect(event_name, Callable(target, method))
        print("EventBus: Connected " + target.name + "." + method + " to event " + event_name)

# Disconnect from an event
func disconnect_event(event_name: String, target: Object, method: String) -> void:
    if _registered_events.has(event_name) and is_connected(event_name, Callable(target, method)):
        disconnect(event_name, Callable(target, method))

# Check if an event exists
func has_event(event_name: String) -> bool:
    return _registered_events.has(event_name)