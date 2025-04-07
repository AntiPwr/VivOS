class_name TerrainManipulator
extends Node2D

# Material types
enum MaterialType {
	SAND
}

# Constants
const MAX_PARTICLES = 5000  # Maximum number of particles to prevent performance issues

# Properties
var active_material: MaterialType = MaterialType.SAND
var gravity_enabled: bool = true

# Node references
var sand_layer: Node2D = null

# Cache for performance
var _particle_count: int = 0

func _ready():
	# Create material layers
	_create_material_layers()
	
	# Start physics process
	set_physics_process(gravity_enabled)
	
	print("TerrainManipulator: Ready")

# Create required material layers
func _create_material_layers():
	# Create sand layer if it doesn't exist
	sand_layer = get_node_or_null("SandLayer")
	if !sand_layer:
		sand_layer = Node2D.new()
		sand_layer.name = "SandLayer"
		add_child(sand_layer)
	
	print("TerrainManipulator: Material layers created")

# Apply material at a position
func apply_material(position: Vector2, material: MaterialType, size: float, shape_type: int):
	# Select the right layer based on material
	var layer: Node2D = null
	match material:
		MaterialType.SAND:
			layer = sand_layer
	
	# Check if we have a valid layer
	if !layer:
		push_error("TerrainManipulator: Invalid material type")
		return
	
	# Check if we've reached particle limit
	if _particle_count >= MAX_PARTICLES:
		# Remove oldest particle
		if layer.get_child_count() > 0:
			layer.get_child(0).queue_free()
			_particle_count -= 1
	
	# Create a new particle
	var particle = TerrainParticle.new()
	particle.position = position
	particle.size = size
	particle.shape_type = shape_type
	layer.add_child(particle)
	_particle_count += 1

# Physics process for gravity simulation
func _physics_process(delta):
	if gravity_enabled:
		# Apply gravity to sand particles
		for particle in sand_layer.get_children():
			if particle is TerrainParticle:
				particle.apply_gravity(delta)

# Toggle gravity simulation
func set_gravity_enabled(enabled: bool):
	gravity_enabled = enabled
	set_physics_process(gravity_enabled)

# Clear all terrain
func clear_terrain():
	# Remove all particles from all layers
	for child in sand_layer.get_children():
		child.queue_free()
	
	_particle_count = 0
	print("TerrainManipulator: Terrain cleared")

# Terrain particle class
class TerrainParticle extends Node2D:
	# Shape types
	enum {
		SHAPE_CIRCLE,
		SHAPE_SQUARE
	}
	
	# Properties
	var size: float = 10.0
	var shape_type: int = SHAPE_CIRCLE
	var gravity_speed: float = 0.0
	var settled: bool = false
	
	# Draw the particle
	func _draw():
		var color = Color(0.9, 0.8, 0.5, 1.0) # Sand color
		if shape_type == SHAPE_CIRCLE:
			draw_circle(Vector2.ZERO, size, color)
		else:
			var half_size = size
			draw_rect(Rect2(-half_size, -half_size, size*2, size*2), color, true)
	
	# Apply gravity to the particle
	func apply_gravity(delta):
		if settled:
			return
			
		# Only apply gravity if we're not settled
		gravity_speed += 98.0 * delta # Acceleration due to gravity
		var motion = Vector2(0, gravity_speed * delta)
		
		# Check for collisions with other particles
		var parent = get_parent()
		var collided = false
		
		# If we're close to the bottom of the screen, settle
		if position.y > get_viewport_rect().size.y - size * 2:
			position.y = get_viewport_rect().size.y - size * 2
			settled = true
			gravity_speed = 0
			return
		
		# Check collisions with other particles
		for other in parent.get_children():
			if other != self and other is TerrainParticle:
				var distance = position.distance_to(other.position)
				var min_distance = size + other.size
				
				if distance < min_distance:
					# Collision detected
					collided = true
					
					# Simple settling behavior - stop if we collide
					settled = true
					gravity_speed = 0
					
					# Push slightly away from the other particle
					var dir = (position - other.position).normalized()
					position += dir * (min_distance - distance) * 0.5
					break
		
		# Apply motion if not collided
		if !collided:
			position += motion
