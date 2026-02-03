# RenegadeController Plugin — Comprehensive Audit Report

> **Note:** This audit has been partially implemented. See `## Changes Implemented` section at the end for what's been fixed.

## Summary Statistics

| Metric | Value |
|--------|-------|
| **Total GDScript files** | 38 |
| **Total lines of code** | ~6,800 |
| **Total .tres resources** | 13 |
| **Total .tscn scenes** | 10 |
| **Classes defined** | 32 |
| **Signals defined** | ~45 |
| **@export properties** | ~180 |

### Largest Files (>300 lines)

| File | Lines | Assessment |
|------|-------|------------|
| `camera_rig.gd` | 938 | **FIXED** — Reduced from 1,179 lines (split into modules) |
| `cursor_3d.gd` | 585 | Moderate — Could be split |
| `camera_zone_inspector.gd` | 522 | Moderate — Editor tool |
| `camera_zone.gd` | 392 | **FIXED** — Reduced from 617 lines |
| `character_body.gd` | 354 | Acceptable |
| `default_camera_marker.gd` | 280 | **FIXED** — Reduced from 463 lines |

---

## Critical Issues (Must Fix)

### 1. `camera_rig.gd` is 1,166 lines — Monolithic god class
**File:** `src/camera/camera_rig.gd`
**Impact:** Hard to maintain, hard to test, violates single responsibility

The CameraRig class handles:
- Target following (third-person)
- First-person mode
- Marker/zone camera mode
- Transitions between all modes
- Zoom (scroll wheel, auto-framing, idle zoom)
- Idle shake effects
- DOF settings
- Collision detection
- Player mesh transparency
- Input direction calculation

**Recommendation:** Extract into focused modules:
- `CameraFollower` — Position/rotation follow logic
- `CameraTransitions` — Tween-based mode switching
- `CameraZoom` — Auto-framing, idle zoom, scroll zoom
- `CameraEffects` — Idle shake, DOF
- `CameraCollision` — Raycast collision + player fade

### 2. Debug `print()` statements in production code
**Files:** `camera_rig.gd:217-233, 282-323, 357, 658, 742, 749`
**Impact:** Console spam, performance overhead

```gdscript
print("CameraRig.transition_to: Using marker at ", camera_marker.global_position)
print("CameraRig.reset_to_default: Called")
print(">>> _transition_to_marker: FOLLOW MODE - progress-based from ", camera_world_pos)
```

**Recommendation:** Remove all debug prints or gate behind `OS.is_debug_build()`.

### 3. Duplicate editor visualization code
**Files:** `camera_zone.gd:225-617`, `default_camera_marker.gd:159-462`
**Impact:** ~600 lines of near-identical ImmediateMesh camera gizmo drawing

Both files implement:
- `_create_camera_preview()`
- `_update_camera_preview()`
- `_add_line()`, `_add_tri()`, `_add_dashed_line()`
- `_add_wireframe_cube()`, `_add_filled_cube()`
- Camera body/lens/frustum rendering

**Recommendation:** Extract to shared `CameraGizmo` utility class.

### 4. Missing type hints on several variables
**Files:** Multiple
**Impact:** Reduced type safety, IDE autocomplete issues

Examples:
```gdscript
# camera_rig.gd:113 - should be typed
var current_preset: CameraPreset  # OK
var _camera_marker: Marker3D  # OK but could be DefaultCameraMarker|Marker3D union

# camera_zone.gd:63
var _debug_label: Label3D  # OK

# But many internal vars lack hints
var result := _space_state.intersect_ray(query)  # Inferred, but explicit would be clearer
```

---

## Recommended Improvements (Should Fix)

### 5. `get_tree().get_nodes_in_group()` called every frame
**Files:**
- `cursor_3d.gd:230` — Called in `_apply_sticky()` every `_physics_process`
- `camera_zone.gd:78` — Called in `get_look_at_node()` at runtime

**Impact:** O(n) scan every frame for sticky cursor

**Recommendation:** Cache group results and invalidate on `tree_changed` signal, or use an Area3D overlap check instead.

### 6. Redundant exponential smoothing pattern
**Files:** Throughout `camera_rig.gd`, `cursor_3d.gd`
**Pattern:** `lerp(a, b, 1.0 - exp(-speed * delta))`

This exact pattern appears 25+ times. Consider a utility function:
```gdscript
static func damp(from: float, to: float, speed: float, delta: float) -> float:
    return lerpf(from, to, 1.0 - exp(-speed * delta))

static func damp_v3(from: Vector3, to: Vector3, speed: float, delta: float) -> Vector3:
    return from.lerp(to, 1.0 - exp(-speed * delta))
```

