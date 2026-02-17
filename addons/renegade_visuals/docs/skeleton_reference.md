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

**Generated: 2025-02-17**
**Godot: v4.6.stable**

```
======================================================================
COMPLETE BONE AXIS REFERENCE (for IK/procedural rotations)
======================================================================

pelvis (idx=2):
  Rest euler: (-0.0°, -90.0°, -2.1°)
  Local X -> 100% Back
  Local Y -> 100% Up
  Local Z -> 100% Left
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.FORWARD (local Z ≈ world right, 100%)
  ROLL (tilt): Vector3.RIGHT (local X ≈ world forward, 100%)

spine_01 (idx=3):
  Rest euler: (-0.0°, -0.0°, 3.9°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

spine_02 (idx=4):
  Rest euler: (-0.0°, -0.0°, 2.7°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

spine_03 (idx=5):
  Rest euler: (-0.0°, 0.0°, 1.7°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

neck_01 (idx=64):
  Rest euler: (0.0°, -0.0°, -23.1°)
  Local X -> 92% Right, 39% Down
  Local Y -> 39% Right, 92% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 92%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 92%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

neck_02 (idx=65):
  Rest euler: (-0.0°, 0.0°, 5.8°)
  Local X -> 99% Right
  Local Y -> 99% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 99%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 99%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

head (idx=66):
  Rest euler: (-0.0°, -0.0°, 13.2°)
  Local X -> 97% Right
  Local Y -> 97% Up
  Local Z -> 100% Back
  Bone points along: leaf
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 97%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 97%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

======================================================================
CLAVICLE BONES (Important for shoulder motion)
======================================================================

clavicle_l (idx=8):
  Rest euler: (4.4°, 93.9°, 3.2°)
  Local X -> 100% Forward
  Local Y -> 100% Up
  Local Z -> 99% Right
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.FORWARD (local Z ≈ world right, 99%)
  ROLL (tilt): Vector3.RIGHT (local X ≈ world forward, 100%)

clavicle_r (idx=36):
  Rest euler: (-4.4°, -93.9°, -176.8°)
  Local X -> 100% Forward
  Local Y -> 100% Down  <-- MIRRORED
  Local Z -> 99% Left   <-- MIRRORED
  Bone points along: -X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.FORWARD (local Z ≈ world right, 99%)
  ROLL (tilt): Vector3.RIGHT (local X ≈ world forward, 100%)

CLAVICLE ROTATION GUIDE:
  - Protraction (shoulder forward/back): Use PITCH axis = Vector3.FORWARD
  - Elevation (shoulder up/down): Use ROLL axis = Vector3.RIGHT
  - NOTE: Right clavicle has mirrored Y (Down) and Z (Left)
  - For mirrored bone, NEGATE the rotation angle for symmetric motion

======================================================================
ARM BONES
======================================================================

upperarm_l (idx=9):
  Rest euler: (2.8°, 37.8°, -0.1°)
  Local X -> 79% Right, 61% Forward
  Local Y -> 100% Up
  Local Z -> 61% Right, 79% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 79%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 79%)

upperarm_r (idx=37):
  Rest euler: (2.8°, 37.8°, -0.1°)
  Local X -> 79% Right, 61% Forward
  Local Y -> 100% Up
  Local Z -> 61% Right, 79% Back
  Bone points along: -X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 79%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 79%)

lowerarm_l (idx=10):
  Rest euler: (4.6°, -0.0°, -28.4°)
  Local X -> 88% Right, 47% Down
  Local Y -> 48% Right, 88% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 88%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 88%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

lowerarm_r (idx=38):
  Rest euler: (4.6°, -0.0°, -28.4°)
  Local X -> 88% Right, 47% Down
  Local Y -> 48% Right, 88% Up
  Local Z -> 100% Back
  Bone points along: -X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 88%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 88%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

hand_l (idx=11):
  Rest euler: (-86.1°, -96.7°, 108.8°)
  Local X -> 98% Right
  Local Y -> 98% Forward
  Local Z -> 100% Up
  Bone points along: -Z
  TWIST (yaw): Vector3.FORWARD (local Z ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 98%)
  ROLL (tilt): Vector3.UP (local Y ≈ world forward, 98%)

hand_r (idx=39):
  Rest euler: (-86.1°, -96.7°, 108.8°)
  Local X -> 98% Right
  Local Y -> 98% Forward
  Local Z -> 100% Up
  Bone points along: +Z
  TWIST (yaw): Vector3.FORWARD (local Z ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 98%)
  ROLL (tilt): Vector3.UP (local Y ≈ world forward, 98%)

======================================================================
LEG BONES
======================================================================

thigh_l (idx=67):
  Rest euler: (0.2°, -6.6°, 1.8°)
  Local X -> 99% Right
  Local Y -> 100% Up
  Local Z -> 99% Back
  Bone points along: -X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 99%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 99%)

thigh_r (idx=74):
  Rest euler: (-0.2°, 6.6°, -178.2°)
  Local X -> 99% Left
  Local Y -> 100% Down  <-- MIRRORED
  Local Z -> 99% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 99%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 99%)

calf_l (idx=68):
  Rest euler: (0.1°, 1.8°, -4.5°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: -X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

calf_r (idx=75):
  Rest euler: (0.1°, 1.8°, -4.5°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

foot_l (idx=71):
  Rest euler: (4.6°, 5.4°, 4.2°)
  Local X -> 99% Right
  Local Y -> 99% Up
  Local Z -> 99% Back
  Bone points along: -Y
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 99%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 99%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 99%)

foot_r (idx=78):
  Rest euler: (4.6°, 5.4°, 4.2°)
  Local X -> 99% Right
  Local Y -> 99% Up
  Local Z -> 99% Back
  Bone points along: +Y
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 99%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 99%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 99%)

ball_l (idx=72):
  Rest euler: (0.0°, 0.0°, -89.9°)
  Local X -> 100% Down
  Local Y -> 100% Right
  Local Z -> 100% Back
  Bone points along: leaf
  TWIST (yaw): Vector3.RIGHT (local X ≈ world up, 100%)
  PITCH (nod): Vector3.UP (local Y ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

ball_r (idx=79):
  Rest euler: (0.0°, 0.0°, -89.9°)
  Local X -> 100% Down
  Local Y -> 100% Right
  Local Z -> 100% Back
  Bone points along: leaf
  TWIST (yaw): Vector3.RIGHT (local X ≈ world up, 100%)
  PITCH (nod): Vector3.UP (local Y ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

======================================================================
ROOT BONE
======================================================================

root (idx=0):
  Rest euler: (-0.0°, 0.0°, 0.0°)
  Local X -> 100% Right
  Local Y -> 100% Up
  Local Z -> 100% Back
  Bone points along: -Z
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 100%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 100%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

======================================================================
TWIST BONES (for smooth deformation)
======================================================================

upperarm_twist_01_l (idx=34):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

upperarm_twist_01_r (idx=62):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

lowerarm_twist_01_l (idx=32):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

lowerarm_twist_01_r (idx=60):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

thigh_twist_01_l (idx=73):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

thigh_twist_01_r (idx=80):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

calf_twist_01_l (idx=69):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

calf_twist_01_r (idx=76):
  Local X -> 100% Right, Local Y -> 100% Up, Local Z -> 100% Back

======================================================================
FINGER REFERENCE (index finger as example)
======================================================================

index_01_l (idx=13):
  Rest euler: (0.0°, -5.6°, 10.6°)
  Local X -> 98% Right
  Local Y -> 98% Up
  Local Z -> 100% Back
  Bone points along: +X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 98%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 98%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)

index_01_r (idx=41):
  Rest euler: (0.0°, -5.6°, 10.6°)
  Local X -> 98% Right
  Local Y -> 98% Up
  Local Z -> 100% Back
  Bone points along: -X
  TWIST (yaw): Vector3.UP (local Y ≈ world up, 98%)
  PITCH (nod): Vector3.RIGHT (local X ≈ world right, 98%)
  ROLL (tilt): Vector3.FORWARD (local Z ≈ world forward, 100%)
```

