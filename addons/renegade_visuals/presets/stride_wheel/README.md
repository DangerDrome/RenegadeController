# Stride Wheel Presets

Pre-configured StrideWheelConfig resources for common use cases. These presets provide starting points for different animation styles and can be customized further in the inspector.

## Available Presets

### realistic.tres
**Production-ready realistic human locomotion**
- Balanced parameters for natural-looking movement
- Moderate hip bob and shoulder rotation
- Footfall impacts and breathing enabled
- Best for: Third-person action games, realistic sims

**Key features:**
- Standard stride length (0.5m walk, 2.2m run)
- Subtle hip motion and shoulder counter-rotation
- Turn banking and idle sway enabled
- AAA footfall impact system

### stylized.tres
**Exaggerated anime/game-like movement**
- Larger, bouncier motions
- Pronounced hip rock and shoulder swing
- Heel-to-toe roll enabled for emphasis
- Best for: Stylized games, anime aesthetics, arcade feel

**Key features:**
- Longer strides (0.7m walk, 2.5m run)
- Exaggerated hip motion (8° rock X, 10° rock Y)
- High shoulder rotation (8°)
- Increased crossover for runway-style walk
- Start/stop motion enabled

### minimal.tres
**Bare minimum stride wheel (debugging/prototyping)**
- Only basic foot placement
- All extras disabled
- Fast iteration, low complexity
- Best for: Initial setup, debugging, performance testing

**Key features:**
- Simple foot placement only
- No hip motion, breathing, or banking
- No shoulder rotation or clavicle motion
- Straight leg extension, minimal smoothing
- Use this to verify basic IK setup before adding polish

### tactical.tres
**Military/tactical movement (Metal Gear Solid, SOCOM style)**
- Shorter, controlled strides
- Lowered hip (crouched stance)
- Minimal bob, more grounded
- Best for: Stealth games, tactical shooters, realistic military sims

**Key features:**
- Short strides (0.4m walk, 1.8m run)
- Lowered hip offset (-0.05m for knee bend)
- Reduced hip bob (0.05m vs 0.1m)
- Wider stance (0.12m lateral offset)
- Higher stance ratio (0.65 = more grounded)
- Controlled turn banking (8° vs 15°)

## Usage

1. **In the Inspector**:
   - Select your StrideWheelComponent node
   - Drag a preset .tres file onto the `config` property

2. **At Runtime**:
   ```gdscript
   var config = load("res://addons/renegade_visuals/presets/stride_wheel/realistic.tres")
   stride_wheel.config = config
   ```

3. **Customization**:
   - After loading a preset, you can override individual parameters
   - Use "Make Unique" in the inspector to create a custom copy
   - Save your customized config as a new .tres for reuse

## Parameter Quick Reference

**For natural human walk:**
- stride_length: 0.45-0.55m
- hip_bob_amount: 0.08-0.12m
- crossover_amount: 0.3-0.5

**For run/sprint:**
- max_stride_length: 2.0-2.5m
- step_height: 0.15-0.25m
- min_stance_ratio: 0.3-0.4

**For stylized/exaggerated:**
- Increase all motion parameters by 50-100%
- Enable heel_toe_roll and start_stop
- Increase gait_asymmetry and cadence_variation

**For tactical/grounded:**
- Reduce stride_length by 20%
- Set hip_offset to -0.05 to -0.1
- Reduce hip_bob_amount to 0.03-0.06
- Increase stance_lateral_stagger for wider stance

## Debugging

All presets have debug flags disabled by default. To visualize:
- `debug_hip = true` - Shows hip motion debug lines
- `debug_ground = true` - Shows ground raycast visualization
- `debug_foot_rotation = true` - Shows foot rotation gizmos
- `debug_turn_in_place = true` - Shows turn-in-place stepping

Enable these during setup to verify IK is working correctly.
