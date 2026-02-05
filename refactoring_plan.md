# Renegade Controller — Refactoring Plan

**Priority Legend:**
- 🔴 **Critical** — Must fix, affects correctness
- 🟠 **High** — Should fix, significant improvement
- 🟡 **Medium** — Nice to have, cleanliness improvement
- 🟢 **Low** — Optional optimization

---

## Phase 1: Quick Wins (Low Effort, High Impact)

### 1.1 Standardize Signal Signatures 🔴
**Risk:** Safe
**Scope:** ~10 lines
**Plugins:** modular_hud, sky_weather

**Change:**
```gdscript
# sky_weather/sky_weather.gd - Update line 84
signal time_changed(hour: float, period: String)  # Add period parameter

# Update _emit_hud_time() to pass period
func _emit_hud_time() -> void:
    var hud_events := get_node_or_null("/root/HUDEvents")
    if hud_events and hud_events.has_signal("time_changed"):
        hud_events.emit_signal("time_changed", time, get_period())
    time_changed.emit(time, get_period())  # Include period
```

**Why:** Eliminates signal signature confusion between plugins.

---

### 1.2 Remove Dead Signals 🟡
**Risk:** Safe
**Scope:** ~5 lines
**Plugin:** renegade_controller

**Change:**
```gdscript
# inventory_slot_ui.gd - Remove line 6
# signal right_clicked  # DELETE - never connected

# Line 50 - Simplify to only emit clicked
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        clicked.emit(event.button_index)
```

**Why:** Dead code removal, cleaner API.

---

### 1.3 Fix Distance Calculation 🟡
**Risk:** Safe
**Scope:** ~3 lines
**Plugin:** renegade_controller

**Change:**
```gdscript
# camera_auto_frame.gd - Line 94
# Before:
var hit_distance := player_pos.distance_to(result.position)

# After (option 1 - if only comparison needed):
var hit_distance_sq := player_pos.distance_squared_to(result.position)
var check_distance_sq := check_distance * check_distance
total_openness += hit_distance_sq / check_distance_sq

# After (option 2 - keep sqrt for actual distance ratio):
var hit_distance := player_pos.distance_to(result.position)  # Keep if ratio matters
```

**Why:** Avoids 8 sqrt() calls per frame in auto-framing loop.

---

### 1.4 Fix Outline Depth Edge Detection 🟡
**Risk:** Safe
**Scope:** 1 line
**Plugin:** pixel_outline

**Change:**
```glsl
// outline_post_process.gdshader - Line 77
// Before:
float behind_weight = max(0.0, sign(sample_depth - center_depth));

// After:
float behind_weight = step(center_depth, sample_depth);
```

**Why:** `sign()` returns 0 at exact threshold; `step()` is more reliable.

---

## Phase 2: Code Deduplication (Medium Effort)

### 2.1 Extract HUD Tree Search Utility 🟠
**Risk:** Safe
**Scope:** ~50 lines added, ~200 lines removed
**Plugin:** modular_hud

**Change:**
```gdscript
# Add to hud_events.gd:
static func find_node_by_class(root: Node, class_name_str: String) -> Node:
    var script := root.get_script() as Script
    if script and script.get_global_name() == class_name_str:
        return root
    for child in root.get_children():
        var result := find_node_by_class(child, class_name_str)
        if result:
            return result
    return null

# Update all 4 sky_* components to use:
# _sky_weather = HUDEvents.find_node_by_class(get_tree().root, "SkyWeather")
```

**Files to update:**
- `sky_time_display.gd` — Remove `_find_node_by_class()`, use HUDEvents
- `sky_day_display.gd` — Same
- `sky_weather_icon.gd` — Same
- `sky_speed_display.gd` — Same

**Why:** Eliminates 4 copies of identical 15-line function.

---

### 2.2 Create HUDDataBar Base Class 🟠
**Risk:** Safe (additive)
**Scope:** ~40 lines new, ~20 lines removed
**Plugin:** modular_hud

