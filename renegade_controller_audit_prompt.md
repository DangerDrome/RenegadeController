# Renegade Controller — Full Repo Audit

## Objective
Perform a comprehensive audit of the RenegadeController plugin. Clean up, remove duplicates, simplify, and optimize while preserving ALL current functionality. No features should be lost or broken.

**Key Principle: Use Godot's built-in nodes first.** Before implementing custom functionality, check if Godot 4.6 already has a node that does what you need. Flag any custom implementations that duplicate built-in node functionality.

## Phase 1: Discovery & Mapping

### 1.1 File Inventory
Scan the entire `addons/renegade_controller/` directory and create a complete manifest:
- List every `.gd` file with its `class_name` (if any)
- List every `.tscn` and `.tres` file
- List every `.gd.uid` file
- Note file sizes and line counts
- Flag any files that seem unusually large (>300 lines)

Expected directories to scan:
```
addons/renegade_controller/
├── demo/
├── presets/
│   ├── items/
│   └── modifiers/
└── src/
    ├── camera/
    │   └── modifiers/
    ├── character/
    ├── controllers/
    ├── cursor/
    ├── editor/
    ├── inventory/
    ├── utils/
    └── zones/
```

### 1.2 Dependency Graph
For each script, document:
- What classes it extends
- What classes it references (type hints, preloads, `class_name` usage)
- What signals it defines
- What signals it connects to
- What groups it uses (`add_to_group`, `is_in_group`, `get_tree().get_nodes_in_group()`)

### 1.3 Export/Public API Surface
For each class, list:
- All `@export` properties
- All public methods (no `_` prefix)
- All signals

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

### 2.2 Jolt Physics Compatibility
Verify all physics code works with Jolt (Godot 4.6 default):
- Check for deprecated Godot Physics methods
- Verify `CharacterBody3D.move_and_slide()` usage
- Check collision layer/mask setup
- Verify `RigidBody3D` impulse application patterns

## Phase 3: Duplicate & Dead Code Detection

### 3.1 Duplicate Logic
Search for:
- Functions with identical or near-identical implementations across files
- Copy-pasted code blocks (especially math helpers, signal connection patterns)
- Multiple implementations of the same pattern (e.g., spring damping, exponential smoothing)
- Redundant utility functions that could be consolidated
- **Exponential damping pattern** — should use `lerp(a, b, 1.0 - exp(-speed * delta))` consistently. Flag any raw lerp usage or inconsistent implementations.

### 3.2 Dead Code
Identify:
- Functions that are never called
- Signals that are never emitted or connected
- `@export` properties that are never read
- Variables that are assigned but never used
- Commented-out code blocks
- Files that are never referenced or loaded

### 3.3 Unused Resources
Check `presets/` directory:
- Are all `.tres` files in `presets/` actually used?
- Are all `.tres` files in `presets/items/` actually used?
- Are all `.tres` files in `presets/modifiers/` actually used?
- Are all `.tscn` prefabs referenced somewhere?
- Any orphaned resources?

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
- `CameraModifier` → `ShakeModifier` / `ZoomModifier` / `FramingModifier` / `IdleShakeModifier`
- `CameraZone` → `FirstPersonZone`

### 4.2 Coupling Analysis
Check for:
- Scripts that know too much about other scripts' internals
- Direct property access that should be method calls
- Hardcoded node paths that should be exports
- Type assumptions without proper checks

### 4.3 Signal vs Direct Reference
Review:
- Are signals used where direct calls would be simpler?
- Are direct calls used where signals would be more decoupled?
- Any signal chains that are overly complex?

### 4.4 Setter Pattern Compliance
Per CLAUDE.md critical patterns, verify all cross-reference `@export` properties that need signal connections use setters:
- `RenegadeCharacter.controller`
- `PlayerController.cursor`
- `CameraRig` handler property propagation
- Any other cross-references

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

### 5.3 Error Handling
Check:
- Null checks before using optional references
- `is_instance_valid()` for potentially freed nodes
- Graceful handling of missing resources/presets

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
- Utility functions that could be extracted to `utils/math_utils.gd`
- Common patterns that could become helper methods
- Scripts that could be merged (if tightly coupled and always used together)

### 6.3 Configuration Simplification
Review:
- `@export` properties that have sensible defaults and are rarely changed
- Overly granular configuration that could be grouped
- Magic numbers that should be constants (or vice versa)

## Phase 7: Inventory System Review

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

## Phase 8: Camera System Review

### 8.1 Camera Modifier Stack
Review the modifier architecture:
- `CameraModifier` (abstract base)
- `CameraModifierStack` (manager)
- `ShakeModifier`, `ZoomModifier`, `FramingModifier`, `IdleShakeModifier`

Check for:
- Correct alpha blending implementation
- Priority ordering logic
- Any modifiers that could be combined

### 8.2 CameraSystem → CameraRig → Handler Chain
Verify property propagation:
- `CameraSystem` exposes settings
- `CameraRig` propagates to handlers
- Handlers (`_auto_framer`, `_idle_effects`, `_collision_handler`) receive updates

### 8.3 Camera Collision
- `camera_collision.gd` — does this duplicate `SpringArm3D` functionality?
- `camera_auto_frame.gd` — is this needed or can `SpringArm3D` handle it?

## Phase 9: Documentation Audit

### 9.1 CLAUDE.md
Verify:
- File structure section matches actual files
- All critical patterns are documented
- No outdated information
- Code examples are accurate
- "Use Godot's built-in nodes first" principle is present

### 9.2 README.md
Check:
- Installation instructions work
- Setup instructions are complete
- All features are documented
- Examples are runnable

### 9.3 Inline Documentation
Ensure:
- All public classes have doc comments
- Complex algorithms are explained
- Non-obvious decisions have comments explaining "why"

## Phase 10: Output Format

### 10.1 Findings Report
Create a structured report with:

```
## Summary Statistics
- Total files: X
- Total lines of code: X
- Largest files: [list top 5]
- Classes defined: X
- Signals defined: X

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
```

### 10.2 Refactoring Plan
After the report, propose a prioritized action plan:
1. Quick wins (low effort, high impact)
2. Medium effort improvements
3. Larger refactors (if warranted)

Each action item should specify:
- What to change
- Why it improves the codebase
- Risk level (safe / needs testing / breaking change)
- Estimated scope (lines affected)

## Constraints

- **DO NOT** remove or modify any functionality without explicit approval
- **DO NOT** change public APIs (method signatures, signal names, export properties) without documenting the breaking change
- **DO** preserve all existing behavior
- **DO** maintain backwards compatibility with existing scenes using the plugin
- **DO** keep the audit non-destructive — report findings, don't auto-fix
- **DO** prioritize Godot built-in nodes over custom implementations

## Deliverables

1. **audit_report.md** — Full findings document
2. **refactoring_plan.md** — Prioritized action items
3. **dependency_graph.md** — Visual or textual representation of class relationships
4. **dead_code_list.md** — Files/functions safe to remove
5. **builtin_alternatives.md** — Custom code that could use Godot built-in nodes

## Environment

- **Godot Version**: 4.6
- **Physics Engine**: Jolt (default for Godot 4.6)
- **Target Game**: "Renegade Cop" — 80s third-person shooter action-RPG

Begin by reading CLAUDE.md, then systematically work through each phase. Ask clarifying questions if you find ambiguous situations.
