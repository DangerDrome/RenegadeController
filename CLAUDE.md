# Renegade Controller — Godot 4.6 Plugin

## Project Overview

A unified character controller plugin for Godot 4.6 with a decoupled camera system, 3D mouse cursor, and zone-based camera transitions. Works for both player characters and NPCs through input abstraction.

This is a plugin for the "Renegade Cop" game — a gritty 80s third-person shooter action-RPG with Metal Gear Solid-inspired gameplay.

## Architecture

### Core Pattern: Controller Abstraction
- `ControllerInterface` — Base class. Defines the API that characters read from.
- `PlayerController` — Reads from InputMap + Cursor3D. Player-driven.
- `AIController` — Receives movement/action intents from external AI (GOAP). NPC-driven.
- `RenegadeCharacter` (CharacterBody3D) — Reads from ANY ControllerInterface. Never knows what drives it. Same script for player and NPC.

### Camera System (Player Only)
- `CameraRig` — Decoupled camera (NOT parented to character). Follows with exponential damping. Builds its own Pivot/SpringArm3D/Camera3D hierarchy at runtime if children don't exist.
- `CameraPreset` (Resource) — .tres files defining camera position, rotation, FOV, input mapping, transition curves.
- `CameraZone` (Area3D) — Level volumes that trigger camera preset transitions when player enters.
- `FirstPersonZone` — Specialized CameraZone for MGS-style first-person toggle.
- `CameraZoneManager` — Auto-discovers zones, resolves priority for overlaps, triggers transitions on CameraRig.

### 3D Cursor System
- `Cursor3D` — Raycasts from camera through mouse position. Provides aim target, detects interactables (group: "interactable"), shows visual cursor.
- Supports move-to-then-interact pattern: clicking ground emits `ground_clicked`, clicking interactable queues navigation then interaction.
- Automatically disabled during first-person mode.

### Movement Features
- Camera-relative movement (input oriented to camera forward/right)
- Fixed-axis movement (side-scroller)
- World-mapped movement (top-down)
- Strafe while aiming (character faces cursor/aim target, moves independently)
- Sprint multiplier
- Jump (spacebar)

## File Structure

```
addons/renegade_controller/
├── plugin.cfg                          # Plugin metadata
├── plugin.gd                           # Registers custom types
├── README.md                           # Usage documentation
├── demo/                               # Demo scene (full .tscn with editor nodes)
│   ├── demo_scene.tscn                 # All geo/zones/NPCs as editor nodes
│   ├── demo_scene.gd                   # Wiring script only
│   ├── debug_overlay.gd                # F3 debug HUD
│   ├── demo_interactable.gd            # Highlight-on-hover test objects
│   ├── npc_patrol.gd                   # Waypoint patrol for demo NPC
│   └── input_setup.gd                  # Runtime InputMap action setup
├── presets/                            # Camera preset .tres files
│   ├── third_person.tres
│   ├── side_scroller.tres
│   ├── top_down.tres
│   └── first_person.tres
└── src/
    ├── controllers/
    │   ├── controller_interface.gd     # Base class (virtual input API)
    │   ├── player_controller.gd        # Player input + cursor
    │   └── ai_controller.gd            # AI intent receiver
    ├── character/
    │   └── character_body.gd           # Unified CharacterBody3D movement
    ├── camera/
    │   ├── camera_preset.gd            # Resource class for camera configs
    │   └── camera_rig.gd               # Decoupled camera with transitions
    ├── cursor/
    │   └── cursor_3d.gd                # 3D mouse cursor + interactable detection
    └── zones/
        ├── camera_zone.gd              # Area3D trigger for camera presets
        ├── first_person_zone.gd        # First-person toggle zone
        └── camera_zone_manager.gd      # Priority-based zone resolution
```

## CRITICAL PATTERNS — Read Before Editing

