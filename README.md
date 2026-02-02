# Renegade Controller

A unified third-person / first-person character controller plugin for Godot 4.6. Handles player and NPC movement through the same character script using input abstraction, with a decoupled camera system that transitions between presets via level zones.

Built for "Renegade Cop" but designed to be reusable in any third-person action game.

## What It Does

**One character script, two controller types.** `RenegadeCharacter` is a `CharacterBody3D` that reads from a `ControllerInterface`. Plug in a `PlayerController` and it reads WASD + mouse. Plug in an `AIController` and it takes movement vectors from your AI system. The character doesn't know or care which one is driving it.

**Camera is not parented to the character.** The `CameraRig` sits in the scene independently and follows the player with exponential damping. Camera behavior is defined by `CameraPreset` resources — .tres files you can edit in the inspector. Drop `CameraZone` volumes in your level and the camera transitions smoothly between presets as the player walks through them.

**3D cursor with move-to-interact.** A raycast-based cursor tracks the mouse in world space, detects interactable objects, and supports click-to-move and click-to-interact-at-a-distance (character walks to the target, then interacts on arrival).

## Features

- Camera-relative, fixed-axis (side-scroller), and world-mapped (top-down) movement modes
- Sprint, jump, strafe-while-aiming (hold RMB, character faces cursor, WASD moves freely)
- Tween-based camera transitions with configurable duration, easing, and per-preset settings
- SpringArm3D collision so the camera doesn't clip through walls
- Priority-based zone resolution for overlapping camera volumes
- First-person zone with automatic player mesh hiding
- 3D cursor with hover highlighting, state-based coloring, and surface-aligned orientation
- Move-to (click ground) and move-to-then-interact (click distant object) navigation
- AI controller with `set_movement()`, `move_toward_position()`, `set_aim_target()`, action press/hold/release
- Debug overlay (F3) showing speed, camera preset, aim state, cursor hits, active zone, FPS

## Installation

1. Copy the `addons/renegade_controller/` folder into your Godot project
2. Enable the plugin: Project > Project Settings > Plugins > Renegade Controller
3. Open `addons/renegade_controller/demo/demo_scene.tscn` and hit F5 to test

The demo scene has everything set up — player, NPC, camera zones, interactables, debug overlay. All nodes are in the editor so you can move things around and tweak values directly.

## Setup (Your Own Scene)

### Required groups
- Player character must be in the `"player"` group
- Interactable objects must be in the `"interactable"` group

### Required input actions
These are created at runtime by `InputSetup.ensure_actions()` if they don't already exist:

| Action | Default Binding |
|---|---|
| `move_forward` | W |
| `move_back` | S |
| `move_left` | A |
| `move_right` | D |
| `sprint` | Shift |
| `jump` | Space |
| `interact` | Left Mouse |
| `aim` | Right Mouse |
| `toggle_debug` | F3 |

### Wiring

The minimum setup is:

```
Scene Root
├── RenegadeCharacter (CharacterBody3D)
│   ├── CollisionShape3D
│   ├── Mesh (Node3D with visual children)
│   └── PlayerController (Node)
├── CameraRig (Node3D)
│   └── Pivot / SpringArm3D / Camera3D (auto-created if missing)
├── Cursor3D (Node3D)
└── CameraZoneManager (Node)
```

Cross-references to set (in code or inspector):
- `RenegadeCharacter.controller` → PlayerController
- `RenegadeCharacter.camera_rig` → CameraRig
- `RenegadeCharacter.visual_root` → Mesh node
- `CameraRig.target` → RenegadeCharacter
- `CameraRig.default_preset` → a CameraPreset .tres
- `CameraRig.player_controller` → PlayerController
- `PlayerController.cursor` → Cursor3D
- `Cursor3D.camera` → the Camera3D inside CameraRig (assign after first frame)
- `CameraZoneManager.camera_rig` → CameraRig
- `CameraZoneManager.default_preset` → fallback CameraPreset

Note: `controller`, `cursor`, and other cross-references use property setters to connect signals. They can be assigned at any time, not just during `_ready()`.

### Adding an NPC

Same `RenegadeCharacter` script, just with `AIController` instead of `PlayerController` and no camera_rig:

```gdscript
var ai: AIController = $NPC/AIController
ai.move_toward_position(Vector3(10, 0, 5))
ai.set_aim_target(player.global_position)
ai.hold_action("aim")
```

### Camera Presets

Create a new `CameraPreset` resource (.tres) and configure in the inspector:

- `preset_name` — display name for debugging
- `offset` — position offset from target
- `spring_length` — distance from pivot to camera
- `pitch` — camera angle in degrees
- `fov` — field of view
- `input_mode` — `CAMERA_RELATIVE`, `FIXED_AXIS`, or `WORLD`
- `fixed_rotation` / `fixed_yaw` — lock camera rotation (for side-scrollers)
- `is_first_person` / `head_offset` — first-person mode settings
- `follow_speed` / `rotation_speed` — exponential damping rates
- `transition_duration` / `transition_type` / `ease_type` — how to blend in

### Camera Zones

Add a `CameraZone` (Area3D) to your scene with a CollisionShape3D, assign a CameraPreset, and set priority. When the player enters the zone, the camera transitions to that preset. When they leave, it reverts. Overlapping zones resolve by highest priority.

For first-person areas, use `FirstPersonZone` instead — it hides the player mesh and enables mouse-look.

## Interactables

Any `StaticBody3D` (or other physics body) in the `"interactable"` group will be detected by the cursor. Implement any of these optional methods:

```gdscript
func on_cursor_enter() -> void:
    # Mouse hovering over this object

func on_cursor_exit() -> void:
    # Mouse left this object

func on_interact() -> void:
    # Player clicked / arrived-and-interacted
```

The cursor walks up one parent level when checking groups, so clicking a `MeshInstance3D` child of an interactable `StaticBody3D` works automatically.

## File Reference

```
src/controllers/
  controller_interface.gd    Base class — virtual input API
  player_controller.gd       Reads InputMap + Cursor3D
  ai_controller.gd           Receives AI movement/action intents

src/character/
  character_body.gd          CharacterBody3D with movement, jump,
                             sprint, aim, strafe, move-to navigation

src/camera/
  camera_preset.gd           Resource defining camera configuration
  camera_rig.gd              Decoupled camera with tween transitions

src/cursor/
  cursor_3d.gd               3D mouse cursor, raycast, interactable detection

src/zones/
  camera_zone.gd             Area3D trigger for camera presets
  first_person_zone.gd       First-person toggle with mesh hiding
  camera_zone_manager.gd     Priority resolution for overlapping zones

demo/
  demo_scene.tscn            Complete test level (editor-editable)
  demo_scene.gd              Wiring script
  debug_overlay.gd           F3 debug HUD
  demo_interactable.gd       Test interactable with hover/bounce
  npc_patrol.gd              Simple waypoint patrol
  input_setup.gd             Runtime InputMap setup

presets/
  third_person.tres          Default over-the-shoulder
  side_scroller.tres         Fixed side view
  top_down.tres              Overhead camera
  first_person.tres          MGS-style first person
```

## Requirements

- Godot 4.6+
- 3D project with Jolt Physics (default for new 4.6 projects)

## License

MIT