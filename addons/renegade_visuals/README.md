# Renegade Visuals — Character Animation Plugin v0.1.0

IK-first character animation system for **Renegade Cop** (Godot 4.6).
Root motion locomotion, foot/hand IK, hit reactions, procedural lean.

## Architecture

```
CharacterBody3D (your controller)
└── CharacterVisuals
    ├── [Your Character Scene]           ← FBX mannequin with Skeleton3D + AnimationTree
    │   ├── Skeleton3D
    │   │   ├── MeshInstance3D
    │   │   ├── TwoBoneIK3D (left leg)   → targets LeftFootTarget
    │   │   ├── TwoBoneIK3D (right leg)  → targets RightFootTarget
    │   │   ├── TwoBoneIK3D (left arm)   → targets LeftHandTarget
    │   │   ├── TwoBoneIK3D (right arm)  → targets RightHandTarget
    │   │   ├── LookAtModifier3D (head)
    │   │   ├── LimitAngularVelocityModifier3D
    │   │   ├── CopyTransformModifier3D (left foot rotation)
    │   │   ├── CopyTransformModifier3D (right foot rotation)
    │   │   └── PhysicalBoneSimulator3D
    │   ├── AnimationPlayer
    │   └── AnimationTree
    ├── Marker3D (LeftFootTarget)
    ├── Marker3D (RightFootTarget)
    ├── Marker3D (LeftHandTarget)
    ├── Marker3D (RightHandTarget)
    ├── LocomotionComponent              ← Root motion + blend params + stride clamping
    ├── StrideWheelComponent             ← Procedural walk IK (no animations needed)
    ├── FootIKComponent                  ← Raycast ground IK + hip offset
    ├── HandIKComponent                  ← Interaction hand IK
    ├── HitReactionComponent             ← Flinch + partial ragdoll + full ragdoll + hitstop
    └── ProceduralLeanComponent          ← Acceleration lean + pelvis slope tilt
```

## Processing Pipeline

Godot 4.6's guaranteed processing order makes this work:

1. **AnimationTree** blends root motion animations → writes bone poses
2. **LocomotionComponent** extracts root motion → drives CharacterBody3D.move_and_slide()
3. **StrideWheelComponent** (if no walk anims) drives foot targets procedurally from velocity
4. **FootIKComponent** raycasts ground → positions Marker3D targets → adjusts pelvis height
5. **TwoBoneIK3D** (SkeletonModifier3D) solves leg chains to reach targets
6. **CopyTransformModifier3D** copies foot rotation from ground-aligned targets
7. **LimitAngularVelocityModifier3D** smooths any IK snapping
8. **ProceduralLeanComponent** applies additive spine lean from acceleration
9. **HitReactionComponent** applies flinch offsets or ragdoll influence
10. **PhysicalBoneSimulator3D** (if active) blends physics poses via influence

SkeletonModifier3D children process in **scene tree order** — arrange them accordingly.

## Quick Setup

### 1. Enable the plugin
Project → Project Settings → Plugins → Enable "Renegade Visuals"

### 2. Import your FBX
Drop your UEFN mannequin `.fbx` into the project. Animations as separate FBX files
will auto-import as AnimationLibrary resources. Add `-loop` suffix for looping clips.

### 3. Set up the character scene
On your imported mannequin scene, add as children of Skeleton3D:
- `TwoBoneIK3D` × 4 (left/right leg, left/right arm)
- `LimitAngularVelocityModifier3D`
- `CopyTransformModifier3D` × 2 (left/right foot rotation)
- `LookAtModifier3D` (head tracking)
- `PhysicalBoneSimulator3D` (for ragdoll)

Set up your AnimationTree with:
- Root: BlendTree
- BlendSpace2D for 8-way locomotion (X = strafe, Y = forward/back)
- State machine for locomotion states (idle/walk/run, turn-in-place, jump)
- Blend2 with bone filter for upper/lower body layering
- Set `root_motion_track` to `Skeleton3D:root`

### 4. Add CharacterVisuals to your controller
```
CharacterBody3D
└── CharacterVisuals
    ├── LocomotionComponent
    ├── FootIKComponent
    ├── HandIKComponent
    ├── HitReactionComponent
    └── ProceduralLeanComponent
```

### 5. Assign resources in Inspector
- CharacterVisuals → `skeleton_config`: use `uefn_skeleton_config.tres` or make your own
- CharacterVisuals → `character_scene`: your mannequin scene
- Each component → assign its config resource (or leave null for defaults)
- FootIKComponent → assign IK node and target paths
- HandIKComponent → assign IK node and target paths
- HitReactionComponent → assign PhysicalBoneSimulator3D path

