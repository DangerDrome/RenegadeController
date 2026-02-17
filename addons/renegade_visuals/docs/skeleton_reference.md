# Skeleton Bone Reference

This document contains bone orientation data for the UEFN character skeleton used in procedural IK.

## How to Regenerate This Data

1. In the scene, find the **StrideWheelComponent**
2. Expand the **Debug** group in the inspector
3. Enable **Debug Bone Axes**
4. Run the game - bone data prints to console
5. Copy output here

---

## UEFN Skeleton Bone Data

**Generated: 2024**

```
======================================================================
BONE AXIS REFERENCE (for IK rotations)
======================================================================

pelvis (idx=2):
  Rest euler: (-0.0°, -90.0°, -2.1°)
  Local X -> 100% Back
  Local Y -> 100% Up
  Local Z -> 100% Left
  Bone points along: +X
  TWIST AXIS: Y (rotate around local Y for yaw)

spine_01 (idx=3):
  Rest euler: (-0.0°, -0.0°, 3.9°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST AXIS: Y (rotate around local Y for yaw)

spine_02 (idx=4):
  Rest euler: (-0.0°, -0.0°, 2.7°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST AXIS: Y (rotate around local Y for yaw)

spine_03 (idx=5):
  Rest euler: (-0.0°, 0.0°, 1.7°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST AXIS: Y (rotate around local Y for yaw)

foot_l (idx=71):
  Rest euler: (4.6°, 5.4°, 4.2°)
  Local X -> 99% Right
  Local Y -> 99% Up
  Local Z -> 99% Back
  Bone points along: -Y
  TWIST AXIS: Y (rotate around local Y for yaw)

foot_r (idx=78):
  Rest euler: (4.6°, 5.4°, 4.2°)
  Local X -> 99% Right
  Local Y -> 99% Up
  Local Z -> 99% Back
  Bone points along: +Y
  TWIST AXIS: Y (rotate around local Y for yaw)

thigh_l (idx=67):
  Rest euler: (0.2°, -6.6°, 1.8°)
  Local X -> 99% Right
  Local Y -> 100% Up
  Local Z -> 99% Back
  Bone points along: -X
  TWIST AXIS: Y (rotate around local Y for yaw)

thigh_r (idx=74):
  Rest euler: (-0.2°, 6.6°, -178.2°)
  Local X -> 99% Left
  Local Y -> 100% Down  <-- MIRRORED (normal for right-side bones)
  Local Z -> 99% Back
  Bone points along: +X
  TWIST AXIS: Check orientation! (mirrored)

calf_l (idx=68):
  Rest euler: (0.1°, 1.8°, -4.5°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: -X
  TWIST AXIS: Y (rotate around local Y for yaw)

calf_r (idx=75):
  Rest euler: (0.1°, 1.8°, -4.5°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST AXIS: Y (rotate around local Y for yaw)

upperarm_l (idx=9):
  Rest euler: (2.8°, 37.8°, -0.1°)
  Local X -> 79% Right, 61% Forward
  Local Y -> 100% Up
  Local Z -> 61% Right, 79% Back
  Bone points along: +X
  TWIST AXIS: Y (rotate around local Y for yaw)

upperarm_r (idx=37):
  Rest euler: (2.8°, 37.8°, -0.1°)
  Local X -> 79% Right, 61% Forward
  Local Y -> 100% Up
  Local Z -> 61% Right, 79% Back
  Bone points along: -X
  TWIST AXIS: Y (rotate around local Y for yaw)

lowerarm_l (idx=10):
  Rest euler: (4.6°, -0.0°, -28.4°)
  Local X -> 88% Right, 47% Down
  Local Y -> 48% Right, 88% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST AXIS: Angled (elbow bend in T-pose)

lowerarm_r (idx=38):
  Rest euler: (4.6°, -0.0°, -28.4°)
  Local X -> 88% Right, 47% Down
  Local Y -> 48% Right, 88% Up
  Local Z -> 100% Back
  Bone points along: -X
  TWIST AXIS: Angled (elbow bend in T-pose)

hand_l (idx=11):
  Rest euler: (-86.1°, -96.7°, 108.8°)
  Local X -> 98% Right
  Local Y -> 98% Forward
  Local Z -> 100% Up
  Bone points along: -Z
  TWIST AXIS: Z (hands oriented differently)

hand_r (idx=39):
  Rest euler: (-86.1°, -96.7°, 108.8°)
  Local X -> 98% Right
  Local Y -> 98% Forward
  Local Z -> 100% Up
  Bone points along: +Z
  TWIST AXIS: Z (hands oriented differently)

======================================================================
KEY FINDINGS:
- Torso/spine bones: Local Y = World Up, use Y for twist
- Legs: Local Y = Up (except thigh_r which is mirrored)
- Arms: Local Y = Up for upper arms
- Hands: Local Z = Up (rotated 90° from body)
======================================================================
```

---

## Rotation Axis Quick Reference

### Torso (Pelvis, Spine)

| Motion | Euler Component | Axis |
|--------|-----------------|------|
| Lateral tilt (roll) | X | Local X (Back for pelvis, Right for spine) |
| **Twist/Yaw** | **Y** | **Local Y = World Up** |
| Forward tilt (pitch) | Z | Local Z |

### Code Examples

```gdscript
# Hip rock - all components map correctly for this skeleton
var rock_rotation := Basis.from_euler(hip_rock)  # (X=roll, Y=twist, Z=pitch)

# Spine counter-rotation - twist around Y axis
var local_rotation := Basis.from_euler(Vector3(lean_angle, counter_twist, 0.0))
#                                              X=forward lean  Y=twist    Z=unused

# Foot yaw rotation - use world Y axis (all feet have local Y ≈ world Y)
var yaw_rotation := Basis(Vector3.UP, yaw_angle)
```

### Notes

1. **Right thigh is mirrored** - `Local Y = Down` instead of Up. This is normal for mirrored skeleton rigs.

2. **Forearms are angled** - Due to slight elbow bend in T-pose. The IK system uses targets, not direct rotation, so this doesn't affect functionality.

3. **Hands have different orientation** - `Local Z = Up` instead of `Local Y = Up`. Hand IK should rotate around Z for twist.

---

*Last updated from debug_bone_axes output*
