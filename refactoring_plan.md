# RenegadeController — Refactoring Plan

## Priority Legend
- **P0** — Quick wins (low effort, high impact, safe)
- **P1** — Medium effort improvements
- **P2** — Larger refactors (require careful testing)

---

## P0: Quick Wins

### 1. Remove Debug Print Statements
**Files:** `camera_rig.gd`
**Lines affected:** ~20
**Risk:** Safe — No behavior change

Remove or gate behind `OS.is_debug_build()`:
```gdscript
# Lines to remove/modify:
# 217, 218, 219, 222, 223, 232, 233, 282, 283, 300, 301, 311, 322, 357, 658, 742, 749
```

**Action:**
```bash
# Find all print statements
grep -n "print(" src/camera/camera_rig.gd
```

---

### 2. Delete Empty FirstPersonZone Class
**File:** `src/zones/first_person_zone.gd` (37 lines)
**Risk:** Safe — Adds no functionality

The file extends `CameraZone` but adds nothing:
```gdscript
class_name FirstPersonZone extends CameraZone
# No additional methods, properties, or overrides
```

**Action:**
1. Search codebase for `FirstPersonZone` references
2. Replace with `CameraZone` + first_person preset
3. Delete `first_person_zone.gd` and `first_person_zone.gd.uid`
4. Update `plugin.gd` custom type registration if needed

---

### 3. Merge LootEntry into LootTable
**Files:** `src/inventory/loot_entry.gd` (7 lines) → `src/inventory/loot_table.gd`
**Risk:** Safe — Internal API only

`LootEntry` is only 4 properties:
```gdscript
class LootEntry extends Resource:
    @export var item: ItemDefinition
    @export var weight: float = 1.0
    @export var min_quantity: int = 1
    @export var max_quantity: int = 1
```

**Action:**
1. Move class definition into `loot_table.gd` as inner class
2. Update any `.tres` files that reference `LootEntry`
3. Delete `loot_entry.gd` and `loot_entry.gd.uid`

---

### 4. Add Constants for Magic Numbers
**File:** `camera_rig.gd`
**Lines affected:** ~10
**Risk:** Safe

```gdscript
# Add at top of CameraRig class:
const INPUT_DIRECTION_THRESHOLD := 0.7  # ~45 degrees for direction change
const VELOCITY_MOVING_THRESHOLD := 0.1  # Squared velocity to consider "moving"
const CAMERA_LOOK_THRESHOLD := 0.001    # Min direction length for look_at
const UP_VECTOR_THRESHOLD := 0.9        # When to use alternate up vector
```

---

### 5. Extract Physics Interpolation Reset Helper
**File:** `camera_rig.gd`
**Lines affected:** ~30 (5 call sites × 4 lines each → 5 lines each)
**Risk:** Safe

```gdscript
func _reset_all_interpolation() -> void:
    reset_physics_interpolation()
    if pivot:
        pivot.reset_physics_interpolation()
    if spring_arm:
        spring_arm.reset_physics_interpolation()
    if camera:
        camera.reset_physics_interpolation()
```

Replace 5 duplicate blocks with single call.

---

## P1: Medium Effort Improvements

### 6. Extract Damping Utility Functions
**Files:** `camera_rig.gd`, `cursor_3d.gd`
**Lines affected:** ~50 (25 call sites)
**Risk:** Low

Create `src/utils/math_utils.gd`:
```gdscript
class_name MathUtils

## Frame-rate independent exponential damping for floats.
static func damp(from: float, to: float, speed: float, delta: float) -> float:
    return lerpf(from, to, 1.0 - exp(-speed * delta))

## Frame-rate independent exponential damping for Vector3.
static func damp_v3(from: Vector3, to: Vector3, speed: float, delta: float) -> Vector3:
    return from.lerp(to, 1.0 - exp(-speed * delta))

## Frame-rate independent exponential damping for angles.
static func damp_angle(from: float, to: float, speed: float, delta: float) -> float:
    return lerp_angle(from, to, 1.0 - exp(-speed * delta))
```