### Setter-based signal wiring (NOT _ready)
Cross-references between nodes are assigned AFTER _ready() by demo_scene.gd. Therefore any `@export` property that needs signal connections MUST use a setter, NOT connect in `_ready()`.

**This pattern is used by:**
- `RenegadeCharacter.controller` — connects `move_to_requested` / `interact_requested`
- `PlayerController.cursor` — connects `interactable_clicked` / `ground_clicked`

**If you add a new cross-reference that needs signals, ALWAYS use this pattern:**
```gdscript
@export var my_ref: SomeNode:
    set(value):
        if my_ref and my_ref.some_signal.is_connected(_handler):
            my_ref.some_signal.disconnect(_handler)
        my_ref = value
        if my_ref:
            my_ref.some_signal.connect(_handler)
```

### CameraRig builds its own children
CameraRig checks for `has_node("Pivot")` in `_ready()`. If missing, it calls `_build_hierarchy()` to create Pivot → SpringArm3D → Camera3D. The .tscn includes these children, but runtime creation also works. Do NOT use `@onready` for pivot/spring_arm/camera — assign them after the hierarchy check.

### Camera transitions vs physics updates
`_update_third_person()` skips rotation updates while `is_transitioning == true` to avoid fighting the tween. Position follow still runs during transitions. When exiting fixed-rotation zones, the yaw is explicitly tweened toward the player's facing direction.

### AIController uses get_parent(), not owner
`AIController.move_toward_position()` uses `get_parent()` to get the CharacterBody3D position. Do NOT use `owner` — it points to the scene root, not the NPC.

### Zone collision
Camera zones use `collision_mask = 1` (default physics layer). Player must be on collision layer 1 and in the `"player"` group.

## Key Design Decisions

- **KISS principles** — No unnecessary abstraction. Composition over inheritance where practical.
- **Resource-based presets** — Camera configs are .tres files, editable in the inspector, portable between scenes.
- **Exponential damping for camera follow** — `lerp(a, b, 1.0 - exp(-speed * delta))` for frame-rate independent smoothing. Never raw lerp.
- **Group-based interactable detection** — Objects in `"interactable"` group are detected by cursor. Supports `on_cursor_enter()` / `on_cursor_exit()` / `on_interact()` callbacks.
- **Player must be in `"player"` group** — Camera zones detect the player via group membership.
- **NPCs skip camera entirely** — Just assign AIController, leave camera_rig null. Same character script.
- **Demo scene uses editor nodes** — All geometry, zones, and objects are real nodes in the .tscn. The .gd script only wires cross-references and bakes navmesh. Edit layout/colors/geo directly in the editor.

## Godot 4.6 Specifics

- Uses Jolt Physics (default in 4.6 for new 3D projects)
- Uses `reset_physics_interpolation()` on teleport
- Uses `get_gravity()` to respect Area3D gravity overrides
- SpringArm3D for third-person camera collision
- Tween-based transitions between camera presets
- `@tool` on CameraZone and CameraPreset for editor visualization

## Required Input Actions

These are set up at runtime by `InputSetup.ensure_actions()`:
- `move_forward` (W), `move_back` (S), `move_left` (A), `move_right` (D)
- `sprint` (Shift)
- `jump` (Space)
- `interact` (LMB) — cursor click / interact
- `aim` (RMB) — hold to strafe-aim
- `toggle_debug` (F3) — debug overlay

## Coding Standards

- GDScript only (no C#, no GDExtension)
- Follow Godot style guide: snake_case, type hints on all parameters and return types
- Use `@export` groups for inspector organization
- Use signals for cross-node communication, not direct references where possible
- Prefix private methods/vars with `_`
- Use `class_name` for all scripts that need to be referenced by other scripts
- Comments: doc comments on classes and public methods, inline comments only where logic is non-obvious
- No autoloads — everything is node-based and composable
- When adding new @export cross-references that need signal connections, ALWAYS use setter pattern (see Critical Patterns above)