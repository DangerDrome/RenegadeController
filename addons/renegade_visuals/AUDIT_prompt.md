# Renegade Visuals — Plugin Audit

## Objective
Perform a comprehensive audit of the `renegade_visuals` plugin — a fully procedural AAA character animation system for Godot 4.6. Clean up, remove duplicates, simplify, and optimize while preserving ALL current functionality. No features should be lost or broken.

**Key Principle: Use Godot's built-in nodes first.** Before implementing custom functionality, check if Godot 4.6 already has a node that does what you need. Leverage SkeletonModifier3D, AnimationTree, and Skeleton3D nodes properly.

---

## Plugin Overview

**renegade_visuals** is a Godot 4.6 plugin providing fully procedural character animation with AAA quality motion:

| Feature | Implementation |
|---------|----------------|
| **Stride Wheel** | Fully procedural walk/run IK with footfall impacts, hip motion, shoulder counter-rotation |
| **Foot IK** | Ground-adapting foot placement with slope detection |
| **Hand IK** | Two-bone IK for hands, wall touching, object placement |
| **Hip Motion** | Hip bob, rock, twist via SkeletonModifier3D pipeline |
| **Hit Reactions** | Physics-based hit flinch with spring recovery |
| **Active Ragdoll** | Powered ragdoll with pose matching |
| **Root Motion** | AnimationTree integration with velocity extraction |
| **Procedural Lean** | Body leaning into movement and turns |
| **Spring Bones** | World collision for physics bones |

---

## Phase 1: Discovery & Mapping

### 1.1 File Inventory
Scan the renegade_visuals plugin and create a complete manifest:
- List every `.gd` file with its `class_name` (if any)
- List every `.tscn` and `.tres` file
- Note file sizes and line counts
- Flag any files that seem unusually large (>500 lines for procedural systems)

Expected directory structure:
```
addons/renegade_visuals/
├── plugin.cfg
├── plugin.gd
├── nodes/                              # Main component nodes
│   ├── stride_wheel_component.gd       # Procedural locomotion (LARGE FILE)
│   ├── hip_rock_modifier.gd            # SkeletonModifier3D for hip motion
│   ├── foot_ik_component.gd            # Foot IK solver
│   ├── hand_ik_component.gd            # Hand IK solver
│   ├── locomotion_component.gd         # Root motion integration
│   ├── character_visuals.gd            # Main coordinator node
│   ├── hit_reaction_component.gd       # Hit detection
│   ├── hit_reaction_modifier.gd        # SkeletonModifier3D for hits
│   ├── hit_reactor_component.gd        # Hit physics
│   ├── active_ragdoll_component.gd     # Powered ragdoll
│   ├── procedural_lean_component.gd    # Body leaning
│   ├── item_slots.gd                   # Visual item attachment
│   ├── hand_object_placement.gd        # Object holding IK
│   ├── wall_hand_placement.gd          # Wall touching IK
│   └── spring_bone_world_collision.gd  # Spring bone physics
├── resources/                          # Configuration resources
│   ├── stride_wheel_config.gd          # Stride wheel parameters
│   ├── foot_ik_config.gd               # Foot IK parameters
│   ├── locomotion_config.gd            # Root motion parameters
│   ├── lean_config.gd                  # Body lean parameters
│   ├── hit_reaction_config.gd          # Hit reaction parameters
│   └── skeleton_config.gd              # Bone mapping
├── presets/                            # Template scenes
│   ├── character_visuals.tscn          # Main character visuals template
│   └── ragdoll.gd                      # Ragdoll setup helper
├── defaults/                           # Default configs
│   └── mannequin/
│       └── uefn_skeleton_config.tres   # UEFN skeleton bone map
└── tools/                              # Editor tools
    └── skeleton_analyzer.gd            # Skeleton introspection tool
```

### 1.2 Dependency Graph
For each script, document:
- What classes it extends (Node, SkeletonModifier3D, Resource, etc.)
- What classes it references (type hints, preloads, `class_name` usage)
- What signals it defines
- What signals it connects to
- Component → CharacterVisuals → Skeleton3D relationship chain
- SkeletonModifier3D pipeline order (important for correct bone application)
- AnimationTree → LocomotionComponent → CharacterBody3D → StrideWheel data flow

**Key Relationships:**
- `CharacterVisuals` (coordinator) → child components
- `StrideWheelComponent` → `HipRockModifier` (via exposed state)
- `LocomotionComponent` → AnimationTree → root motion velocity
- Config resources → component nodes
- SkeletonConfig → bone index caching

