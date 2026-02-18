# Renegade Controller — Full Repo Audit

## Objective
Perform a comprehensive audit of the entire RenegadeController repository — including the core `renegade_controller` plugin and all supporting addons. Clean up, remove duplicates, simplify, and optimize while preserving ALL current functionality. No features should be lost or broken.

**Key Principle: Use Godot's built-in nodes first.** Before implementing custom functionality, check if Godot 4.6 already has a node that does what you need. Flag any custom implementations that duplicate built-in node functionality.

---

## Repository Overview

This repo contains multiple Godot 4.6 plugins working together:

| Plugin | Purpose |
|--------|---------|
| `renegade_controller` | Core character controller, camera system, inventory, zones |
| `modular_hud` | Signal-driven HUD components with reactive data binding |
| `sky_weather` | Day/night cycle and weather system |
| `dither_shader` | Retro dithering post-process effect |
| `pixel_outline` | Pixel-perfect outline shader system |
| `pixel_upscale` | Integer-scale pixel art upscaling |
| `universal_door` | Multi-type door system with teleporter support |
| `material_icons_importer` | Editor tool for Google Material Icons |

---

## Phase 1: Discovery & Mapping

### 1.1 File Inventory
Scan ALL addon directories and create a complete manifest:
- List every `.gd` file with its `class_name` (if any)
- List every `.tscn` and `.tres` file
- List every `.gdshader` file
- Note file sizes and line counts
- Flag any files that seem unusually large (>300 lines)

Expected directories to scan:
```
addons/
├── dither_shader/
│   ├── demo/
│   ├── presets/
│   └── src/
├── material_icons_importer/
│   ├── context_menu/
│   ├── icons/
│   └── window/
├── modular_hud/
│   ├── components/
│   ├── core/
│   ├── examples/
│   │   └── resources/
│   └── fonts/
├── pixel_outline/
├── pixel_upscale/
│   ├── presets/
│   └── src/
├── renegade_controller/
│   ├── demo/
│   ├── presets/
│   │   └── items/
│   ├── src/
│   │   ├── camera/
│   │   ├── character/
│   │   ├── controllers/
│   │   ├── cursor/
│   │   ├── editor/
│   │   ├── inventory/
│   │   └── zones/
│   └── textures/
│       ├── dark/
│       ├── green/
│       ├── icons/
│       ├── light/
│       ├── orange/
│       ├── purple/
│       └── red/
├── sky_weather/
│   ├── demo/
│   ├── icons/
│   └── presets/
└── universal_door/
```

### 1.2 Dependency Graph
For each script, document:
- What classes it extends
- What classes it references (type hints, preloads, `class_name` usage)
- What signals it defines
- What signals it connects to
- What groups it uses (`add_to_group`, `is_in_group`, `get_tree().get_nodes_in_group()`)
- **Cross-plugin dependencies** (e.g., modular_hud ↔ sky_weather integration)

### 1.3 Export/Public API Surface
For each class, list:
- All `@export` properties
- All public methods (no `_` prefix)
- All signals

---

## Phase 2: Godot Built-in Node Analysis

### 2.1 Redundant Custom Implementations
Check if any custom code duplicates Godot 4.6 built-in functionality:
- Custom pathfinding vs `NavigationAgent3D`
- Custom camera collision vs `SpringArm3D` (already used — verify no duplication)
- Custom animation state management vs `AnimationTree`
- Custom detection/triggers vs `Area3D` with groups
- Custom tweening vs `Tween` node
- Custom timers vs `Timer` node
- Custom raycasting wrappers vs `RayCast3D` node
- Custom physics queries vs `ShapeCast3D`
- Custom sky/environment vs `ProceduralSkyMaterial` (sky_weather uses this — verify correct usage)
- Custom post-processing vs `CompositorEffect` (Godot 4.3+)

