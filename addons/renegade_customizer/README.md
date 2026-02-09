# Renegade Customizer

Character customizer plugin for Renegade Cop. Provides a turntable 3D character preview
with equipment slot UI, drag-and-drop gear management, and live visual updates on the
character model.

**CassettePunk aesthetic** — warm halogen lighting, amber CRT stats, VHS-era rarity colors.

## Requirements

- Godot 4.6+
- `addons/renegade_controller/` plugin (provides Inventory, EquipmentManager, ItemDefinition)

## Setup

### 1. Enable the plugin

Project → Project Settings → Plugins → Enable "Renegade Customizer"

### 2. Add visual data to your item Resources

Extend your existing `GearDefinition` with visual fields:

```gdscript
# In gear_definition.gd, add:
@export_group("Visuals")
@export var equipment_mesh: Mesh              ## For body group swap slots
@export var equipment_scene: PackedScene      ## For bone attachment slots
@export var mount_offset: Transform3D = Transform3D.IDENTITY
```

### 3. Prepare your character model (Blender)

Split the character into body group meshes sharing one armature:
- `slot_head`, `slot_torso`, `slot_arms`, `slot_legs`, `slot_feet`

Add BoneAttachment3D mount points for accessories:
- `acc_head/mount`, `weapon_r/mount`, `acc_hip/mount`, `acc_back/mount`

Export all together as `.glb`. All equipment meshes must use the same armature.

### 4. Wire up in your game scene

```gdscript
func _ready() -> void:
    var customizer := $CharacterCustomizer  # or instantiate
    customizer.connect_to_equipment_manager($Player/EquipmentManager)
    customizer.connect_to_inventory($Player/Inventory)
```

### 5. Configure slot definitions

Create `EquipmentSlotVisualConfig` resources for each slot and assign them to the
`CustomizerScreen.slot_definitions` array.

## Architecture

```
addons/renegade_customizer/
├── plugin.cfg / plugin.gd         — Plugin registration
├── core/
│   ├── character_customizer.gd    — Main controller (open/close, input action)
│   └── equipment_visual_manager.gd — Mesh swap + bone attachment logic
├── ui/
│   ├── customizer_screen.gd/.tscn — Full overlay (turntable + slots + inventory)
│   ├── turntable_preview.gd/.tscn — SubViewport with CassettePunk lighting
│   ├── equipment_slot_ui.gd/.tscn — Drag target with validation + rarity borders
│   └── stat_comparison_panel.gd/.tscn — Hover tooltip with delta stats
└── resources/
    └── equipment_slot_visual_config.gd — Slot → skeleton node mapping
```

## Key Design Decisions

- **Body groups over blend shapes** — mesh swapping is dramatically more VRAM-efficient
- **SubViewportContainer over TextureRect** — built-in input forwarding, no alpha bugs
- **own_world_3d = true** — isolates preview from game world
- **Signal-based cross-plugin** — no autoloads, game scene wires connections
- **AGX tonemapping** — handles warm CassettePunk material range
- **TwoBoneIK3D ready** — weapon grip posing via Godot 4.6 IK (add IK nodes to skeleton)

## Godot 4.6 Features Used

- SubViewport + SubViewportContainer (turntable)
- BoneAttachment3D (accessories)
- TwoBoneIK3D support (weapon grip — add to skeleton)
- AGX tonemapping (CassettePunk lighting)
- SSR overhaul (reflective gear)
- Unique node IDs (scene robustness)
- Control drag-and-drop API (inventory ↔ equipment)

## Rarity Colors (CassettePunk)

| Rarity    | Color          | Hex       |
|-----------|----------------|-----------|
| Common    | Beige          | `#D4C5A9` |
| Uncommon  | Miami Vice Teal| `#2EC4B6` |
| Rare      | Hot Pink       | `#FF3366` |
| Epic      | Chrome Silver  | `#C0C0C0` |
| Legendary | Gold Foil      | `#FFD700` |