### 1.3 Export/Public API Surface
For each class, list:
- All `@export` properties (especially Config resources)
- All public methods (no `_` prefix)
- All signals
- All exposed state variables (for component coordination)

---

## Phase 2: Godot Built-in Node Analysis

### 2.1 Proper Use of Godot Animation System
Verify correct usage of Godot's built-in animation nodes:
- **Skeleton3D** — Are we querying bone poses correctly? Using bone indices efficiently?
- **SkeletonModifier3D** — Are modifiers in correct order? Are we preserving/chaining transforms properly?
- **AnimationTree** — Root motion extraction, blend tree parameters
- **SkeletonIK3D** — Could we use built-in IK instead of custom two-bone solver? (Likely NO - our solver has more control)
- **BoneAttachment3D** — Are we using this for item attachment or custom solution?

### 2.2 Physics System Integration
Check physics usage patterns:
- **RayCast3D** nodes vs direct PhysicsDirectSpaceState3D queries (ground detection, wall touching)
- **PhysicsBody3D** hierarchy — RigidBody3D for ragdoll, proper collision layers
- **CharacterBody3D** integration — how does CharacterVisuals connect to controller?
- **Jolt Physics** compatibility (Godot 4.6 default)
- Spring physics implementations — are we using Godot's spring joints where appropriate?

### 2.3 Performance & Caching
Check for:
- Bone index caching (should cache in `_ready()`, not query every frame)
- Transform calculations in local vs global space (minimize conversions)
- PhysicsDirectSpaceState3D query allocation (reuse queries where possible)
- Exponential damping pattern — using `1.0 - exp(-speed * delta)` consistently?

---

## Phase 3: Duplicate & Dead Code Detection

### 3.1 Duplicate Logic
Search for:
- **Two-bone IK solver** — used in FootIKComponent, HandIKComponent, WallHandPlacement. Should this be extracted to shared utility?
- **Spring damping physics** — footfall impacts, hit reactions, procedural lean. Are formulas consistent?
- **Exponential smoothing** — should use `lerp(a, b, 1.0 - exp(-speed * delta))` consistently. Flag raw lerp usage.
- **Bone index lookups** — multiple components cache spine/head/hand bone indices. Pattern consistent?
- **Ground raycasting** — used in StrideWheelComponent, FootIKComponent. Shared logic?
- **Transform math** — vector rotation, basis alignment, local↔global conversions. Consolidate helpers?

### 3.2 Dead Code
Identify:
- Functions that are never called (especially in large files like stride_wheel_component.gd)
- Signals that are never emitted or connected
- `@export` properties that are never read (bloated config resources?)
- Variables that are assigned but never used
- Commented-out code blocks (implementation experiments?)
- Debug flags that are always false

### 3.3 Unused Resources
Check resources:
- `defaults/` — unused skeleton configs?
- `presets/` — orphaned .tscn or .tres files?
- Old config parameters that are no longer used (check version history if needed)

---

## Phase 4: Architecture Review

### 4.1 Component Composition Pattern
Evaluate the CharacterVisuals → child component pattern:
- **CharacterVisuals** (coordinator) — Does it properly manage child components?
- Component independence — Can components work without each other?
- Initialization order — Are components initialized in correct sequence?
- Component coupling — Do components access each other directly or through CharacterVisuals?

Key hierarchies:
- Node → StrideWheelComponent, FootIKComponent, HandIKComponent, etc. (flat, good)
- SkeletonModifier3D → HipRockModifier, HitReactionModifier (correct usage)
- Resource → Config classes (StrideWheelConfig, FootIKConfig, etc.)

### 4.2 SkeletonModifier3D Pipeline
Critical review:
- **Modifier order** — HipRockModifier must run AFTER AnimationTree, BEFORE IK modifiers
- **Transform preservation** — Are modifiers chaining transforms correctly or overwriting?
- **Bone pose API** — Using `get_bone_pose()` / `set_bone_pose()` correctly?
- **Performance** — Are modifiers doing minimal work when disabled?

### 4.3 Data Flow Analysis
Trace data flow through system:
1. **Input** → CharacterBody3D velocity → LocomotionComponent
2. **LocomotionComponent** → AnimationTree parameters → root motion
3. **AnimationTree** → Skeleton3D bone poses
4. **StrideWheelComponent** → exposes state (hip motion, footfall impacts)
5. **HipRockModifier** → reads StrideWheelComponent state → modifies skeleton
6. **FootIKComponent** → reads ground, modifies skeleton