### 2.2 Jolt Physics Compatibility
Verify all physics code works with Jolt (Godot 4.6 default):
- Check for deprecated Godot Physics methods
- Verify `CharacterBody3D.move_and_slide()` usage
- Check collision layer/mask setup
- Verify `RigidBody3D` impulse application patterns
- Check `AnimatableBody3D` usage in universal_door

---

## Phase 3: Duplicate & Dead Code Detection

### 3.1 Duplicate Logic
Search for:
- Functions with identical or near-identical implementations across files
- Copy-pasted code blocks (especially math helpers, signal connection patterns)
- Multiple implementations of the same pattern (e.g., spring damping, exponential smoothing)
- Redundant utility functions that could be consolidated
- **Exponential damping pattern** — should use `lerp(a, b, 1.0 - exp(-speed * delta))` consistently. Flag any raw lerp usage or inconsistent implementations.
- **Cross-plugin duplication** — similar patterns in modular_hud and renegade_controller

### 3.2 Dead Code
Identify:
- Functions that are never called
- Signals that are never emitted or connected
- `@export` properties that are never read
- Variables that are assigned but never used
- Commented-out code blocks
- Files that are never referenced or loaded

### 3.3 Unused Resources
Check all `presets/` directories:
- `renegade_controller/presets/` — camera presets, character templates, item definitions
- `renegade_controller/presets/items/` — weapon/gear/consumable .tres files
- `modular_hud/examples/resources/` — HUDData .tres files
- `sky_weather/presets/` — weather preset .tres files
- `dither_shader/presets/` — dither overlay scenes
- `pixel_upscale/presets/` — upscale display scenes
- Any orphaned resources or unused textures in `renegade_controller/textures/`

---

## Phase 4: Architecture Review

### 4.1 Class Hierarchy
Evaluate:
- Is inheritance used appropriately? Any deep inheritance chains (>2 levels)?
- Could any inheritance be replaced with composition?
- Are there base classes with only one subclass?
- Any circular dependencies?

Key hierarchies to review:
- `ControllerInterface` → `PlayerController` / `AIController`
- `ItemDefinition` → `WeaponDefinition` / `GearDefinition` / `ConsumableDefinition`
- `CameraZone` → `FirstPersonZone`
- `HUDData` (Resource) usage pattern in modular_hud
- `WeatherPreset` (Resource) usage in sky_weather

### 4.2 Coupling Analysis
Check for:
- Scripts that know too much about other scripts' internals
- Direct property access that should be method calls
- Hardcoded node paths that should be exports
- Type assumptions without proper checks
- **Cross-plugin coupling** — how tightly are plugins connected?

### 4.3 Signal vs Direct Reference
Review:
- Are signals used where direct calls would be simpler?
- Are direct calls used where signals would be more decoupled?
- Any signal chains that are overly complex?
- **HUDEvents autoload pattern** — is this the right approach for HUD updates?

### 4.4 Setter Pattern Compliance
Per CLAUDE.md critical patterns, verify all cross-reference `@export` properties that need signal connections use setters:
- `RenegadeCharacter.controller`
- `PlayerController.cursor`
- `CameraRig` handler property propagation
- `SkyWeather.time` and `SkyWeather.weather` setters
- Any other cross-references

---

## Phase 5: Code Quality

### 5.1 Godot Style Guide Compliance
Check each file for:
- Consistent snake_case naming
- Type hints on ALL function parameters and return types
- Type hints on ALL variable declarations where type isn't obvious
- Proper use of `@export` groups
- Doc comments on public methods
- `_` prefix on private members

### 5.2 Performance Concerns
Flag:
- `get_node()` or `$` calls inside `_process()` or `_physics_process()` (should use `@onready`)
- String allocations in hot paths
- Array/Dictionary creation in loops
- `distance_to()` where `distance_squared_to()` would work
- Repeated calculations that could be cached
- `find_children()` or `get_tree().get_nodes_in_group()` called every frame
- Missing `reset_physics_interpolation()` on teleport
- **Shader performance** — any expensive operations in dither/outline/upscale shaders?