---

### 7. Extract Camera Gizmo Utility
**Files:** `camera_zone.gd`, `default_camera_marker.gd`
**Lines affected:** ~600 (extract to new file)
**Risk:** Low — Editor-only code

Create `src/editor/camera_gizmo.gd`:
```gdscript
class_name CameraGizmo extends RefCounted

static func draw_camera_body(im: ImmediateMesh, pos: Vector3, basis: Basis) -> void:
    # ...existing code from both files...

static func draw_frustum(im: ImmediateMesh, pos: Vector3, basis: Basis, fov: float, aspect: float) -> void:
    # ...

static func draw_look_at_line(im: ImmediateMesh, from: Vector3, to: Vector3) -> void:
    # ...

# Helper methods
static func add_line(im: ImmediateMesh, start: Vector3, end: Vector3, local_transform: Transform3D) -> void:
    # ...

static func add_tri(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, local_transform: Transform3D) -> void:
    # ...

static func add_dashed_line(im: ImmediateMesh, start: Vector3, end: Vector3, ...) -> void:
    # ...

static func add_wireframe_cube(im: ImmediateMesh, center: Vector3, size: float, basis: Basis, ...) -> void:
    # ...

static func add_filled_cube(im: ImmediateMesh, ...) -> void:
    # ...
```

---

### 8. Cache Interactable Group in Cursor3D
**File:** `cursor_3d.gd`
**Lines affected:** ~30
**Risk:** Medium — Timing sensitivity

```gdscript
var _cached_interactables: Array[Node3D] = []
var _cache_valid: bool = false

func _ready() -> void:
    # ...existing code...
    get_tree().node_added.connect(_on_tree_changed)
    get_tree().node_removed.connect(_on_tree_changed)

func _on_tree_changed(_node: Node) -> void:
    _cache_valid = false

func _get_interactables() -> Array[Node3D]:
    if not _cache_valid:
        _cached_interactables.clear()
        for node in get_tree().get_nodes_in_group("interactable"):
            if node is Node3D:
                _cached_interactables.append(node)
        _cache_valid = true
    return _cached_interactables
```

---

### 9. Cache Player Meshes in CameraRig
**File:** `camera_rig.gd`
**Lines affected:** ~20
**Risk:** Low

```gdscript
var _cached_player_meshes: Array[MeshInstance3D] = []
var _player_meshes_valid: bool = false

func _get_player_meshes() -> Array[MeshInstance3D]:
    if not _player_meshes_valid and target:
        _cached_player_meshes.clear()
        _collect_meshes(target, _cached_player_meshes)
        _player_meshes_valid = true
    return _cached_player_meshes

# Invalidate when target changes
@export var target: CharacterBody3D:
    set(value):
        target = value
        _player_meshes_valid = false
```

---

### 10. Fix Editor Material Recreation
**File:** `camera_zone.gd`
**Lines affected:** ~40
**Risk:** Low — Editor-only

```gdscript
var _body_face_mat: StandardMaterial3D
var _body_line_mat: StandardMaterial3D
var _line_face_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _cross_mat: StandardMaterial3D

func _create_camera_preview() -> void:
    # Create materials once
    _body_face_mat = StandardMaterial3D.new()
    _body_face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _body_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    # ...etc

func _update_camera_preview() -> void:
    # Just update colors, don't recreate
    if _body_face_mat:
        _body_face_mat.albedo_color = face_color
    # ...
```

---

### 11. Update CLAUDE.md Documentation
**File:** `CLAUDE.md`
**Lines affected:** ~100
**Risk:** Safe

Add sections for:
1. Inventory system file structure
2. CameraSystem node
3. DefaultCameraMarker
4. Updated presets directory structure
5. New dependency relationships

---

## P2: Larger Refactors