**New file:** `modular_hud/components/hud_data_bar.gd`
```gdscript
class_name HUDDataBar
extends Control

@export var data: HUDData
@export var low_threshold: float = 0.25
@export var bar_color: Color = Color.WHITE
@export var warning_color: Color = Color.RED

@onready var bar: ProgressBar = $ProgressBar
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    if data:
        data.changed.connect(_update)
        _update()

func _update() -> void:
    if not data or not bar:
        return
    var target := (data.value / data.max_value) * 100.0
    var tween := create_tween()
    tween.tween_property(bar, "value", target, 0.15)

    var ratio := data.value / data.max_value
    if ratio < low_threshold:
        bar.modulate = warning_color
        if anim and anim.has_animation("pulse"):
            anim.play("pulse")
    else:
        bar.modulate = bar_color
        if anim:
            anim.stop()
```

**Refactor `health_bar.gd` and `stamina_bar.gd` to extend HUDDataBar.**

**Why:** Merges 60 lines of duplicate code into reusable base.

---

### 2.3 Extract Zoom Composition Method 🟡
**Risk:** Safe
**Scope:** ~15 lines
**Plugin:** renegade_controller

**Change in `camera_rig.gd`:**
```gdscript
## Calculates effective zoom offset from dynamic sources.
func _get_dynamic_zoom_offset() -> float:
    return minf(_auto_frame_zoom, _movement_zoom) + _aim_zoom

# Line 622-623 (follow mode):
var effective_zoom := _target_zoom - _get_dynamic_zoom_offset()

# Line 673-674 (marker mode):
var total_zoom := _current_zoom + _get_dynamic_zoom_offset()
```

**Why:** Eliminates duplicate zoom composition logic, makes zoom behavior testable.

---

## Phase 3: Architecture Improvements (Higher Effort)

### 3.1 Clarify Inventory/Equipment Ownership 🔴
**Risk:** Medium (behavioral change)
**Scope:** ~50 lines
**Plugin:** renegade_controller

**Current problem:** Items exist in both `Inventory.slots` AND `EquipmentManager.equipped`.

**Solution:** EquipmentManager stores slot indices, not item references.

```gdscript
# equipment_manager.gd - Change equipped dict
var equipped: Dictionary = {
    &"primary": -1,    # Inventory slot index, -1 = empty
    &"secondary": -1,
    &"throwable": -1,
    &"armor": -1
}

func equip_to_slot(slot_name: StringName, inventory_slot_index: int) -> bool:
    if inventory_slot_index < 0 or inventory_slot_index >= inventory.slots.size():
        return false
    var slot := inventory.slots[inventory_slot_index]
    if not slot.item:
        return false
    # ... validation ...
    equipped[slot_name] = inventory_slot_index
    item_equipped.emit(slot.item, slot_name)
    return true

func get_equipped_item(slot_name: StringName) -> ItemDefinition:
    var idx := equipped.get(slot_name, -1)
    if idx < 0:
        return null
    return inventory.slots[idx].item
```

**Why:** Single source of truth prevents item duplication bugs.

---

### 3.2 Extract CameraTransitionHandler 🟠
**Risk:** Low
**Scope:** ~150 lines moved
**Plugin:** renegade_controller

**New file:** `renegade_controller/src/camera/camera_transition_handler.gd`
```gdscript
class_name CameraTransitionHandler
extends RefCounted

signal transition_started(from: CameraPreset, to: CameraPreset)
signal transition_finished(preset: CameraPreset)

var is_transitioning: bool = false
var transition_progress: float = 0.0
var _active_tween: Tween

# Move from camera_rig.gd:
# - _apply_curve()
# - _get_active_curve()
# - _transition_third_person()
# - _transition_to_first_person()
# - _transition_from_first_person()
# - _transition_to_marker()
# - Transition-related state variables
```

**Why:** Reduces camera_rig.gd by ~150 lines, isolates transition logic for easier testing.

---

### 3.3 Implement FireMode 🟡
**Risk:** Low (additive feature)
**Scope:** ~30 lines
**Plugin:** renegade_controller