### 5.3 Error Handling
Check:
- Null checks before using optional references
- `is_instance_valid()` for potentially freed nodes
- Graceful handling of missing resources/presets
- **Autoload availability checks** — HUDEvents, NPCBrainHooks lookups

---

## Phase 6: Simplification Opportunities

### 6.1 Over-Engineering
Identify:
- Abstractions that only have one implementation
- Getter/setter methods that just wrap a property
- Factory patterns where direct instantiation would suffice
- State machines where booleans would work
- Event systems where direct calls would be clearer

### 6.2 Code Consolidation
Propose:
- Utility functions that could be extracted to a shared `utils/` folder
- Common patterns that could become helper methods
- Scripts that could be merged (if tightly coupled and always used together)
- **Cross-plugin shared code** — common patterns across addons

### 6.3 Configuration Simplification
Review:
- `@export` properties that have sensible defaults and are rarely changed
- Overly granular configuration that could be grouped
- Magic numbers that should be constants (or vice versa)

---

## Phase 7: Inventory System Review (renegade_controller)

### 7.1 Item Definition Hierarchy
Review the item resource hierarchy:
- `ItemDefinition` (base)
- `WeaponDefinition` (damage, fire_rate, ammo_type)
- `GearDefinition` (armor_value, slot_type)
- `ConsumableDefinition` (use_effect, cooldown)

Check for:
- Redundant properties across subclasses
- Missing common functionality in base class
- Overly complex inheritance vs composition

### 7.2 Inventory/Equipment/Weapon Managers
Check for:
- Duplicate logic between `Inventory`, `WeaponManager`, `EquipmentManager`
- Signal usage consistency
- Slot/capacity management patterns

### 7.3 Loot System
Review `LootTable`, `LootEntry`, `LootDropper`:
- Is the weighted random implementation correct?
- Any simpler Godot-native patterns available?

### 7.4 Inventory UI
Review `InventoryGridUI`, `InventorySlotUI`, `ItemInfoPanel`:
- Clean separation of data and presentation?
- Proper signal-based updates?

---

## Phase 8: Camera System Review (renegade_controller)

### 8.1 Camera Handler Architecture
Review the handler composition pattern:
- `CameraCollisionHandler` — collision detection + player mesh fade
- `CameraAutoFramer` — auto-zoom based on nearby geometry
- `CameraIdleEffects` — movement-based zoom

Check for:
- Correct responsibility separation
- Any handlers that could be combined
- Proper enable/disable propagation

### 8.2 CameraSystem → CameraRig → Handler Chain
Verify property propagation:
- `CameraSystem` exposes settings
- `CameraRig` propagates to handlers
- Handlers receive updates via setters

### 8.3 Camera Collision
- `camera_collision.gd` — does this duplicate `SpringArm3D` functionality?
- `camera_auto_frame.gd` — is this needed or can `SpringArm3D` handle it?

---

## Phase 9: Modular HUD System Review

### 9.1 Core Architecture
Review:
- `HUDData` (Resource) — reactive data binding pattern
- `HUDEvents` (Autoload expected) — signal bus for HUD updates
- Component → Data binding approach

### 9.2 Component Inventory
Review all HUD components:
- `health_bar.gd`, `stamina_bar.gd` — stat bars
- `ammo_display.gd` — weapon ammo
- `money_display.gd` — currency
- `damage_flash.gd` — damage feedback
- `prompt.gd` — interaction prompts
- `profiler_display.gd` — debug info
- Sky/weather components: `sky_day_display.gd`, `sky_time_display.gd`, `sky_speed_display.gd`, `sky_weather_icon.gd`, `time_weather_display.gd`

Check for:
- Consistent patterns across components
- Duplicate functionality
- Missing base class opportunities

### 9.3 Sky Weather Integration
Review how `modular_hud` components integrate with `sky_weather`:
- Signal connections
- Data flow
- Coupling level

---

