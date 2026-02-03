# RenegadeController — Dead Code List

> **Note:** Some items in this list were re-evaluated and kept. See corrections below.

## Files Safe to Remove

### ~~1. `first_person_zone.gd` — Empty Subclass~~ **KEEP**
**Path:** `src/zones/first_person_zone.gd`
**Lines:** 37

**CORRECTION:** Initially flagged as empty, but actually has unique functionality:
- `@export var hide_player_mesh: bool` — Toggle player mesh visibility
- `@export var mesh_node_path: String` — Path to mesh node
- Overridden `_on_body_entered()` / `_on_body_exited()` to toggle mesh visibility

**Status:** Keep this file.

---

### ~~2. `loot_entry.gd` — Should Be Inner Class~~ **KEEP**
**Path:** `src/inventory/loot_entry.gd`
**Lines:** 7

**CORRECTION:** Godot's resource system requires separate script files for types used in `Array[ResourceType]` exports. If LootEntry were an inner class, the inspector wouldn't be able to create/edit entries.

**Status:** Keep this file.

---

## Unused Code Within Files

### `camera_rig.gd`

#### Debug Print Statements (20+ occurrences)
**Lines:** 217-223, 232-233, 282-283, 300-301, 311, 322, 357, 658, 742, 749

```gdscript
# Line 217-219
print("CameraRig.transition_to: Using marker at ", camera_marker.global_position)
print("CameraRig.transition_to: No marker, using preset values (offset=", preset.offset if preset else "null", ")")

# Line 222-223
print("CameraRig.transition_to: Early return - already at this state")

# Line 232-233
print("CameraRig.transition_to: Using stored _default_follow_offset=", _default_follow_offset)

# Line 282-283
print("CameraRig.reset_to_default: Called")

# Line 300-301
print("CameraRig.reset_to_default: Parent is ", parent, " (is CameraSystem: ", parent is CameraSystem, ")")

# Line 311
print("CameraRig.reset_to_default: Marker found via '", found_via, "', marker=", marker)

# Line 357
print("apply_default_marker: Stored _default_follow_offset=", _default_follow_offset)

# Line 658
print(">>> _transition_third_person: Using preset values! offset=", preset.offset, " spring_length=", preset.spring_length)

# Line 742
print(">>> _transition_to_marker: FOLLOW MODE - progress-based from ", camera_world_pos)

# Line 749
print(">>> _transition_to_marker: FIXED MODE marker=", _camera_marker.name, " pos=", target_pos)
```

**Action:** Remove all or wrap in `if OS.is_debug_build():`

---

#### Redundant Initializations
**Lines:** 124-125

```gdscript
var _target_zoom: float = 5.0  # Immediately overwritten in _ready()
var _target_fov: float = 50.0  # Immediately overwritten in _ready()
```

The values are always set from `default_preset` in `_ready()`:
```gdscript
# Line 168-169
_target_zoom = default_preset.spring_length
_target_fov = default_preset.fov
```

**Action:** Change to `var _target_zoom: float` and `var _target_fov: float`

---

### `cursor_3d.gd`

#### Unused Signals
**Lines:** 11, 13

```gdscript
signal interactable_hovered(target: Node3D)
signal interactable_unhovered(target: Node3D)
```

These signals are **emitted** but never **connected** anywhere in the codebase.

**Action:** Keep for external game code to use, but document as "available for game integration"

---

### `camera_zone.gd`

#### Editor-Only Variables Initialized at Class Level
**Lines:** 66-70

```gdscript
var _frustum_mesh: MeshInstance3D
var _body_mesh: MeshInstance3D
var _target_mesh: MeshInstance3D
var _collision_shape: CollisionShape3D
var _is_editor_selected: bool = false
```

These are only used when `Engine.is_editor_hint()` is true but are always declared.

**Action:** Minor — could be wrapped in `@export_tool_only` pattern but not critical.

---

### `default_camera_marker.gd`

#### Same Editor-Only Pattern
**Lines:** 62-64 (similar issue)

---

## Commented-Out Code Blocks

No significant commented-out code blocks found in the codebase.

---

## Unused @export Properties

### `camera_preset.gd`

All @export properties appear to be used. No dead exports found.

### `camera_rig.gd`

All @export properties appear to be used. No dead exports found.

### `cursor_3d.gd`

All @export properties appear to be used. No dead exports found.

---

## Unused Methods

### None Found

All public and private methods appear to have at least one call site.

---

## Unused .tres Resources

### All Resources Are Used

Verified:
- `presets/third_person.tres` — Used by demo scene
- `presets/side_scroller.tres` — Used by demo zones
- `presets/top_down.tres` — Used by demo zones
- `presets/first_person.tres` — Used by first person zones
- `presets/modifiers/default_shake.tres` — Available for use
- `presets/modifiers/default_zoom.tres` — Available for use
- `presets/modifiers/default_framing.tres` — Available for use
- `presets/items/*.tres` — All used by demo scene

---

## Summary Table

| Item | Location | Lines | Risk | Action |
|------|----------|-------|------|--------|
| ~~`first_person_zone.gd`~~ | `src/zones/` | 37 | ~~Safe~~ | **KEEP** — Has mesh hiding logic |
| ~~`loot_entry.gd`~~ | `src/inventory/` | 7 | ~~Safe~~ | **KEEP** — Required by Godot resource system |
| Debug prints | `camera_rig.gd` | ~20 | Safe | Now gated behind flag |
| Redundant init | `camera_rig.gd:124-125` | 2 | Safe | Remove defaults |

**Total dead code:** ~66 lines across 2 files to delete + ~20 lines to remove inline

---

## Updated Dead Code (2026-02-03)

### Files Safe to Remove

#### 1. `math_utils.gd` — UNUSED
**Path:** `src/utils/math_utils.gd`
**Lines:** 48

This file defines a `MathUtils` class with helper functions for exponential damping, but **no file in the codebase references it**. The damping is done inline throughout `camera_rig.gd` and other files.

**Action:** Delete or integrate into codebase.

---

#### 2. `camera_gizmo.gd` — UNUSED
**Path:** `src/utils/camera_gizmo.gd`
**Lines:** 359

This file defines a `CameraGizmo` class for drawing camera preview gizmos, but **no file in the codebase references it**. The gizmo drawing is done inline in `camera_zone.gd`.

**Action:** Delete or refactor camera_zone.gd to use it.

---

#### 3. `rail_camera_preview.gd.uid` — ORPHANED
**Path:** `src/editor/rail_camera_preview.gd.uid`

The corresponding `.gd` file was deleted when the rails feature was removed, but the `.uid` file remains.

**Action:** Delete this orphaned file.

---

### Unused Inventory Methods

**File:** `inventory.gd`

| Method | Lines | Status |
|--------|-------|--------|
| `swap_slots()` | ~10 | Never called |
| `find_item()` | ~8 | Never called |
| `get_items_of_type()` | ~10 | Never called |
| `get_empty_slot_count()` | ~5 | Never called |

**Action:** Either remove or document as public API for game integration.

---

### Updated Summary

| Item | Location | Lines | Risk | Action |
|------|----------|-------|------|--------|
| `math_utils.gd` | `src/utils/` | 48 | **Safe** | **DELETE** — Never used |
| `camera_gizmo.gd` | `src/utils/` | 359 | **Safe** | **DELETE** — Never used |
| `rail_camera_preview.gd.uid` | `src/editor/` | 1 | **Safe** | **DELETE** — Orphaned |
| Unused inventory methods | `inventory.gd` | ~33 | Low | Keep or document |

**Total unused code:** 407 lines in utility files + 1 orphaned UID