### 12. Split CameraRig into Focused Modules
**File:** `camera_rig.gd` (1,166 lines)
**Lines affected:** 1,166 → split into ~5 files
**Risk:** Medium — Many internal references

**Proposed structure:**
```
src/camera/
├── camera_rig.gd           # Core: _ready, target follow, public API (~300 lines)
├── camera_transitions.gd   # Tween logic, mode switching (~200 lines)
├── camera_zoom.gd          # Auto-frame, idle zoom, scroll wheel (~150 lines)
├── camera_effects.gd       # Idle shake, DOF settings (~120 lines)
└── camera_collision.gd     # Raycast, player fade (~150 lines)
```

**Approach:**
1. Create child nodes or composition (not inheritance)
2. CameraRig holds references to modules
3. Modules can be optional (e.g., collision can be disabled)

**Example composition:**
```gdscript
# camera_rig.gd
var _zoom_module: CameraZoom
var _effects_module: CameraEffects
var _collision_module: CameraCollision

func _ready() -> void:
    _zoom_module = CameraZoom.new(self)
    _effects_module = CameraEffects.new(self)
    _collision_module = CameraCollision.new(self)

func _physics_process(delta: float) -> void:
    _zoom_module.update(delta)
    _effects_module.update(delta)
    if _collision_module:
        _collision_module.update(delta)
```

---

### 13. Decouple CameraRig from CameraSystem
**Files:** `camera_rig.gd`, `camera_system.gd`
**Lines affected:** ~50
**Risk:** Medium

Current problem:
```gdscript
# camera_rig.gd:299
var parent := get_parent()
if parent is CameraSystem and parent.third_person_camera:
    marker = parent.third_person_camera
```

**Solution:** Inject dependencies via exports/setters:
```gdscript
# camera_system.gd
func _ready() -> void:
    if camera_rig:
        camera_rig.default_camera_marker = third_person_camera
        camera_rig.first_person_marker = first_person_camera
```

Remove parent lookup from CameraRig entirely.

---

### 14. Standardize Null Checking Patterns
**Files:** Multiple
**Lines affected:** ~100
**Risk:** Low

Establish pattern:
- Use `is_instance_valid(node)` for any Node reference that could be freed
- Use simple `if value:` for Resources and values
- Never double-check (`if x and is_instance_valid(x)`)

```gdscript
# Before
if _camera_marker and is_instance_valid(_camera_marker):

# After
if is_instance_valid(_camera_marker):
```

---

## Implementation Order

### Phase 1: Safe Cleanup (P0)
1. Remove debug prints
2. Delete FirstPersonZone
3. Merge LootEntry
4. Add magic number constants
5. Extract interpolation reset helper

**Estimated scope:** ~100 lines changed, ~50 lines removed

### Phase 2: Utilities (P1)
1. Extract damping utility
2. Extract camera gizmo utility
3. Cache interactables
4. Cache player meshes
5. Fix editor materials
6. Update documentation

**Estimated scope:** ~400 lines changed, ~300 lines consolidated

### Phase 3: Architecture (P2)
1. Split CameraRig
2. Decouple CameraRig/CameraSystem
3. Standardize null checks

**Estimated scope:** ~600 lines refactored

---

## Testing Checklist

After each phase, verify:

### Core Functionality
- [ ] Player character moves correctly in all camera modes
- [ ] Camera follows player smoothly
- [ ] Camera transitions between zones work
- [ ] First-person mode works
- [ ] Cursor 3D works (hover, click, aim)
- [ ] Zoom (scroll wheel) works
- [ ] Idle camera behaviors work (zoom, shake)

### Editor Functionality
- [ ] Camera gizmos display correctly
- [ ] Zone collision shapes editable
- [ ] Marker positions adjustable
- [ ] Inspector properties work

### NPC Functionality
- [ ] AIController works
- [ ] NPCs move correctly
- [ ] No camera interference with NPCs

### Inventory (if modified)
- [ ] Items can be picked up
- [ ] Inventory displays correctly
- [ ] Weapon wheel works
