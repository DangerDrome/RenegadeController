# RenegadeController — Dead Code List

**Updated:** 2026-02-05 (Post-Improvement Audit)

---

## Status: All Issues Resolved

All dead code issues identified in the audit have been addressed:

| Issue | Status | Resolution |
|-------|--------|------------|
| `signal right_clicked` in `inventory_slot_ui.gd` | **REMOVED** | Redundant with `clicked(button_index)` signal |
| `speed_modifier`/`stealth_modifier` in `gear_definition.gd` | **IMPLEMENTED** | Now used by EquipmentManager and RenegadeCharacter |
| `FireMode` enum in `weapon_definition.gd` | **IMPLEMENTED** | WeaponManager now handles SEMI_AUTO, BURST, FULL_AUTO modes |
| Duplicate `_find_node_by_class()` | **CONSOLIDATED** | Moved to `HUDEvents.find_node_by_class()` static method |
| `_selected_index` in `inventory_grid_ui.gd` | **KEPT** | Valid public API for `set_selected()` method |

---

## Files Safe to Remove

### None

All files serve valid purposes.

---

## Dead Code Within Files

### None

All previously identified dead code has been either removed or implemented.

---

## Orphaned Files

### None Found

All `.gd`, `.tscn`, `.tres`, and `.gdshader` files have valid references.

---

## Unused Resources

### None Found

All resource files in `presets/` directories are referenced by scenes or code.

---

## Public API (Kept for Integration)

The following methods are not used internally but are valid public API:

### inventory.gd
- `swap_slots(from_index, to_index)` — For drag-and-drop reordering
- `find_item(item)` — For item lookup by reference
- `get_items_of_type(type)` — For filtering by item type
- `get_empty_slot_count()` — For capacity checks

### equipment_manager.gd
- `get_total_armor()` — For damage calculation systems
- `get_total_damage_reduction()` — For damage calculation systems
- `get_speed_modifier()` — Used by RenegadeCharacter
- `get_stealth_modifier()` — For stealth/detection systems

---

## Previously Removed (2026-02-04 Audit)

| Item | Status |
|------|--------|
| `shaders/` directory (DOF, Moebius) | Removed |
| `src/rendering/` directory | Removed |
| `presets/materials/` directory | Removed |
| Debug print statements in `camera_rig.gd` | Gated behind flag |

---

## Code Quality: A+

The codebase has excellent code hygiene with:
- No dead code
- No orphaned files
- No unused resources
- Clean public API design
- Consolidated utility functions