## Phase 10: Sky Weather System Review

### 10.1 Day/Night Cycle
Review:
- Time progression logic
- Sky color blending
- Sun position calculation (axial tilt, path rotation)
- Energy/ambient light adjustments

### 10.2 Weather System
Review:
- `WeatherPreset` resource structure
- Weather transitions (interpolation)
- Precipitation spawning
- Fog handling

### 10.3 Integration Points
Check:
- HUD integration via `_emit_hud_time()`, `_emit_hud_weather()`
- NPC AI integration via `NPCBrainHooks` conditions
- Performance of `_update_sky()` called every time change

---

## Phase 11: Universal Door System Review

### 11.1 Door Types
Review implementation of:
- `NORMAL` — hinged rotation
- `SLIDING` — horizontal slide
- `GARAGE` — vertical roll
- `ELEVATOR` — dual panel split
- `CUSTOM` — AnimationPlayer-driven

### 11.2 Teleporter Feature
Check:
- Target resolution (direct reference vs group lookup)
- Entity positioning and rotation handling
- Signal emission

### 11.3 Built-in Node Usage
Verify correct usage of:
- `AnimatableBody3D` for door physics
- `Area3D` for detection zones
- `Tween` for procedural animation
- `Timer` for auto-close
- `AnimationPlayer` for custom animations

---

## Phase 12: Shader Systems Review

### 12.1 Dither Shader
Review:
- `dither.gdshader` — main dithering effect
- `scene_buffers.gdshader` — buffer handling
- `DitherOverlay` component
- `WorldLabel` / `WorldLabelManager` — purpose and usage

### 12.2 Pixel Outline
Review:
- Multi-pass approach (data pass, mesh shaders, post-process)
- `OutlineMaterial` and `OutlineSetup` components
- Performance considerations

### 12.3 Pixel Upscale
Review:
- `pixel_upscale.gdshader` — upscaling algorithm
- `PixelUpscaleDisplay` and `PixelUpscaleMaterial` components
- Integration with viewport rendering

---

## Phase 13: Documentation Audit

### 13.1 CLAUDE.md
Verify:
- File structure section matches actual files
- All critical patterns are documented
- No outdated information
- Code examples are accurate
- "Use Godot's built-in nodes first" principle is present
- All addons are mentioned

### 13.2 README.md (root and per-addon)
Check:
- Installation instructions work
- Setup instructions are complete
- All features are documented
- Examples are runnable

### 13.3 Inline Documentation
Ensure:
- All public classes have doc comments
- Complex algorithms are explained
- Non-obvious decisions have comments explaining "why"

---

## Phase 14: Output Format

### 14.1 Findings Report
Create a structured report with:

```
## Summary Statistics
- Total addons: X
- Total .gd files: X
- Total lines of code: X
- Total .tscn scenes: X
- Total .tres resources: X
- Total .gdshader files: X
- Largest files: [list top 10]
- Classes defined: X
- Signals defined: X

## Cross-Plugin Dependencies
- [Plugin A] depends on [Plugin B] via [mechanism]

## Godot Built-in Alternatives (Priority Review)
1. [Custom Implementation] — [Built-in Alternative] — [Recommendation]

## Critical Issues (Must Fix)
1. [Issue] — [File:Line] — [Impact]

## Recommended Improvements (Should Fix)
1. [Issue] — [File:Line] — [Benefit]

## Optional Optimizations (Nice to Have)
1. [Issue] — [File:Line] — [Benefit]

## Dead Code to Remove
- [File] — [Reason]

## Duplicate Code to Consolidate
- [Pattern] found in [File1], [File2] — [Suggestion]

## Files to Merge
- [File1] + [File2] → [Reason]

## Files to Split
- [File] → [Reason]

## Plugin-Specific Findings
### renegade_controller
...
### modular_hud
...
### sky_weather
...
### universal_door
...
### dither_shader
...
### pixel_outline
...
### pixel_upscale
...
```