Check for:
- Circular dependencies in data flow
- State synchronization issues
- Race conditions in `_physics_process()` vs `_process()`

### 4.4 Config Resource Pattern
Review:
- All components use `@export var config: ConfigResource` pattern (good)
- Config changes propagate correctly (setters needed?)
- Default configs provided vs mandatory configs
- Config validation (null checks, range validation)

---

## Phase 5: Code Quality

### 5.1 Godot Style Guide Compliance
Check each file for:
- Consistent snake_case naming
- Type hints on ALL function parameters and return types
- Type hints on ALL variable declarations where type isn't obvious
- Proper use of `@export` groups (stride_wheel_config.gd has MANY groups - is it organized well?)
- Doc comments on public methods (especially IK solvers, complex math)
- `_` prefix on private members

### 5.2 Performance Concerns (CRITICAL for Procedural Animation)
Flag:
- **Bone lookups** — `skeleton.find_bone()` in hot paths (should cache indices in `_ready()`)
- **Transform allocations** — creating new Transform3D every frame vs reusing
- **Trigonometry** — unnecessary `sin()`/`cos()` calls (can we use cached values?)
- **PhysicsDirectSpaceState3D** queries — reuse query objects, don't allocate every frame
- `distance_to()` where `distance_squared_to()` would work
- **Vector3 allocations** — `Vector3(0, 0, 0)` vs `Vector3.ZERO`
- **Matrix math** — expensive basis operations in tight loops
- **Debug drawing** — are debug visualizations properly gated behind flags?

### 5.3 Error Handling
Check:
- **Skeleton validity** — null checks before accessing skeleton
- **Bone index validity** — checking index != -1 before use
- **Config validation** — handling null configs gracefully
- **CharacterBody3D reference** — what happens if controller is null?
- `is_instance_valid()` for cross-references that might be freed

---

## Phase 6: Simplification Opportunities

### 6.1 Over-Engineering
Identify:
- **Hit reaction system** — HitReactionComponent vs HitReactionModifier vs HitReactorComponent. Are all three needed?
- **Config resources** — Could some configs be merged? (e.g., FootIKConfig vs StrideWheelConfig overlap?)
- Getter/setter methods that just wrap a property
- State variables that could be computed on-demand vs cached

### 6.2 Code Consolidation
Propose:
- **IK solver utility** — Extract shared two-bone IK logic from FootIK, HandIK, WallHand components
- **Spring physics helper** — Consolidate spring-damping formulas (footfall, hit reaction, lean)
- **Bone lookup utility** — Shared bone index caching pattern
- **Math helpers** — Vector rotation, basis alignment, clamping utilities
- Could `locomotion_component.gd` be merged into CharacterVisuals? (only 124 lines)

### 6.3 Configuration Simplification
Review stride_wheel_config.gd (256 lines, 16 export groups!):
- Are all 80+ parameters necessary?
- Could parameters be grouped into sub-resources? (e.g., GaitConfig, HipMotionConfig, FootfallConfig)
- Debug flags scattered across components — consolidate to single DebugConfig?
- Magic numbers — are constants defined vs hardcoded?

---

## Phase 7: Stride Wheel System Review (LARGEST COMPONENT)

stride_wheel_component.gd is the heart of the plugin (likely >2000 lines). Review thoroughly:

### 7.1 Core Locomotion Algorithm
Review:
- **Gait cycle calculation** — How are left/right foot cycles computed?
- **Stride length scaling** — Speed-based stride adjustment logic
- **Foot plant detection** — Cycle thresholds for stance/swing transitions
- **Footfall impact system** — Spring-damped chest/head drops (recently added)
- Are physics formulas correct and consistent?

### 7.2 Hip Motion System
Review hip bob, rock, twist implementation:
- **Hip bob** — Vertical pelvis oscillation during walk
- **Hip rock** — X/Y/Z axis rotations (side-to-side, twist, tilt)
- **Body trail** — Character body offset behind/ahead of feet
- **Spine lean** — Forward tilt into movement
- Exposed state → HipRockModifier integration

### 7.3 Shoulder Counter-Rotation
Review:
- Shoulder twist opposite to hips (natural arm swing)
- Spine twist cascade (hip rotation propagating up spine)
- Is this data properly exposed to skeleton modifiers?

### 7.4 Feature Toggles
The component has MANY optional features:
- Turn-in-place stepping
- Foot rotation (ground normal, swing pitch, heel-toe roll)
- Knee pole tracking
- Slope adaptation
- Start/stop motion
- Turn banking (lateral lean into turns)
- Procedural breathing
- Idle sway
- Clavicle motion
- Gait refinement (asymmetry, cadence variation)

