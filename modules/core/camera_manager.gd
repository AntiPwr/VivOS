extends Node

# CameraManager: Consolidated camera management system
# Combines functionality from:
# - scene_camera.gd
# - camera_compatibility.gd
# - main_menu_camera.gd
# - camera_debug.gd

#region Camera Configuration
# Camera modes
enum CameraMode {
	MENU,       # Fixed position for menus
	VIVARIUM,   # Interactive camera for vivariums
	GENERIC     # Default for other scenes
}
var current_mode: int = CameraMode.GENERIC

# Zoom limits
@export var min_zoom_level: float = 0.2  # 0.2x magnification (most zoomed in)
@export var max_zoom_level: float = 1.0  # 1x magnification (most zoomed out)
@export var zoom_speed: float = 0.1      # How quickly zoom changes
@export var pan_speed: float = 0.4       # How quickly camera pans

# Debug options
@export var show_debug_overlay: bool = false

# Default viewport center position
var default_position: Vector2 = Vector2(1920, 1080)
#endregion

#region Runtime Variables
# Active camera reference
var active_camera: Camera2D = null

# Zoom state
var current_zoom: float = 1.0

# Input tracking
var panning: bool = false
var space_held: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO
var user_controlling: bool = false
var last_user_input_time: float = 0
var input_timeout: float = 0.5

# Target following
var is_following_target: bool = false
var follow_target: Node2D = null

# Background and bounds
var background_sprite: Sprite2D = null
var bounds: Rect2
var camera_ready: bool = false
#endregion

# Debug overlay components
var debug_overlay: CanvasLayer = null
var debug_label: Label = null

# Signals
signal zoom_changed(new_zoom)
signal mode_changed(new_mode)
signal camera_moved(new_position)

func _ready():
	print("CameraManager: Starting initialization...")
	
	# Connect to the scene tree changed signal to detect scene changes
	get_tree().connect("tree_changed", _on_scene_tree_changed)
	
	# Connect to viewport size changes
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	
	# Initialize default position based on viewport
	default_position = get_viewport().get_visible_rect().size / 2
	
	# Set up the debug overlay if enabled
	if show_debug_overlay:
		_setup_debug_overlay()
	
	# Find or create an initial camera
	_ensure_camera_exists()
	
	print("CameraManager: Initialization complete")

# Detect scene changes to update camera accordingly
func _on_scene_tree_changed():
	# Wait a frame to make sure tree is fully updated
	await get_tree().process_frame
	
	# Find active camera
	active_camera = get_viewport().get_camera_2d()
	
	if !active_camera:
		# No camera found, try to instantiate our camera scene
		_ensure_camera_exists()
		return
	
	# Detect if we're in a menu or vivarium
	var scene_root = get_tree().current_scene
	var scene_name = scene_root.name.to_lower() if scene_root else ""
	
	# Detect the scene type and configure camera
	if scene_name.contains("menu"):
		set_camera_mode(CameraMode.MENU)
	elif scene_name.contains("vivarium"):
		set_camera_mode(CameraMode.VIVARIUM)
	else:
		set_camera_mode(CameraMode.GENERIC)
	
	print("CameraManager: Scene change detected, camera mode set to: ", _mode_to_string(current_mode))

# Set camera mode and configure it appropriately
func set_camera_mode(mode: int):
	if !active_camera:
		_ensure_camera_exists()
		if !active_camera:
			return
	
	current_mode = mode
	
	match mode:
		CameraMode.MENU:
			_configure_menu_camera()
		CameraMode.VIVARIUM:
			_configure_vivarium_camera()
		CameraMode.GENERIC:
			_configure_generic_camera()
	
	emit_signal("mode_changed", current_mode)