### 14.2 Refactoring Plan
After the report, propose a prioritized action plan:
1. Quick wins (low effort, high impact)
2. Medium effort improvements
3. Larger refactors (if warranted)

Each action item should specify:
- What to change
- Why it improves the codebase
- Risk level (safe / needs testing / breaking change)
- Estimated scope (lines affected)
- Which plugin(s) affected

---

## Constraints

- **DO NOT** remove or modify any functionality without explicit approval
- **DO NOT** change public APIs (method signatures, signal names, export properties) without documenting the breaking change
- **DO** preserve all existing behavior
- **DO** maintain backwards compatibility with existing scenes using the plugins
- **DO** keep the audit non-destructive — report findings, don't auto-fix
- **DO** prioritize Godot built-in nodes over custom implementations
- **DO** consider cross-plugin compatibility when suggesting changes

---

## Deliverables

1. **audit_report.md** — Full findings document
2. **refactoring_plan.md** — Prioritized action items
3. **dependency_graph.md** — Visual or textual representation of class relationships (including cross-plugin)
4. **dead_code_list.md** — Files/functions safe to remove
5. **builtin_alternatives.md** — Custom code that could use Godot built-in nodes
6. **plugin_integration_map.md** — How plugins connect and depend on each other

---

## Environment

- **Godot Version**: 4.6
- **Physics Engine**: Jolt (default for Godot 4.6)
- **Target Game**: "Renegade Cop" — 80s third-person shooter action-RPG

---

## Current File Inventory

### renegade_controller/src/
```
camera/
├── camera_auto_frame.gd
├── camera_collision.gd
├── camera_idle_effects.gd
├── camera_preset.gd
├── camera_rig.gd
└── camera_system.gd

character/
└── character_body.gd

controllers/
├── ai_controller.gd
├── controller_interface.gd
└── player_controller.gd

cursor/
└── cursor_3d.gd

editor/
└── camera_zone_inspector.gd

inventory/
├── consumable_definition.gd
├── equipment_manager.gd
├── gear_definition.gd
├── inventory.gd
├── inventory_grid_ui.gd
├── inventory_slot.gd
├── inventory_slot_ui.gd
├── item_definition.gd
├── item_info_panel.gd
├── item_slots.gd
├── loot_dropper.gd
├── loot_entry.gd
├── loot_table.gd
├── weapon_definition.gd
├── weapon_manager.gd
├── weapon_wheel.gd
└── world_pickup.gd

zones/
├── camera_zone.gd
├── camera_zone_manager.gd
└── first_person_zone.gd
```

### modular_hud/
```
components/
├── ammo_display.gd
├── damage_flash.gd
├── health_bar.gd
├── money_display.gd
├── profiler_display.gd
├── prompt.gd
├── sky_day_display.gd
├── sky_speed_display.gd
├── sky_time_display.gd
├── sky_weather_icon.gd
├── stamina_bar.gd
└── time_weather_display.gd

core/
├── hud_data.gd
└── hud_events.gd

examples/
└── game_hud.gd
```

### sky_weather/
```
├── sky_weather.gd
└── weather_preset.gd
```

### universal_door/
```
├── door_factory.gd
└── universal_door.gd
```

### dither_shader/src/
```
├── dither.gdshader
├── dither_overlay.gd
├── scene_buffers.gd
├── scene_buffers.gdshader
├── world_label.gd
└── world_label_manager.gd
```

### pixel_outline/
```
├── outline_data_pass.gdshader
├── outline_material.gd
├── outline_mesh_shaded.gdshader
├── outline_mesh_unshaded.gdshader
├── outline_post_process.gdshader
└── outline_setup.gd
```

### pixel_upscale/src/
```
├── pixel_upscale.gdshader
├── pixel_upscale_display.gd
└── pixel_upscale_material.gd
```

---

Begin by reading CLAUDE.md, then systematically work through each phase. Ask clarifying questions if you find ambiguous situations.