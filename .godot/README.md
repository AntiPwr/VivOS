# Animal Module

This module contains all animal-related functionality including base behaviors, species-specific implementations, and animal management.

## Key Components

### Animal Base (animal_base.gd)
- Base class for all animal entities
- Handles movement, states, and interactions
- Provides common functionality like feeding and naming

### Animal Manager (animal_manager.gd)
- Manages creation and tracking of all animals
- Handles animal spawning and life cycle events
- Provides API for working with animals

### Species Implementations
- Cherry Shrimp (species/cherry_shrimp.gd)
- Dream Guppy (species/dream_guppy.gd)

## Usage Examples

### Spawning an animal
```gdscript
var animal_manager = get_node("/root/AnimalManager")
var position = Vector2(500, 500)
var animal = animal_manager.spawn_animal("Cherry Shrimp", position)