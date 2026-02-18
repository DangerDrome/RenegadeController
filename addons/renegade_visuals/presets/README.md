# Renegade Visuals — Configuration Presets

Pre-configured resource files for quick setup and prototyping. These presets provide production-ready starting points for common use cases.

## Directory Structure

```
presets/
├── stride_wheel/       # Procedural walk cycle configs
│   ├── realistic.tres
│   ├── stylized.tres
│   ├── minimal.tres
│   └── tactical.tres
├── foot_ik/           # Foot IK ground adaptation configs
│   ├── standard.tres
│   ├── grounded.tres
│   ├── subtle.tres
│   └── steep_terrain.tres
└── hit_reaction/      # Combat hit reaction configs
    ├── arcade.tres
    ├── realistic.tres
    ├── minimal.tres
    └── souls_like.tres
```

## Quick Start

### For Procedural Walk (no animations)
1. Add StrideWheelComponent to your character
2. Assign a preset from `stride_wheel/`:
   - `realistic.tres` — Natural human locomotion
   - `stylized.tres` — Exaggerated anime/game-like
   - `minimal.tres` — Debugging/prototyping
   - `tactical.tres` — Military/stealth movement

### For Animated Walk (with walk/run clips)
1. Add FootIKComponent to your character
2. Assign a preset from `foot_ik/`:
   - `standard.tres` — Balanced for most games
   - `grounded.tres` — Very uneven terrain
   - `subtle.tres` — Preserves animation more
   - `steep_terrain.tres` — Mountains/hills

### For Combat Hit Reactions
1. Add HitReactionComponent to your character
2. Assign a preset from `hit_reaction/`:
   - `arcade.tres` — Snappy, exaggerated (action games)
   - `realistic.tres` — Subtle, grounded
   - `minimal.tres` — Very light reactions
   - `souls_like.tres` — Heavy hits, long hitstop

## Customization

All presets can be customized after loading:

1. **In Inspector**: Load preset → Modify parameters → "Make Unique" → Save as new .tres
2. **At Runtime**: Load preset → Override specific parameters in code
3. **Copy Preset**: Duplicate .tres file → Edit in external editor → Use as template

## File Format

Presets are text-based `.tres` files (Godot's resource format). They can be:
- Edited in any text editor
- Version controlled with Git (human-readable diffs)
- Shared across projects
- Modified without recompiling

Example:
```tres
[gd_resource type="Resource" script_class="StrideWheelConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/renegade_visuals/resources/stride_wheel_config.gd" id="1"]

[resource]
script = ExtResource("1")
stride_length = 0.5
max_stride_length = 2.2
# ... more parameters
```

## Creating New Presets

1. Load an existing preset as a starting point
2. Adjust parameters in the Inspector
3. Right-click resource → "Make Unique"
4. Right-click → "Save" → Save to `presets/` directory
5. Name clearly (e.g., `zombie_shamble.tres`, `fast_sprint.tres`)

## Tips

- **Start with a preset** instead of default values — they're production-tested
- **Use minimal presets for debugging** — fewer moving parts = easier troubleshooting
- **Combine presets** — Use realistic stride_wheel + grounded foot_ik for uneven terrain
- **Version control** — Check .tres files into Git for team sharing

## Preset Philosophy

These presets follow the "sensible defaults" principle:
- **realistic** — Production-ready AAA quality
- **stylized** — Exaggerated for artistic games
- **minimal** — Bare minimum for debugging
- **tactical/arcade/etc** — Genre-specific tuning

All debug flags are **disabled by default**. Enable them during setup to verify IK configuration.
