# RenegadeController — Dependency Graph

## Class Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INHERITANCE TREE                                │
└─────────────────────────────────────────────────────────────────────────────┘

Resource
├── CameraPreset
├── CameraModifier (@abstract)
│   ├── ShakeModifier
│   ├── ZoomModifier
│   └── FramingModifier
├── ItemDefinition
│   ├── WeaponDefinition
│   ├── GearDefinition
│   └── ConsumableDefinition
├── LootTable
└── LootEntry

Node
├── ControllerInterface
│   ├── PlayerController
│   └── AIController
└── CameraModifierStack

Node3D
├── CameraRig
├── CameraSystem
├── Cursor3D
├── ItemSlots
└── WorldPickup

Marker3D
└── DefaultCameraMarker

Area3D
├── CameraZone
│   └── FirstPersonZone (EMPTY - DELETE)
└── CameraZoneManager

CharacterBody3D
└── RenegadeCharacter

Control/UI
├── InventoryGridUI (GridContainer)
├── InventorySlotUI (PanelContainer)
├── ItemInfoPanel (PanelContainer)
└── WeaponWheel (Control)
```

---

## Cross-Reference Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           RUNTIME DEPENDENCIES                               │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐         ┌──────────────────┐
│ RenegadeCharacter│◄────────│ControllerInterface│
│                  │ @export │ (PlayerController │
│  - controller    │─────────│  or AIController) │
│  - camera_rig    │         └──────────────────┘
└────────┬─────────┘                  │
         │                            │
         │ @export                    │ @export
         ▼                            ▼
┌──────────────────┐         ┌──────────────────┐
│    CameraRig     │◄────────│ PlayerController │
│                  │ @export │                  │
│  - target ───────┼─────────┤  - cursor ───────┼───► Cursor3D
│  - default_preset│         └──────────────────┘
│  - player_ctrl   │
└────────┬─────────┘
         │
         │ parent lookup (BAD)
         ▼
┌──────────────────┐
│   CameraSystem   │
│                  │
│  - camera_rig ───┼───► CameraRig
│  - third_person_ │
│    camera ───────┼───► DefaultCameraMarker
│  - first_person_ │
│    camera ───────┼───► Marker3D
└──────────────────┘


┌──────────────────┐  signals  ┌──────────────────┐
│   CameraZone     │──────────►│CameraZoneManager │
│                  │           │                  │
│  zone_entered ───┼───────────┤  - camera_rig ───┼───► CameraRig
│  zone_exited  ───┼───────────┤                  │
│                  │           └──────────────────┘
│  - camera_preset │
│  - camera_marker │───► Marker3D
│  - look_at_marker│───► Marker3D
└──────────────────┘


┌──────────────────┐         ┌──────────────────┐
│    Cursor3D      │         │     Inventory    │
│                  │         │                  │
│  - camera ───────┼──► Camera3D  - items[]    │
│  - aim_line_origin──► Node3D    - max_slots  │
│                  │         └────────┬─────────┘
│  look_at_target ─┼──► Marker3D      │
└──────────────────┘                  │ @export
                                      ▼
                             ┌──────────────────┐
                             │  InventorySlot   │
                             │                  │
                             │  - item ─────────┼───► ItemDefinition
                             │  - quantity      │
                             └──────────────────┘
```

---

## Signal Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SIGNAL CONNECTIONS                              │
└─────────────────────────────────────────────────────────────────────────────┘

Cursor3D
├── interactable_clicked(target) ──────► PlayerController.interact_requested
├── ground_clicked(position) ──────────► PlayerController.move_to_requested
├── interactable_hovered(target) ──────► (unused - available for game code)
└── interactable_unhovered(target) ────► (unused - available for game code)

PlayerController
├── interact_requested(target) ────────► RenegadeCharacter (via setter)
└── move_to_requested(position) ───────► RenegadeCharacter (via setter)

CameraZone
├── zone_entered(zone) ────────────────► CameraZoneManager._on_zone_entered
└── zone_exited(zone) ─────────────────► CameraZoneManager._on_zone_exited

CameraRig
├── preset_changed(preset) ────────────► (available for game code)
└── first_person_changed(enabled) ─────► (available for game code)

