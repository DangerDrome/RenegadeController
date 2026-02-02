# Renegade Controller

Unified character controller plugin for Godot 4.6 with a decoupled camera system, 3D mouse cursor, and zone-based camera transitions. Works for both player and NPC characters through input abstraction.

## Features

- **Unified Controller** — Same `RenegadeCharacter` node for player and NPCs. Swap between `PlayerController` and `AIController` with zero code changes to movement logic.
- **Decoupled Camera Rig** — Camera exists as a separate scene, follows the character smoothly but can be repositioned to any angle via presets.
- **Camera Presets** — Resource-based `.tres` files for each camera setup. Ship with: third-person, side-scroller, top-down, and first-person.
- **Zone-Based Transitions** — Drop `CameraZone` Area3D volumes in your level. Player enters → camera smoothly transitions. Priority system handles overlaps.
- **First-Person Toggle** — `FirstPersonZone` volumes trigger MGS-style first-person mode with smooth transitions and optional mesh hiding.
- **3D Mouse Cursor** — Raycasts from camera through mouse position. Shows world-space cursor, detects interactables, provides aim direction.
- **Camera-Relative Controls** — Movement input stays correctly oriented regardless of camera angle. Side-scroller, top-down, and free camera all "just work."

## Setup

### Required Input Actions

Add these to `Project > Project Settings > Input Map`:

| Action | Suggested Binding |
|--------|------------------|
| `move_forward` | W |
| `move_back` | S |
| `move_left` | A |
| `move_right` | D |
| `sprint` | Shift |
| `interact` | Left Mouse Button |
| `aim` | Right Mouse Button |

### Player Scene Structure

```
Level (Node3D)
├── Player (RenegadeCharacter / CharacterBody3D)
│   ├── CollisionShape3D
│   ├── Mesh (Node3D)
│   │   └── YourCharacterModel
│   └── PlayerController
├── CameraRig
│   └── Pivot
│       └── SpringArm3D
│           └── Camera3D
├── Cursor3D
├── CameraZoneManager
└── ... your level geometry and zones
```

1. Add a `RenegadeCharacter` node (or use CharacterBody3D with the script)
2. Add a `PlayerController` as a child
3. Add a `CameraRig` as a **sibling** (not child) of the character
4. Add a `Cursor3D` anywhere in the scene
5. Wire up exports:
   - `RenegadeCharacter.controller` → PlayerController
   - `RenegadeCharacter.camera_rig` → CameraRig
   - `CameraRig.target` → Player
   - `CameraRig.default_preset` → `third_person.tres`
   - `CameraRig.player_controller` → PlayerController
   - `PlayerController.cursor` → Cursor3D
   - `Cursor3D.camera` → Camera3D (inside the CameraRig)
6. Add Player to the `"player"` group

### NPC Scene Structure

```
NPC (RenegadeCharacter / CharacterBody3D)
├── CollisionShape3D
├── Mesh (Node3D)
│   └── YourNPCModel
├── AIController
└── NavigationAgent3D (optional)
```

1. Add a `RenegadeCharacter` node
2. Add an `AIController` as a child
3. Set `RenegadeCharacter.controller` → AIController
4. Leave `camera_rig` as null — NPCs don't need cameras
5. Drive the AIController from your GOAP/BehaviorTree system

### Camera Zones

1. Add a `CameraZone` (or `FirstPersonZone`) to your level
2. Add a `CollisionShape3D` child defining the trigger volume
3. Set the zone's `collision_mask` to match the player's physics layer
4. Assign a `CameraPreset` resource
5. Set `priority` for overlapping zones (higher wins)
6. Add a `CameraZoneManager` and point it to your `CameraRig`

## Camera Presets

Create new presets: `Right-click in FileSystem > New Resource > CameraPreset`

### Input Modes

Each preset defines how movement input is interpreted:

| Mode | Use Case | Behavior |
|------|----------|----------|
| `CAMERA_RELATIVE` | Third-person, first-person | Input is relative to camera forward/right |
| `FIXED_AXIS` | Side-scroller | Input mapped to fixed world axes |
| `WORLD` | Top-down | Input maps directly to world X/Z |

### Included Presets

- `third_person.tres` — Standard over-shoulder (offset right, slight pitch down)
- `side_scroller.tres` — Fixed camera from the side, locked movement axis
- `top_down.tres` — Overhead view with world-mapped input
- `first_person.tres` — MGS-style first-person with mouse look

## 3D Cursor

The `Cursor3D` node provides:

- **Aim targeting** — `world_position` is where the character should aim/shoot
- **Interactable detection** — Objects in the `"interactable"` group get hover/click signals
- **Move-to** — Clicking non-interactable ground emits `ground_clicked(position)`
- **Visual feedback** — Color changes for default/hover/aim states

### Making Objects Interactable

Add your object to the `"interactable"` group. Optionally implement:

```gdscript
func on_cursor_enter() -> void:
    # Highlight, show tooltip, etc.
    pass

func on_cursor_exit() -> void:
    # Remove highlight
    pass
```

### Connecting to Interact/Move-To

```gdscript
# In your game manager or player script:
func _ready():
    player_controller.interact_requested.connect(_on_interact)
    player_controller.move_to_requested.connect(_on_move_to)

func _on_interact(target: Node3D) -> void:
    # Handle interaction with target

func _on_move_to(position: Vector3) -> void:
    # Navigate player to position
```

## AI Controller Usage

```gdscript
# From your GOAP action or behavior tree:
var ai: AIController = npc.controller

# Movement
ai.set_movement(Vector2(0, -1))          # Move forward
ai.move_toward_position(target.global_position)  # Move to world pos
ai.stop()                                 # Stop moving

# Aim
ai.set_aim_target(player.global_position) # Aim at player
ai.clear_aim_target()

# Actions
ai.press_action("shoot")                  # One-shot action
ai.hold_action("aim")                     # Hold action
ai.release_action("aim")                  # Release action
```

## Architecture

```
ControllerInterface (base)
├── PlayerController (reads InputMap + Cursor3D)
└── AIController (receives intents from AI systems)

RenegadeCharacter (CharacterBody3D)
└── Reads from any ControllerInterface — never knows what drives it

CameraRig (separate scene, not parented to character)
├── Follows target with exponential damping
├── Transitions between CameraPreset resources
└── Handles first-person/third-person mode switching

CameraZone (Area3D volumes in level)
└── CameraZoneManager resolves priority and triggers transitions

Cursor3D (raycasts from camera through mouse position)
├── Provides aim target to PlayerController
├── Detects interactables (group-based)
└── Visual cursor with state-based coloring
```