**Change in `weapon_manager.gd`:**
```gdscript
func fire() -> bool:
    if state != State.IDLE or _fire_cooldown > 0.0 or ammo_in_magazine <= 0:
        return false

    match current_weapon.fire_mode:
        WeaponDefinition.FireMode.SEMI_AUTO:
            _fire_single()
        WeaponDefinition.FireMode.BURST:
            _fire_burst(3)  # 3-round burst
        WeaponDefinition.FireMode.FULL_AUTO:
            # Handled in _process while trigger held
            _fire_single()
    return true

func _fire_single() -> void:
    ammo_in_magazine -= 1
    _fire_cooldown = 1.0 / current_weapon.fire_rate
    weapon_fired.emit()

func _fire_burst(count: int) -> void:
    for i in count:
        if ammo_in_magazine <= 0:
            break
        _fire_single()
        await get_tree().create_timer(0.05).timeout
```

**Why:** Existing enum becomes functional, enables weapon variety.

---

### 3.4 Add Sky Update Optimization 🟢
**Risk:** Safe
**Scope:** ~15 lines
**Plugin:** sky_weather

**Change in `sky_weather.gd`:**
```gdscript
var _needs_sky_update: bool = true

func _process(delta: float) -> void:
    if day_duration_minutes > 0 and not Engine.is_editor_hint():
        var old_time := time
        var base_speed := (delta / 60.0) * (24.0 / day_duration_minutes)
        time += base_speed * time_scale
        if time != old_time:
            _needs_sky_update = true

    if _weather_t < 1.0:
        _weather_t = minf(_weather_t + delta / weather_transition_time, 1.0)
        _needs_sky_update = true

    if _needs_sky_update:
        _update_sky()
        _needs_sky_update = false
```

**Why:** Skips redundant sky calculations when nothing changed.

---

## Phase 4: Documentation Updates

### 4.1 Update CLAUDE.md File Structure 🟡
**Risk:** Safe
**Scope:** Documentation only

Add any new files created during refactoring. Verify all paths match actual structure.

---

### 4.2 Document Integration Patterns 🟡
**Risk:** Safe
**Scope:** Documentation only

Add to modular_hud README:
- How to find SkyWeather from HUD components
- Signal listening patterns (HUDEvents vs direct)
- Recommended integration approach

---

## Implementation Order

| Phase | Task | Priority | Effort | Risk |
|-------|------|----------|--------|------|
| 1 | Standardize signal signatures | 🔴 Critical | 15 min | Safe |
| 1 | Remove dead signals | 🟡 Medium | 5 min | Safe |
| 1 | Fix distance calculation | 🟡 Medium | 10 min | Safe |
| 1 | Fix outline depth edge | 🟡 Medium | 5 min | Safe |
| 2 | Extract HUD tree search | 🟠 High | 1 hr | Safe |
| 2 | Create HUDDataBar base | 🟠 High | 1.5 hr | Safe |
| 2 | Extract zoom composition | 🟡 Medium | 30 min | Safe |
| 3 | Clarify inventory ownership | 🔴 Critical | 2 hr | Medium |
| 3 | Extract CameraTransitionHandler | 🟠 High | 2 hr | Low |
| 3 | Implement FireMode | 🟡 Medium | 1 hr | Low |
| 3 | Add sky update optimization | 🟢 Low | 30 min | Safe |
| 4 | Update documentation | 🟡 Medium | 1 hr | Safe |

**Estimated Total:** ~10.5 hours

---

## Testing Requirements

After each phase:

1. **Phase 1:** Run demo scene, verify no errors
2. **Phase 2:** Test HUD components with/without SkyWeather present
3. **Phase 3:**
   - Inventory: Equip/unequip/drop weapons, verify no duplication
   - Camera: Test all zone transitions, verify smooth interpolation
   - Weapons: Test each fire mode (once implemented)
4. **Phase 4:** Review documentation accuracy

---

## Rollback Plan

All changes are isolated. If issues arise:
- Phase 1: Revert individual line changes
- Phase 2: Delete new base classes, restore original files from git
- Phase 3: Revert to previous implementation via git
- Phase 4: Documentation-only, no code impact