Inventory
├── item_added(slot_index, item) ──────► (available for game code)
├── item_removed(slot_index, item) ────► (available for game code)
└── item_changed(slot_index) ──────────► InventoryGridUI, ItemSlots

WeaponManager
├── weapon_equipped(weapon) ───────────► (available for game code)
└── weapon_unequipped(weapon) ─────────► (available for game code)

EquipmentManager
├── gear_equipped(slot, gear) ─────────► (available for game code)
└── gear_unequipped(slot, gear) ───────► (available for game code)
```

---

## Group Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                               GROUP USAGE                                    │
└─────────────────────────────────────────────────────────────────────────────┘

"player" group
├── Used by: CameraZone._on_body_entered/exited
├── Used by: CameraZone.get_look_at_node()
├── Used by: CameraZoneManager (collision detection)
└── Must contain: Player's RenegadeCharacter node

"interactable" group
├── Used by: Cursor3D._is_interactable()
├── Used by: Cursor3D._apply_sticky() (screen-space search)
├── Expects methods: on_cursor_enter(), on_cursor_exit() (optional)
└── Must contain: Any object the cursor can interact with

"camera_zones" group
├── Used by: CameraZoneManager._find_zones() (auto-discovery)
├── Auto-added by: CameraZone._ready()
└── Must contain: All CameraZone instances in level
```

---

## Resource Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            RESOURCE REFERENCES                               │
└─────────────────────────────────────────────────────────────────────────────┘

CameraPreset (.tres)
├── Referenced by: CameraRig.default_preset
├── Referenced by: CameraZone.camera_preset
├── Referenced by: CameraZoneManager (via zones)
└── Files:
    ├── presets/third_person.tres
    ├── presets/side_scroller.tres
    ├── presets/top_down.tres
    └── presets/first_person.tres

CameraModifier (.tres)
├── Referenced by: CameraModifierStack.modifiers[]
└── Files:
    ├── presets/modifiers/default_shake.tres
    ├── presets/modifiers/default_zoom.tres
    └── presets/modifiers/default_framing.tres

ItemDefinition (.tres)
├── Referenced by: Inventory.items[]
├── Referenced by: InventorySlot.item
├── Referenced by: LootEntry.item
├── Referenced by: WorldPickup.item
└── Files:
    ├── presets/items/pistol.tres (WeaponDefinition)
    ├── presets/items/shotgun.tres (WeaponDefinition)
    ├── presets/items/medkit.tres (ConsumableDefinition)
    ├── presets/items/kevlar_vest.tres (GearDefinition)
    └── presets/items/security_keycard.tres (ItemDefinition)

LootTable (.tres)
├── Referenced by: LootDropper.loot_table
└── Contains: LootEntry[] → ItemDefinition references
```

---

## Scene Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             SCENE COMPOSITION                                │
└─────────────────────────────────────────────────────────────────────────────┘

presets/player.tscn
├── RenegadeCharacter (root)
│   ├── CollisionShape3D
│   ├── Mesh (placeholder)
│   └── PlayerController

presets/npc.tscn
├── RenegadeCharacter (root)
│   ├── CollisionShape3D
│   ├── Mesh (placeholder)
│   └── AIController

presets/camera_system.tscn
├── CameraSystem (root)
│   ├── CameraRig
│   │   └── Pivot/SpringArm3D/CameraModifierStack/Camera3D
│   ├── ThirdPersonCamera (DefaultCameraMarker)
│   └── FirstPersonCamera (Marker3D)

presets/world_pickup.tscn
├── WorldPickup (root)
│   ├── CollisionShape3D
│   └── MeshInstance3D

Zone prefab scenes:
├── presets/third_person_zone.tscn
├── presets/side_scroller_zone.tscn
├── presets/top_down_zone.tscn
└── presets/first_person_zone.tscn
```

---

## Editor Tool Dependencies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EDITOR-ONLY DEPENDENCIES                           │
└─────────────────────────────────────────────────────────────────────────────┘