Questions:
- Are all features actually implemented and working?
- Can features be safely disabled without breaking other systems?
- Are debug flags comprehensive?

---

## Phase 8: IK Systems Review

### 8.1 Foot IK Component
Review foot_ik_component.gd:
- Two-bone IK solver implementation (is it correct?)
- Ground detection (raycasting vs stride wheel ground detection - duplication?)
- Foot rotation to match ground normal
- Integration with stride wheel foot targets

### 8.2 Hand IK Component
Review hand_ik_component.gd:
- Two-bone IK solver (same as foot IK? Should be shared?)
- Hand target positioning
- Integration with item holding system

### 8.3 Wall Hand Placement
Review wall_hand_placement.gd:
- Wall detection (raycasting)
- Hand placement on surfaces
- IK solver (another two-bone implementation?)

### 8.4 Hand Object Placement
Review hand_object_placement.gd:
- Object attachment to hands
- Rotation/offset handling
- BoneAttachment3D usage?

---

## Phase 9: Hit Reaction System Review

Three separate components for hit reactions - is this necessary?

### 9.1 HitReactionComponent
Review hit_reaction_component.gd:
- Hit detection (how does it receive hit events?)
- Impact direction calculation
- Component coordination

### 9.2 HitReactionModifier
Review hit_reaction_modifier.gd:
- SkeletonModifier3D implementation
- Spring-damped bone displacement
- Modifier order in pipeline

### 9.3 HitReactorComponent
Review hit_reactor_component.gd:
- What does this do differently from HitReactionComponent?
- Is there duplication?

---

## Phase 10: Ragdoll System Review

### 10.1 Active Ragdoll Component
Review active_ragdoll_component.gd:
- Powered ragdoll implementation (pose matching)
- RigidBody3D hierarchy
- Transition from animation → ragdoll
- Ragdoll → animation recovery

### 10.2 Ragdoll Setup
Review presets/ragdoll.gd:
- Helper for creating ragdoll physics bodies
- Joint configuration
- Collision setup

---

## Phase 11: Supporting Components Review

### 11.1 Procedural Lean Component
Review procedural_lean_component.gd:
- Body lean into movement direction
- Turn banking
- How does this integrate with hip motion?

### 11.2 Item Slots
Review item_slots.gd:
- Visual attachment points on character
- BoneAttachment3D usage
- Item visibility management

### 11.3 Spring Bone World Collision
Review spring_bone_world_collision.gd:
- Physics bone collision detection
- Spring damping
- Performance impact

---

## Phase 12: Documentation Audit

### 12.1 README.md
Check if exists and contains:
- Installation instructions
- Setup instructions (how to use with CharacterBody3D)
- Feature list (stride wheel, IK, ragdoll, etc.)
- Configuration guide (how to tune parameters)
- Example usage

### 12.2 Inline Documentation
Ensure:
- All component classes have doc comments explaining purpose
- `StrideWheelConfig` parameters have clear descriptions (some are very technical)
- IK solver math is explained (two-bone IK formula)
- Spring physics formulas are documented
- SkeletonModifier3D pipeline order is documented

### 12.3 Code Comments
Check:
- Complex algorithms explained (gait cycle, footfall detection, spring damping)
- Non-obvious decisions have "why" comments
- Magic numbers explained (why those specific values?)
- AAA animation techniques cited (footfall impacts, hip motion, etc.)

---

## Phase 13: Output Format

### 13.1 Findings Report
Create a structured report with:

```markdown
## Summary Statistics
- Total .gd files: X
- Total lines of code: X
- Total .tscn scenes: X
- Total .tres resources: X
- Largest files: [list top 5, flag if >1000 lines]
- Classes defined: X (with class_name)
- Signals defined: X
- Export parameters: X (across all configs)

## Component Dependency Map
[Diagram or text showing component relationships]
- CharacterVisuals → child components
- StrideWheelComponent → HipRockModifier data flow
- LocomotionComponent → AnimationTree → root motion
- Config resources → components

## Godot Built-in Node Usage Review
1. [Component] — Uses [Godot Node] — [Correct/Incorrect/Could be improved]

## Critical Issues (Must Fix)
1. [Issue] — [File:Line] — [Impact on animation quality/performance]

## Recommended Improvements (Should Fix)
1. [Issue] — [File:Line] — [Benefit]

## Optional Optimizations (Nice to Have)
1. [Issue] — [File:Line] — [Benefit]

## Dead Code to Remove
- [File/Function] — [Reason: never called, feature incomplete, etc.]

## Duplicate Code to Consolidate
- [Pattern] found in [File1], [File2], [File3] — [Consolidation suggestion]

## Configuration Complexity
- stride_wheel_config.gd: X parameters across Y groups
- Recommendation: [simplify/split/keep as-is]

## Performance Hotspots
- [Component] — [Potential bottleneck] — [Optimization suggestion]

## SkeletonModifier3D Pipeline Order
Current order: [list modifiers]
Recommendation: [correct/needs reordering]
```