### 6. Wire up Marker3D targets
Add 4 Marker3D nodes as children of CharacterVisuals:
- LeftFootTarget, RightFootTarget, LeftHandTarget, RightHandTarget
These are positioned by the IK components each frame. Point TwoBoneIK3D target
properties at these Marker3D nodes.

## Component API

### CharacterVisuals
```gdscript
# Trigger hit reaction (call from combat system)
character_visuals.apply_hit(&"spine_02", hit_direction, 5.0)

# Full ragdoll (death)
character_visuals.trigger_ragdoll(hit_direction, 15.0)

# Recovery from ragdoll
character_visuals.begin_recovery(face_up)
```

### HandIKComponent
```gdscript
# Reach for a door handle
hand_ik.reach_right(door_handle.global_position)

# Push an object with both hands
hand_ik.reach_both(left_grip.global_position, right_grip.global_position)

# Release
hand_ik.release_right()
hand_ik.release_both()
```

### StrideWheelComponent
Procedural stride wheel — generates walk/run leg motion from velocity alone, no walk
animations required. Feet plant on the ground during stance phase and swing in an arc
to the next plant position. Includes hip bob and ground-following hip drop.

Use **instead of** FootIKComponent when you have no locomotion animations. Use
FootIKComponent when you have walk/run anims and just need ground adaptation.

Assign `left_leg_ik` / `right_leg_ik` (TwoBoneIK3D) and `left_foot_target` /
`right_foot_target` (Marker3D) in the inspector.

### LocomotionComponent
```gdscript
# Query movement state
if locomotion.is_moving():
    # ...
```

## Configuration Resources

All tuning is done via `.tres` resource files — human-readable, Git-friendly:

- **SkeletonConfig** — bone name mappings (swap for different characters)
- **LocomotionConfig** — root motion, blending, stride rate clamping
- **FootIKConfig** — ray distances, hip offset, influence curves
- **StrideWheelConfig** — stride length/height, hip bob/drop, ground ray, foot rotation
- **HitReactionConfig** — hitstop, flinch, ragdoll, force thresholds
- **LeanConfig** — lean angle, speed, pelvis tilt

## Stride Wheel Approach

Procedural walk cycle driven entirely by character velocity — no walk/run animations needed:

- Phase accumulator advances based on `speed / stride_length`
- Each foot alternates between **plant phase** (locked at world position while character moves)
  and **swing phase** (arc from old plant to predicted next plant via sin curve)
- Next plant position predicted from move direction + stride length, raycasted to find ground
- Hip bobs sinusoidally during cycle, plus drops to follow lowest foot (ground adaptation)
- Hip drop applied to `CharacterVisuals.position.y` (not pelvis bone) to avoid bone-space drift
- IK influence blends up when moving + grounded, down at idle or airborne
- Safety clamp re-plants feet that drift too far on sudden direction changes

Use StrideWheelComponent when you have no locomotion animations. Once you add walk/run
anims, switch to FootIKComponent which only corrects the delta from animated positions.

## Foot IK Approach

Uses **offset-based targeting** (same as Unity FinalIK Grounder):
- Raycasts from each animated foot position
- Computes ground height *difference* from where animation places the foot
- Drops pelvis by the needed amount
- IK only corrects the delta — on flat ground, IK does nothing

This never fights root motion because it only adjusts the difference.

## Hit Reaction Tiers

| Tier | Trigger | What happens |
|------|---------|-------------|
| Flinch | force < 3.0 | Additive spine rotation, decays over ~0.3s |
| Partial ragdoll | force < 10.0 | Physics on hit area, influence tweens 0.6→0, ~0.4s |
| Full ragdoll | force ≥ 10.0 | All bones physical, animation disabled, recovery via signal |

All tiers trigger **hitstop** (1-2 frame freeze) for combat feel.

## Key Godot 4.6 Features Used

- **TwoBoneIK3D** — deterministic two-bone IK for limbs
- **CopyTransformModifier3D** — copies rotation from Marker3D to foot bones
- **LimitAngularVelocityModifier3D** — smooths IK snapping
- **LookAtModifier3D** — head tracking
- **PhysicalBoneSimulator3D** — ragdoll with `influence` blending
- **SkeletonModifier3D** processing order guarantee
- **AnimationTree.root_motion_local** — fixes crossfade drift

## Known Limitations

- TwoBoneIK3D solves position only, not rotation (hence CopyTransformModifier3D)
- Root motion extraction happens before IK modifiers (by design — IK doesn't affect movement)
- Method Call Tracks in AnimationTree can be unreliable through blend nodes (use timer-based footsteps)
- Active ragdoll (partial physics + animation fighting) requires tuning per-character
- No built-in distance matching — stride rate clamping covers ~80% of foot slide
- Hip drop uses visual root Y offset (not pelvis bone) to avoid bone-space drift with complex skeletons