plugin.gd (EditorPlugin)
├── Registers custom types:
│   ├── CameraRig
│   ├── CameraPreset
│   ├── CameraZone
│   ├── CameraZoneManager
│   ├── Cursor3D
│   ├── RenegadeCharacter
│   ├── ControllerInterface
│   ├── PlayerController
│   ├── AIController
│   └── (all inventory types)
├── Adds inspector plugins:
│   ├── CameraZoneInspector
│   └── DefaultCameraInspector
└── Tracks selection for gizmo updates

CameraZoneInspector
├── References: CameraZone (for preview buttons)
└── References: CameraRig (for preview camera control)

DefaultCameraInspector
├── References: DefaultCameraMarker
└── References: CameraRig (for preview)

@tool scripts (run in editor):
├── CameraZone - draws gizmos, updates on selection
├── DefaultCameraMarker - draws gizmos, updates on selection
└── CameraPreset - (minimal editor support)
```

---

## Coupling Hotspots

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PROBLEMATIC COUPLING                                 │
└─────────────────────────────────────────────────────────────────────────────┘

1. CameraRig → CameraSystem (parent lookup)
   Location: camera_rig.gd:299-309
   Problem: Violates dependency inversion
   Fix: Inject via @export setter

2. CameraRig → DefaultCameraMarker (type check)
   Location: camera_rig.gd:336, 561, 717
   Problem: Tight coupling to specific marker type
   Fix: Use interface/duck typing or extract method

3. Cursor3D → get_tree().get_nodes_in_group() every frame
   Location: cursor_3d.gd:230
   Problem: Performance, global state access
   Fix: Cache with invalidation

4. CameraZone & DefaultCameraMarker → ImmediateMesh (duplicate code)
   Location: Both files, ~300 lines each
   Problem: Code duplication
   Fix: Extract to shared utility
```

---

## Module Boundaries

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LOGICAL MODULE GROUPINGS                             │
└─────────────────────────────────────────────────────────────────────────────┘

CAMERA MODULE
├── camera_rig.gd        # Core camera logic
├── camera_preset.gd     # Camera configuration resource
├── camera_system.gd     # Scene-level camera setup
├── default_camera_marker.gd  # Marker with gizmo
└── modifiers/           # Effect modifiers
    ├── camera_modifier.gd
    ├── camera_modifier_stack.gd
    ├── shake_modifier.gd
    ├── zoom_modifier.gd
    └── framing_modifier.gd

CONTROLLER MODULE
├── controller_interface.gd  # Abstract base
├── player_controller.gd     # Human input
└── ai_controller.gd         # AI input

ZONE MODULE
├── camera_zone.gd           # Trigger volume
├── camera_zone_manager.gd   # Zone resolution
└── first_person_zone.gd     # (DELETE - empty subclass)

CHARACTER MODULE
└── character_body.gd        # Unified movement

CURSOR MODULE
└── cursor_3d.gd             # 3D mouse cursor

INVENTORY MODULE
├── inventory.gd             # Container
├── inventory_slot.gd        # Single slot
├── item_definition.gd       # Base item
├── weapon_definition.gd     # Weapon stats
├── gear_definition.gd       # Armor stats
├── consumable_definition.gd # Use effects
├── weapon_manager.gd        # Equipped weapons
├── equipment_manager.gd     # Equipped gear
├── weapon_wheel.gd          # Selection UI
├── item_slots.gd            # Visual attachment
├── world_pickup.gd          # World item
├── loot_table.gd            # Drop tables
├── loot_entry.gd            # (MERGE into loot_table)
└── loot_dropper.gd          # Drop spawner

INVENTORY UI MODULE
├── inventory_grid_ui.gd     # Grid display
├── inventory_slot_ui.gd     # Slot widget
└── item_info_panel.gd       # Tooltip

EDITOR MODULE
├── plugin.gd                # Plugin registration
├── camera_zone_inspector.gd # Zone inspector
└── default_camera_inspector.gd  # Marker inspector

DEMO MODULE
├── demo_scene.gd            # Demo wiring
├── demo_interactable.gd     # Test objects
├── debug_overlay.gd         # F3 HUD
├── npc_patrol.gd            # AI demo
└── input_setup.gd           # Input action setup
```
