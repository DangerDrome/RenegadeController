# Universal Door Plugin for Godot 4.6

A flexible door system handling all door types with built-in teleportation support.

## Installation

1. Copy the `addons/universal_door` folder into your project's `addons/` directory
2. In Godot: **Project → Project Settings → Plugins**
3. Enable "Universal Door"

## Features

- **5 Door Types**: Normal (hinged), Sliding, Garage, Elevator (dual panel), Custom
- **Teleporter**: Link doors together for instant travel
- **Auto-open**: Trigger zones for hands-free operation
- **Auto-close**: Configurable delay with occupancy detection
- **Locking**: Lock/unlock support with audio feedback
- **Procedural Animation**: No animation assets required (uses Tweens)
- **Custom Animation**: Full AnimationPlayer support for complex doors
- **Editor Preview**: Toggle `preview_open` to see door positions in editor
- **Configuration Warnings**: Helpful warnings for missing nodes

## Quick Start

### Method 1: Use the Scene Template
1. Instance `res://addons/universal_door/universal_door.tscn`
2. Add your mesh to `DoorBody/MeshInstance3D`
3. Set collision shape on `DoorBody/CollisionShape3D`
4. Configure via inspector

### Method 2: Add Node Directly
1. Add a new node, search for "UniversalDoor"
2. Add child structure manually (see Scene Structure below)

### Method 3: Runtime via DoorFactory
```gdscript
var mesh := BoxMesh.new()
mesh.size = Vector3(1, 2, 0.1)
var shape := BoxShape3D.new()
shape.size = mesh.size

var door := DoorFactory.create_sliding_door(mesh, shape, 1.5)
add_child(door)
door.position = Vector3(5, 0, 0)
```

## Door Types

| Type | `open_amount` | Movement |
|------|---------------|----------|
| NORMAL | Degrees | Rotates on Y-axis |
| SLIDING | Units | Slides on X-axis |
| GARAGE | Units | Slides on Y-axis (up) |
| ELEVATOR | Total width | Two panels split apart |
| CUSTOM | N/A | Uses AnimationPlayer |

## Teleporter Setup

### Direct Reference (Editor)
```
Door A: teleport_target → Door B
Door B: teleport_target → Door A  (for bidirectional)
```

### Group-Based (Runtime-friendly)
```gdscript
# Both doors:
door.teleport_enabled = true
door.teleport_target_group = &"portal_pair_1"
door.add_to_group("portal_pair_1")
```

### Via Factory
```gdscript
DoorFactory.create_teleport_pair(door_a, door_b, true)  # bidirectional
DoorFactory.create_teleport_network([door_a, door_b, door_c], &"portal_network")
```

## Signals

```gdscript
signal door_opened
signal door_closed
signal teleport_triggered(target_door: UniversalDoor)
signal player_entered_zone
signal player_exited_zone
```

## Public API

```gdscript
# Control
door.open()
door.close()
door.toggle()
door.interact()  # Respects interaction_enabled

# Locking
door.lock()
door.unlock()

# Teleport
door.teleport_entity(player)

# State
door.is_open() -> bool
door.is_closed() -> bool
door.state  # DoorState enum
```

## Scene Structure

```
UniversalDoor (Node3D + script)
├── DoorBody (AnimatableBody3D)     # The moving door
│   ├── MeshInstance3D              # Your door mesh
│   ├── CollisionShape3D            # Door collision
│   ├── LeftPanel (Node3D)          # For elevator type (hidden by default)
│   └── RightPanel (Node3D)         # For elevator type (hidden by default)
├── DetectionZone (Area3D)          # Auto-open trigger
│   └── CollisionShape3D            # Detection area
├── AudioStreamPlayer3D             # Door sounds
└── AnimationPlayer                 # For custom animations
```

## Interaction Example

```gdscript
# Player.gd
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        var door := _raycast_for_door()
        if door:
            door.interact()

func _raycast_for_door() -> UniversalDoor:
    var space := get_world_3d().direct_space_state
    var from := global_position + Vector3.UP * 1.5
    var to := from - global_basis.z * 2.0
    var query := PhysicsRayQueryParameters3D.create(from, to)
    var result := space.intersect_ray(query)
    
    if result and result.collider.get_parent() is UniversalDoor:
        return result.collider.get_parent()
    return null
```

## Tips

1. **Detection Zone**: Position/size it where you want auto-open to trigger
2. **Collision Layers**: Set `detection_layer` to match your player's physics layer
3. **AnimatableBody3D**: Chosen over StaticBody3D so doors push the player smoothly
4. **Elevator Panels**: Enable visibility on LeftPanel/RightPanel, add meshes and colliders to each
5. **Editor Preview**: Toggle `preview_open` to see the door's open state while designing
6. **Locked Feedback**: Assign `locked_sound` for audio cue when player tries locked doors

## Godot 4.6 Features Used

- `@tool` for editor preview
- `@icon` for custom node icon
- `class_name` for global type registration
- `@export_group` for organized inspector
- `@export_flags_3d_physics` for layer mask picker
- `_get_configuration_warnings()` for helpful editor warnings
- `StringName` literals (`&"string"`) for performance
- `AnimatableBody3D` for smooth kinematic movement
- `Tween.parallel()` for synchronized animations
- Typed signals with parameters