### 7. Tightly coupled CameraRig and CameraSystem
**Files:** `camera_rig.gd:299-309`, `camera_system.gd`
**Issue:** CameraRig reaches up to parent to find markers

```gdscript
var parent := get_parent()
if parent is CameraSystem and parent.third_person_camera:
    marker = parent.third_person_camera
```

**Recommendation:** CameraSystem should inject markers via exports/setters, not discovered at runtime.

### 8. Inventory system not documented in CLAUDE.md
**Files:** `src/inventory/*.gd` (16 files)
**Impact:** CLAUDE.md file structure section is outdated

The inventory system was added but not documented:
- `Inventory`, `InventorySlot`, `ItemSlots`
- `ItemDefinition`, `WeaponDefinition`, `GearDefinition`, `ConsumableDefinition`
- `WeaponManager`, `EquipmentManager`, `WeaponWheel`
- `LootTable`, `LootEntry`, `LootDropper`
- UI: `InventoryGridUI`, `InventorySlotUI`, `ItemInfoPanel`
- `WorldPickup`

### 9. Inconsistent null checking patterns
**Files:** Multiple
**Issue:** Mix of `if x:`, `if x != null:`, `is_instance_valid(x)`

```gdscript
# camera_rig.gd - inconsistent
if _camera_marker and is_instance_valid(_camera_marker):  # Double check
if default_camera_marker:  # Single check
if target:  # Single check
```

**Recommendation:** Standardize on `is_instance_valid()` for node references that could be freed.

### 10. Magic numbers scattered throughout
**Files:** `camera_rig.gd`, `cursor_3d.gd`, `camera_zone.gd`

```gdscript
# camera_rig.gd:452 - unexplained threshold
if old_dir.dot(new_dir) < 0.7:

# camera_rig.gd:980 - unexplained threshold
var is_moving := target.velocity.length_squared() > 0.1

# camera_zone.gd:299 - unexplained dimensions
var body_w := 0.25
var body_h := 0.3
var body_d := 0.4
```

**Recommendation:** Extract to named constants with doc comments.

---

## Optional Optimizations (Nice to Have)

### 11. `_collect_meshes()` recursive traversal every frame during collision fade
**File:** `camera_rig.gd:879-893`
**Impact:** Allocates new Array each frame, traverses entire player hierarchy

```gdscript
func _get_player_meshes() -> Array[MeshInstance3D]:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(target, meshes)
    return meshes
```

**Recommendation:** Cache mesh list on player, invalidate only when children change.

### 12. Material creation in editor `_process()`
**File:** `camera_zone.gd:389-402, 480-493`
**Impact:** Creates new StandardMaterial3D objects every frame in editor

```gdscript
func _update_camera_preview() -> void:
    # ...
    var body_face_mat := StandardMaterial3D.new()  # Every frame!
```

**Recommendation:** Create materials once in `_ready()`, update properties only.

### 13. `distance_to()` where `distance_squared_to()` would work
**Files:** `camera_rig.gd:774, 834, 849`, `cursor_3d.gd:525`

```gdscript
var actual_focus := camera.global_position.distance_to(target.global_position + target_frame_offset)
```

When comparing distances, squared comparison is cheaper.

---

## Dead Code to Remove

| File | Item | Reason |
|------|------|--------|
| `camera_rig.gd:124` | `_target_zoom` initialized to 5.0 | Immediately overwritten by preset |
| `camera_rig.gd:125` | `_target_fov` initialized to 50.0 | Immediately overwritten by preset |
| `camera_rig.gd:127` | `_default_follow_offset` | Only set, read in one conditional path |
| `camera_zone.gd:67-69` | Multiple mesh instance vars | Only used in editor mode |
| `first_person_zone.gd` | Entire file (37 lines) | Extends CameraZone with zero changes |

### `first_person_zone.gd` Analysis
```gdscript
class_name FirstPersonZone extends CameraZone
# File is 37 lines but adds NO functionality
# Just sets default values that could be in a .tres preset
```

**Recommendation:** Delete `FirstPersonZone`, use `CameraZone` with first-person preset.

---

## Duplicate Code to Consolidate

### Pattern 1: Camera Gizmo Drawing (~600 lines duplicated)
**Found in:** `camera_zone.gd`, `default_camera_marker.gd`

Both implement identical:
- Frustum rendering
- Camera body/lens mesh
- Look-at line drawing
- Wireframe cube helpers

**Suggestion:** Create `EditorCameraGizmo` utility Resource.