# Configure camera for menu scenes
func _configure_menu_camera():
	if !active_camera:
		return
		
	# Menu cameras should be centered and fixed
	active_camera.position = default_position
	active_camera.enabled = true
	
	# Reset zoom
	current_zoom = 1.0
	active_camera.zoom = Vector2.ONE
	
	# Reset any active behaviors
	is_following_target = false
	follow_target = null
	panning = false
	user_controlling = false
	
	# Find the viewport center
	var viewport_size = get_viewport().get_visible_rect().size
	default_position = viewport_size / 2
	active_camera.position = default_position
	
	print("CameraManager: Configured camera for MENU mode at ", active_camera.position)

# Configure camera for vivarium scenes
func _configure_vivarium_camera():
	if !active_camera:
		return
		
	# Vivarium cameras allow zooming and panning
	active_camera.enabled = true
	
	# Find the background for bounds checking
	_find_background()
	
	# If we found a background, set position accordingly
	if background_sprite and background_sprite.texture:
		var sprite_size = background_sprite.texture.get_size() * background_sprite.scale
		bounds = Rect2(background_sprite.position - sprite_size/2, sprite_size)
		
		# Set camera limits
		active_camera.limit_left = int(background_sprite.position.x - sprite_size.x/2)
		active_camera.limit_top = int(background_sprite.position.y - sprite_size.y/2)
		active_camera.limit_right = int(background_sprite.position.x + sprite_size.x/2)
		active_camera.limit_bottom = int(background_sprite.position.y + sprite_size.y/2)
	else:
		# If no background found, use the viewport center
		active_camera.position = default_position
	
	print("CameraManager: Configured camera for VIVARIUM mode at ", active_camera.position)

# Configure camera for generic scenes
func _configure_generic_camera():
	if !active_camera:
		return
		
	# Generic cameras should be centered at the viewport center
	active_camera.enabled = true
	
	# Find the viewport center
	var viewport_size = get_viewport().get_visible_rect().size
	default_position = viewport_size / 2
	active_camera.position = default_position
	
	# Reset zoom
	current_zoom = 1.0
	active_camera.zoom = Vector2.ONE
	
	print("CameraManager: Configured camera for GENERIC mode at ", active_camera.position)

# Create or find a camera
func _ensure_camera_exists():
	# Check if there's already an active camera
	active_camera = get_viewport().get_camera_2d()
	
	if active_camera:
		print("CameraManager: Using existing camera")
		return
	
	print("CameraManager: No camera found, creating one")
	
	# Try to load our camera scene
	var camera_scene = load("res://modules/core/camera_manager.tscn")
	
	if camera_scene:
		# Instantiate the camera scene
		var camera_instance = camera_scene.instantiate()
		
		# Add to the current scene
		get_tree().current_scene.add_child(camera_instance)
		
		# Get the Camera2D node from the instance
		active_camera = camera_instance.get_node("Camera2D")
		
		if active_camera:
			active_camera.make_current()
			print("CameraManager: Created new camera from scene")
		else:
			push_error("CameraManager: Failed to get Camera2D from scene instance")
	else:
		# Create a Camera2D node directly
		active_camera = Camera2D.new()
		active_camera.name = "ManagedCamera2D"
		get_tree().current_scene.add_child(active_camera)
		active_camera.make_current()
		print("CameraManager: Created new Camera2D node")

# Find the background sprite in the scene
func _find_background():
	background_sprite = null
	
	var scene_root = get_tree().current_scene
	if scene_root:
		background_sprite = scene_root.get_node_or_null("GlassBackground")
		if !background_sprite:
			background_sprite = scene_root.find_child("GlassBackground", true, false)
		
		if background_sprite and background_sprite.texture:
			print("CameraManager: Found background with texture size ", background_sprite.texture.get_size())
		else:
			print("CameraManager: No background with texture found")

# Handle viewport size changes
func _on_viewport_size_changed():
	var viewport_size = get_viewport().get_visible_rect().size
	print("CameraManager: Viewport size changed to ", viewport_size)
	
	# Update default position
	default_position = viewport_size / 2
	
	# Reposition camera based on mode
	if current_mode == CameraMode.MENU or current_mode == CameraMode.GENERIC:
		if active_camera:
			active_camera.position = default_position
	
	# Find the background again to update bounds
	if current_mode == CameraMode.VIVARIUM:
		_find_background()