### 13.2 Refactoring Plan
After the report, propose a prioritized action plan:

**Priority 1: Critical Fixes**
- Performance issues (bone lookups in hot paths, etc.)
- Broken functionality
- SkeletonModifier3D pipeline order issues

**Priority 2: Code Quality**
- Extract shared IK solver
- Consolidate spring physics
- Remove dead code

**Priority 3: Simplification**
- Config resource simplification
- Component merging (if warranted)
- Debug flag consolidation

Each action item should specify:
- What to change
- Why it improves the codebase
- Risk level (safe / needs testing / breaking change)
- Estimated scope (lines affected, files touched)
- Prerequisites (must complete X before Y)

---

## Constraints

- **DO NOT** remove or modify any functionality without explicit approval
- **DO NOT** change public APIs (method signatures, signal names, export properties) without documenting the breaking change
- **DO** preserve all existing behavior
- **DO** maintain backwards compatibility with existing character visuals scenes
- **DO** keep the audit non-destructive — report findings, don't auto-fix
- **DO** prioritize Godot built-in nodes over custom implementations (Skeleton3D, SkeletonModifier3D, AnimationTree)
- **DO** respect SkeletonModifier3D pipeline order (critical for correct animation)

---

## Deliverables

1. **audit_report.md** — Full findings document
2. **refactoring_plan.md** — Prioritized action items
3. **component_dependency_map.md** — Component relationships and data flow
4. **dead_code_list.md** — Files/functions safe to remove
5. **performance_recommendations.md** — Optimization opportunities (bone caching, transform math, etc.)
6. **config_simplification_proposal.md** — Recommendations for reducing config complexity

---

## Environment

- **Godot Version**: 4.6
- **Physics Engine**: Jolt (default for Godot 4.6)
- **Target Use Case**: Fully procedural AAA character animation for third-person action games
- **Key Dependencies**: Requires Skeleton3D, AnimationTree, CharacterBody3D from game

---

## Current File Inventory

### renegade_visuals/
```
plugin.cfg
plugin.gd

nodes/
├── character_visuals.gd              # Main coordinator
├── stride_wheel_component.gd         # Procedural locomotion (LARGE)
├── hip_rock_modifier.gd              # SkeletonModifier3D for hip motion
├── locomotion_component.gd           # Root motion integration
├── foot_ik_component.gd              # Foot IK solver
├── hand_ik_component.gd              # Hand IK solver
├── hand_object_placement.gd          # Object holding IK
├── wall_hand_placement.gd            # Wall touching IK
├── hit_reaction_component.gd         # Hit detection
├── hit_reaction_modifier.gd          # SkeletonModifier3D for hits
├── hit_reactor_component.gd          # Hit physics (?)
├── active_ragdoll_component.gd       # Powered ragdoll
├── procedural_lean_component.gd      # Body leaning
├── item_slots.gd                     # Visual item attachment
└── spring_bone_world_collision.gd    # Spring bone physics

resources/
├── stride_wheel_config.gd            # 256 lines, 80+ parameters
├── foot_ik_config.gd
├── locomotion_config.gd
├── lean_config.gd
├── hit_reaction_config.gd
└── skeleton_config.gd                # Bone mapping

presets/
├── character_visuals.tscn            # Main template
└── ragdoll.gd                        # Ragdoll setup helper

defaults/
└── mannequin/
    └── uefn_skeleton_config.tres     # UEFN bone map

tools/
└── skeleton_analyzer.gd              # Editor tool
```

---

## Getting Started

Begin audit by:
1. Reading each .gd file and documenting class structure
2. Identifying the largest files (stride_wheel_component.gd is likely >2000 lines)
3. Mapping component dependencies (CharacterVisuals → child components)
4. Checking SkeletonModifier3D pipeline order
5. Looking for duplicate IK solver implementations
6. Reviewing spring physics consistency
7. Checking bone index caching patterns

Work through each phase systematically. Flag anything that seems questionable or could be improved.