### Pattern 2: Exponential Damping
**Found in:** 25+ locations across `camera_rig.gd`, `cursor_3d.gd`

```gdscript
value = lerpf(value, target, 1.0 - exp(-speed * delta))
```

**Suggestion:** Add to a `MathUtils` class or use GDScript extension.

### Pattern 3: Physics Interpolation Reset
**Found in:** `camera_rig.gd:270-273, 380-381, 1079-1083, 1114-1118, 1140-1144`

```gdscript
reset_physics_interpolation()
pivot.reset_physics_interpolation()
spring_arm.reset_physics_interpolation()
camera.reset_physics_interpolation()
```

**Suggestion:** Extract to `_reset_all_interpolation()` helper.

---

## Files to Merge

| Source | Into | Reason |
|--------|------|--------|
| `first_person_zone.gd` | Delete entirely | Adds nothing to base CameraZone |
| `loot_entry.gd` (7 lines) | `loot_table.gd` | Too small to be separate file |

### `loot_entry.gd` — Only 7 lines
```gdscript
class_name LootEntry extends Resource
@export var item: ItemDefinition
@export var weight: float = 1.0
@export var min_quantity: int = 1
@export var max_quantity: int = 1
```

Could be an inner class in `LootTable`.

---

## Files to Split

| File | Into | Reason |
|------|------|--------|
| `camera_rig.gd` (1166 lines) | 4-5 smaller files | Monolithic, violates SRP |
| `camera_zone.gd` (616 lines) | Runtime + Editor gizmo | Editor code bloats runtime |

### Suggested CameraRig Split

```
camera/
├── camera_rig.gd          (~300 lines - core follow + API)
├── camera_transitions.gd  (~200 lines - tween logic)
├── camera_zoom.gd         (~150 lines - auto-frame, idle, scroll)
├── camera_effects.gd      (~100 lines - idle shake, DOF)
└── camera_collision.gd    (~150 lines - raycast, player fade)
```

---

## Signals Analysis

### Unused Signals
| Signal | File | Issue |
|--------|------|-------|
| `interactable_hovered` | `cursor_3d.gd:11` | Emitted but never connected |
| `interactable_unhovered` | `cursor_3d.gd:13` | Emitted but never connected |

### Signal Connection Patterns
The codebase correctly uses setter-based signal wiring as documented in CLAUDE.md:
- `RenegadeCharacter.controller` setter
- `PlayerController.cursor` setter

---

## Performance Hotspots

### 1. `cursor_3d.gd:230` — Group iteration every physics frame
```gdscript
var interactables := get_tree().get_nodes_in_group("interactable")
for node in interactables:
    # ...
```

### 2. `camera_zone.gd:614-616` — `_process` in editor tool
```gdscript
func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        _update_camera_preview()  # Creates materials every frame
```

### 3. `camera_rig.gd:879-893` — Recursive mesh collection
```gdscript
func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        meshes.append(node)
    for child in node.get_children():
        _collect_meshes(child, meshes)
```

---

## Architecture Assessment

### Inheritance Hierarchy
```
Resource
├── CameraPreset
├── CameraModifier (abstract)
│   ├── ShakeModifier
│   ├── ZoomModifier
│   └── FramingModifier
├── ItemDefinition
│   ├── WeaponDefinition
│   ├── GearDefinition
│   └── ConsumableDefinition
├── LootTable
└── LootEntry

Node
├── ControllerInterface
│   ├── PlayerController
│   └── AIController

Node3D
├── CameraRig
├── CameraSystem
├── Cursor3D
├── DefaultCameraMarker (Marker3D)
├── ItemSlots
└── WorldPickup

Area3D
├── CameraZone
│   └── FirstPersonZone (empty subclass - DELETE)
└── CameraZoneManager
```

### Coupling Analysis

**Tight Coupling (Should Decouple):**
- `CameraRig` ↔ `CameraSystem` (parent lookup)
- `CameraRig` → `PlayerController` (for cursor disable)
- `CameraRig` → `DefaultCameraMarker` (type check for features)

**Appropriate Coupling:**
- `RenegadeCharacter` → `ControllerInterface` (abstraction)
- `CameraZoneManager` → `CameraZone` (via signals)
- `PlayerController` → `Cursor3D` (via setter)

---

## Documentation Gaps

### CLAUDE.md Updates Needed
1. Add inventory system to file structure
2. Document `CameraSystem` node (not mentioned)
3. Document `DefaultCameraMarker` (not mentioned)
4. Update presets directory (missing items/, modifiers/ subdirs)