# Input handling for Vivarium mode
func _input(event):
	if current_mode != CameraMode.VIVARIUM:
		return
		
	if !active_camera:
		return
	
	# Track user input for all relevant camera inputs
	if event is InputEventMouseButton or (event is InputEventKey and event.keycode == KEY_SPACE):
		last_user_input_time = Time.get_ticks_msec() / 1000.0
		
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				user_controlling = true
				_zoom_at_point(current_zoom + zoom_speed, event.position)
				user_controlling = false
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				user_controlling = true
				_zoom_at_point(current_zoom - zoom_speed, event.position)
				user_controlling = false
			elif event.button_index == MOUSE_BUTTON_LEFT and space_held:
				# Start panning when space is held and left mouse is clicked
				panning = true
				last_mouse_position = event.position
				user_controlling = true
		elif event.button_index == MOUSE_BUTTON_LEFT:
			panning = false
			if !space_held:
				user_controlling = false
	
	# Handle spacebar for panning mode - prevent it from triggering UI events
	if event is InputEventKey and event.keycode == KEY_SPACE:
		space_held = event.pressed
		if space_held:
			# Mark the event as handled to prevent it from triggering UI buttons
			get_viewport().set_input_as_handled()
		if !space_held:
			panning = false
			user_controlling = false

# Process function for continuous camera updates
func _process(_delta):
	# Skip if no active camera
	if !active_camera:
		return
		
	# Only process movement in Vivarium mode
	if current_mode == CameraMode.VIVARIUM:
		# Handle panning movement
		if panning and space_held:
			user_controlling = true
			last_user_input_time = Time.get_ticks_msec() / 1000.0
			
			var mouse_pos = get_viewport().get_mouse_position()
			# Only move the camera if the mouse has actually moved
			if mouse_pos != last_mouse_position:
				var delta_move = (mouse_pos - last_mouse_position) * pan_speed / current_zoom
				active_camera.position -= delta_move
				last_mouse_position = mouse_pos
				
				# Ensure we stay within bounds
				_clamp_position()
				
				emit_signal("camera_moved", active_camera.position)
		
		# Handle target following
		if is_following_target and is_instance_valid(follow_target):
			user_controlling = true
			active_camera.position = active_camera.position.lerp(follow_target.position, 0.1)
			_clamp_position()
			emit_signal("camera_moved", active_camera.position)
	
	# Update debug overlay
	if show_debug_overlay and debug_label:
		_update_debug_overlay()

# Zoom the camera at the specified point
func _zoom_at_point(new_zoom: float, point: Vector2):
	if !active_camera:
		return
		
	# Clamp zoom level within bounds
	new_zoom = clamp(new_zoom, min_zoom_level, max_zoom_level)
	
	# If no real change, exit early
	if abs(new_zoom - current_zoom) < 0.01:
		return
		
	# Mark as user controlled during zoom
	user_controlling = true
	last_user_input_time = Time.get_ticks_msec() / 1000.0
		
	# Calculate offset based on mouse position
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_offset = point - viewport_size/2
	
	# Store old zoom for calculations
	var old_zoom = current_zoom
	current_zoom = new_zoom
	
	# Update camera's zoom (inverse relationship)
	active_camera.zoom = Vector2.ONE / current_zoom
	
	# Adjust position to zoom TOWARD mouse cursor
	active_camera.position += mouse_offset * (1 - (old_zoom / new_zoom))
	
	# Stay within bounds
	_clamp_position()
	
	# Notify any listeners
	emit_signal("zoom_changed", current_zoom)