---

## Rotation Axis Quick Reference

### Standard Bones (spine, legs, arms)

| Motion | Axis | Notes |
|--------|------|-------|
| Twist/Yaw | Vector3.UP | Rotate around world up (local Y for most bones) |
| Pitch/Nod | Vector3.RIGHT | Rotate around world right (local X for most bones) |
| Roll/Tilt | Vector3.FORWARD | Rotate around world forward (local Z for most bones) |

### Clavicle Bones (SPECIAL ORIENTATION)

| Motion | Left Clavicle | Right Clavicle |
|--------|---------------|----------------|
| Protraction (forward/back) | Vector3.FORWARD | Vector3.FORWARD (negate angle) |
| Elevation (up/down) | Vector3.RIGHT | Vector3.RIGHT (negate angle) |

**Key difference**: Clavicle bones are rotated 90° around Y, so:
- Local X -> Forward (not Right)
- Local Z -> Right (not Back)
- Right clavicle is mirrored: Local Y -> Down, Local Z -> Left

### Hand Bones (SPECIAL ORIENTATION)

| Motion | Axis | Notes |
|--------|------|-------|
| Twist/Yaw | Vector3.FORWARD | Local Z = World Up |
| Pitch/Nod | Vector3.RIGHT | Local X = World Right |
| Roll/Tilt | Vector3.UP | Local Y = World Forward |

### Mirrored Bones

These bones have mirrored orientation (Local Y = Down):
- `thigh_r` - Local Y -> Down, Local X -> Left
- `clavicle_r` - Local Y -> Down, Local Z -> Left

For symmetric motion on mirrored bones, negate the rotation angle.

---

## Code Examples

### Spine/Torso Rotation
```gdscript
# All components map correctly for standard bones
var twist_rotation := Basis(Vector3.UP, twist_angle)
var pitch_rotation := Basis(Vector3.RIGHT, pitch_angle)
var roll_rotation := Basis(Vector3.FORWARD, roll_angle)
```

### Clavicle Rotation
```gdscript
# Clavicle has rotated orientation - use FORWARD for protraction
# Left clavicle
var protraction := Basis(Vector3.FORWARD, protract_angle)
var elevation := Basis(Vector3.RIGHT, elevate_angle)

# Right clavicle (negate for mirror)
var protraction_r := Basis(Vector3.FORWARD, -protract_angle)
var elevation_r := Basis(Vector3.RIGHT, -elevate_angle)
```

### Hand Rotation
```gdscript
# Hands are rotated 90° - Z axis is up
var hand_twist := Basis(Vector3.FORWARD, twist_angle)  # Not UP!
```

---

*Last updated from debug_bone_axes output: 2025-02-17*