### Missing Doc Comments
- `camera_system.gd` — No class doc comment
- `default_camera_marker.gd` — No class doc comment
- Most inventory classes — Minimal documentation

---

## Code Quality Summary

| Category | Score | Notes |
|----------|-------|-------|
| Type Hints | 7/10 | Good on exports, inconsistent on locals |
| Naming | 9/10 | Consistent snake_case, descriptive |
| Documentation | 6/10 | Public APIs documented, internals sparse |
| Performance | 6/10 | Several hot-path issues identified |
| Architecture | 6/10 | Good patterns, but CameraRig is too large |
| Dead Code | 7/10 | Some unused code, one empty subclass |
| Duplication | 5/10 | Significant editor visualization duplication |

---

## Risk Assessment

| Change | Risk Level | Notes |
|--------|------------|-------|
| Remove debug prints | Safe | No behavior change |
| Extract camera gizmo utility | Safe | Editor-only code |
| Delete FirstPersonZone | ~~Safe~~ **KEEP** | Has mesh hiding functionality |
| Merge LootEntry into LootTable | ~~Low~~ **KEEP** | Godot resource system needs separate files |
| Split CameraRig | Medium | Many internal references |
| Cache interactable groups | Medium | Timing sensitivity |
| Refactor CameraRig/CameraSystem coupling | Medium | Cross-reference patterns |

---

## Changes Implemented

The following changes from this audit have been implemented:

### Completed

1. **Removed all debug print statements** from `camera_rig.gd` (~11 print calls removed)

2. **Added named constants** for magic numbers in `camera_rig.gd`:
   - `INPUT_DIRECTION_THRESHOLD` (0.7)
   - `VELOCITY_MOVING_THRESHOLD` (0.1)
   - `LOOK_DIRECTION_THRESHOLD` (0.001)
   - `UP_VECTOR_THRESHOLD` (0.9)
   - `INPUT_DEADZONE_SQ` (0.01)
   - `ZOOM_THRESHOLD`, `FOV_THRESHOLD`, `COLLISION_OFFSET_THRESHOLD`, `IDLE_SHAKE_THRESHOLD`

3. **Extracted `_reset_all_interpolation()` helper** — Replaced 4 duplicate 4-line blocks with single method call

4. **Created `MathUtils` utility class** (`src/utils/math_utils.gd`) with:
   - `damp()`, `damp_v2()`, `damp_v3()` — Frame-rate independent exponential damping
   - `damp_angle()`, `damp_basis()` — Rotation damping
   - `smoothstep()` — Ease-in-out function

5. **Cached interactables in `cursor_3d.gd`**:
   - Added `_cached_interactables` array
   - Added `_on_tree_changed()` to invalidate cache
   - Added `_get_interactables()` getter with lazy refresh

6. **Cached player meshes in `camera_rig.gd`**:
   - Added `_cached_player_meshes` array
   - Added setter for `target` to invalidate cache on change
   - Modified `_get_player_meshes()` to use cache

7. **Updated CLAUDE.md documentation**:
   - Added inventory system section
   - Added CameraSystem and DefaultCameraMarker to camera section
   - Updated file structure with all new files

### Kept As-Is (Audit Corrections)

1. **FirstPersonZone** — Initially flagged for deletion, but actually has unique functionality:
   - `hide_player_mesh` export
   - `mesh_node_path` export
   - Overridden `_on_body_entered/exited` to toggle mesh visibility

2. **LootEntry** — Initially flagged for merging, but Godot's resource system requires separate script files for types used in `Array[ResourceType]` exports

8. **Created `CameraGizmo` utility class** (`src/utils/camera_gizmo.gd`):
   - Extracted ~300 lines of duplicate gizmo drawing code
   - Static methods for camera body, frustum, wireframe primitives
   - Shared by `camera_zone.gd` and `default_camera_marker.gd`
   - `camera_zone.gd`: 617 → 392 lines (36% reduction)
   - `default_camera_marker.gd`: 463 → 280 lines (40% reduction)

9. **Fixed editor material recreation**:
   - Materials are now cached and only recreated when selection state changes
   - Added `_update_materials()` with cached material instance variables
   - Eliminates per-frame material allocation in editor `_process()`

10. **Split CameraRig into focused modules**:
   - Created `CameraCollisionHandler` (~195 lines) — collision detection + player mesh fade
   - Created `CameraAutoFramer` (~110 lines) — auto-zoom based on nearby geometry
   - Created `CameraIdleEffects` (~185 lines) — idle zoom + subtle camera sway
   - `camera_rig.gd`: 1,179 → 938 lines (20% reduction)
   - Uses composition pattern — CameraRig delegates to module instances