# Keep camera within bounds
func _clamp_position():
	if !active_camera:
		return
		
	# Skip for non-vivarium mode
	if current_mode != CameraMode.VIVARIUM:
		return
	
	# Calculate visible area based on zoom
	var visible_rect_size = get_viewport().get_visible_rect().size / active_camera.zoom
	
	# Calculate boundaries accounting for visible area
	var min_x = active_camera.limit_left + visible_rect_size.x/2
	var max_x = active_camera.limit_right - visible_rect_size.x/2
	var min_y = active_camera.limit_top + visible_rect_size.y/2
	var max_y = active_camera.limit_bottom - visible_rect_size.y/2
	
	# Clamp position within these boundaries
	active_camera.position.x = clamp(active_camera.position.x, min_x, max_x)
	active_camera.position.y = clamp(active_camera.position.y, min_y, max_y)

# Debug functions
func _setup_debug_overlay():
	if debug_overlay:
		debug_overlay.queue_free()
	
	# Create a CanvasLayer for the debug overlay
	debug_overlay = CanvasLayer.new()
	debug_overlay.layer = 100  # Ensure it's on top
	debug_overlay.name = "CameraDebugOverlay"
	add_child(debug_overlay)
	
	# Create debug label
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow text
	debug_overlay.add_child(debug_label)
	
	# Create camera center marker
	var center_marker = ColorRect.new()
	center_marker.name = "CenterMarker"
	center_marker.size = Vector2(10, 10)
	center_marker.position = Vector2(get_viewport().get_visible_rect().size / 2) - Vector2(5, 5)
	center_marker.color = Color(1, 0, 0)  # Red marker
	debug_overlay.add_child(center_marker)
	
	print("CameraManager: Debug overlay initialized")

func _update_debug_overlay():
	if !debug_label or !active_camera:
		return
	
	# Calculate offset from background center (if any)
	var background_center = default_position
	var pos_offset = Vector2.ZERO
	
	if background_sprite and background_sprite.texture:
		background_center = background_sprite.position
		pos_offset = active_camera.position - background_center
	
	# Get camera mode as string
	var mode_string = _mode_to_string(current_mode)
	
	# Update debug text
	debug_label.text = "Camera Mode: " + mode_string + "\n" + \
					   "Camera Position: " + str(active_camera.position) + "\n" + \
					   "Background Center: " + str(background_center) + "\n" + \
					   "Offset: " + str(pos_offset) + "\n" + \
					   "Zoom: " + str(current_zoom)

func _mode_to_string(mode: int) -> String:
	match mode:
		CameraMode.MENU:
			return "MENU"
		CameraMode.VIVARIUM:
			return "VIVARIUM"
		CameraMode.GENERIC:
			return "GENERIC"
		_:
			return "UNKNOWN"

# Public API for controlling the camera
func toggle_debug_overlay(enabled: bool = true):
	show_debug_overlay = enabled
	
	if show_debug_overlay and !debug_overlay:
		_setup_debug_overlay()
	
	if debug_overlay:
		debug_overlay.visible = show_debug_overlay
		
	print("CameraManager: Debug overlay " + ("enabled" if show_debug_overlay else "disabled"))

func follow(target: Node2D):
	if current_mode != CameraMode.VIVARIUM:
		print("CameraManager: Following only supported in VIVARIUM mode")
		return
		
	if target == null:
		is_following_target = false
		follow_target = null
		return
		
	follow_target = target
	is_following_target = true
	print("CameraManager: Now following target: ", target.name)

func stop_following():
	is_following_target = false
	follow_target = null
	print("CameraManager: Stopped following target")

func get_current_camera_mode() -> String:
	return _mode_to_string(current_mode)

func set_position(pos: Vector2):
	if active_camera:
		active_camera.position = pos
		_clamp_position()
		emit_signal("camera_moved", active_camera.position)

func reset_position():
	if active_camera:
		if current_mode == CameraMode.VIVARIUM and background_sprite:
			active_camera.position = background_sprite.position
		else:
			active_camera.position = default_position
		emit_signal("camera_moved", active_camera.position)

func reset_zoom():
	current_zoom = 1.0
	if active_camera:
		active_camera.zoom = Vector2.ONE
	emit_signal("zoom_changed", current_zoom)

func get_background_bounds() -> Rect2:
	return bounds