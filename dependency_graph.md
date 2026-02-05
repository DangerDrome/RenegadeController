# Renegade Controller — Dependency Graph

## Plugin-Level Dependencies

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           PLUGIN DEPENDENCIES                            │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│  renegade_controller │  ◄── STANDALONE (no external deps)
│  ──────────────────  │
│  • Character system  │
│  • Camera system     │
│  • Inventory system  │
│  • Zone system       │
└──────────────────────┘

┌──────────────────────┐     ┌──────────────────────┐
│    modular_hud       │────►│     sky_weather      │
│  ──────────────────  │     │  ──────────────────  │
│  • HUDEvents (auto)  │     │  • Day/night cycle   │
│  • HUD components    │     │  • Weather system    │
└──────────────────────┘     └──────────────────────┘
         │                            │
         │ (provides autoload)        │ (optional)
         ▼                            ▼
┌──────────────────────┐     ┌──────────────────────┐
│     HUDEvents        │◄────│    NPCBrainHooks     │
│  (Autoload Singleton)│     │  (External Autoload) │
└──────────────────────┘     └──────────────────────┘

┌──────────────────────┐     ┌──────────────────────┐
│    dither_shader     │     │    pixel_outline     │
│  ──────────────────  │     │  ──────────────────  │
│  • DitherOverlay     │     │  • OutlineSetup      │
│  • WorldLabel        │     │  • OutlineMaterial   │
└──────────────────────┘     └──────────────────────┘
         │                            │
         └────────────┬───────────────┘
                      │ (can be stacked)
                      ▼
┌──────────────────────┐     ┌──────────────────────┐
│    pixel_upscale     │     │   universal_door     │
│  ──────────────────  │     │  ──────────────────  │
│  • PixelUpscale      │     │  • UniversalDoor     │
│    Display           │     │  • DoorFactory       │
└──────────────────────┘     └──────────────────────┘
```

---

## renegade_controller Internal Dependencies

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    RENEGADE_CONTROLLER ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │   CameraSystem      │
                    │  (Root Wrapper)     │
                    └─────────┬───────────┘
                              │ owns
                              ▼
                    ┌─────────────────────┐
                    │    CameraRig        │
                    │  (Main Camera)      │
                    └─────────┬───────────┘
                              │ composes
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
    ┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
    │ CameraCollision │ │ CameraAuto  │ │ CameraIdle      │
    │    Handler      │ │   Framer    │ │   Effects       │
    └─────────────────┘ └─────────────┘ └─────────────────┘

                    ┌─────────────────────┐
                    │  CameraZoneManager  │
                    └─────────┬───────────┘
                              │ discovers
                              ▼
                    ┌─────────────────────┐
                    │    CameraZone       │◄────────────┐
                    │    (Area3D)         │             │
                    └─────────────────────┘             │ extends
                              ▲                        │
                              │ uses                   │
                    ┌─────────────────────┐  ┌─────────┴─────────┐
                    │   CameraPreset      │  │  FirstPersonZone  │
                    │    (Resource)       │  │                   │
                    └─────────────────────┘  └───────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                       CONTROLLER ABSTRACTION                             │
└─────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────┐
                    │ ControllerInterface │◄──── Base class (virtual API)
                    │       (Node)        │
                    └─────────┬───────────┘
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌─────────────────┐             ┌─────────────────┐
    │ PlayerController│             │  AIController   │
    │  (InputMap +    │             │  (AI intents)   │
    │   Cursor3D)     │             │                 │
    └────────┬────────┘             └────────┬────────┘
             │                               │
             │ reads from                    │ reads from
             ▼                               ▼
    ┌─────────────────────────────────────────────────┐
    │              RenegadeCharacter                   │
    │           (CharacterBody3D)                      │
    │  ─────────────────────────────────────────────  │
    │  • Same script for player AND NPC               │
    │  • Reads controller.move_direction              │
    │  • Reads controller.is_aiming                   │
    └─────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                        INVENTORY SYSTEM                                  │
└─────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │ ItemDefinition  │◄──── Base resource
    │   (Resource)    │
    └────────┬────────┘
             │ extends
    ┌────────┼────────┬────────────────┐
    ▼        ▼        ▼                ▼
┌────────┐ ┌────────┐ ┌────────────┐ (KeyItem via
│ Weapon │ │  Gear  │ │ Consumable │  ItemType enum)
│  Def   │ │  Def   │ │    Def     │
└────────┘ └────────┘ └────────────┘

    ┌─────────────────┐
    │    Inventory    │◄──── Container
    │     (Node)      │
    └────────┬────────┘
             │ contains
             ▼
    ┌─────────────────┐
    │  InventorySlot  │◄──── Per-slot data
    │  (RefCounted)   │
    └─────────────────┘

    ┌─────────────────┐      ┌─────────────────┐
    │  WeaponManager  │◄────►│EquipmentManager │
    │    (Node3D)     │      │     (Node)      │
    └─────────────────┘      └─────────────────┘
             │                        │
             │ references             │ references
             ▼                        ▼
    ┌─────────────────┐      ┌─────────────────┐
    │   ItemSlots     │      │  WeaponWheel    │
    │  (Visual mesh   │      │  (Radial UI)    │
    │   attachment)   │      │                 │
    └─────────────────┘      └─────────────────┘

    ┌─────────────────┐
    │   LootTable     │◄──── Weighted random
    │   (Resource)    │
    └────────┬────────┘
             │ contains
             ▼
    ┌─────────────────┐      ┌─────────────────┐
    │   LootEntry     │      │  LootDropper    │
    │   (Resource)    │◄─────│    (Node)       │
    └─────────────────┘      └─────────────────┘
                                     │
                                     │ spawns
                                     ▼
                             ┌─────────────────┐
                             │  WorldPickup    │
                             │   (Area3D)      │
                             └─────────────────┘


┌─────────────────────────────────────────────────────────────────────────┐
│                          CURSOR SYSTEM                                   │
└─────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │    Cursor3D     │
    │    (Node3D)     │
    └────────┬────────┘
             │
             ├── Raycasts from camera through mouse position
             ├── Detects "interactable" group members
             ├── Provides aim_target for strafing
             │
             │ emits signals
             ▼
    ┌─────────────────────────────────────────────┐
    │  interactable_clicked(target: Node3D)       │
    │  ground_clicked(position: Vector3)          │
    │  interactable_hovered(target: Node3D)       │
    │  interactable_unhovered(target: Node3D)     │
    └─────────────────────────────────────────────┘
```

---

## modular_hud + sky_weather Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    HUD ↔ SKY_WEATHER INTEGRATION                         │
└─────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │   SkyWeather    │
    │    (Node3D)     │
    └────────┬────────┘
             │
             ├── Emits: time_changed, period_changed, weather_changed
             │
             ├──────────────────┐
             │                  ▼
             │         ┌─────────────────┐
             │         │   HUDEvents     │◄──── Autoload (optional relay)
             │         │   (Singleton)   │
             │         └────────┬────────┘
             │                  │
             │                  ├── time_changed(hour, period)
             │                  ├── weather_changed(weather_name)
             │                  │
             ▼                  ▼
    ┌─────────────────────────────────────────────┐
    │              HUD COMPONENTS                  │
    │  ───────────────────────────────────────    │
    │                                             │
    │  ┌────────────────┐  ┌────────────────┐    │
    │  │ SkyTimeDisplay │  │ SkyDayDisplay  │    │
    │  └────────────────┘  └────────────────┘    │
    │                                             │
    │  ┌────────────────┐  ┌────────────────┐    │
    │  │SkyWeatherIcon  │  │SkySpeedDisplay │    │
    │  └────────────────┘  └────────────────┘    │
    │                                             │
    │  Discovery: _find_node_by_class("SkyWeather")│
    │  Listens to: SkyWeather signals directly    │
    │                                             │
    └─────────────────────────────────────────────┘

    ┌─────────────────┐
    │  NPCBrainHooks  │◄──── External autoload (optional)
    │   (Singleton)   │
    └────────┬────────┘
             │
             │ SkyWeather registers conditions:
             │   • is_night
             │   • is_day
             │   • is_dawn
             │   • is_dusk
             │   • is_raining
             │   • is_cloudy
             │   • is_foggy
             │
             ▼
    ┌─────────────────────────────────────────────┐
    │           AI DECISION MAKING                 │
    │  (External system can query conditions)      │
    └─────────────────────────────────────────────┘
```

---

## Signal Flow Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SIGNAL CONNECTIONS                               │
└─────────────────────────────────────────────────────────────────────────┘

PlayerController.cursor (setter)
    └── cursor.interactable_clicked → _on_interactable_clicked()
    └── cursor.ground_clicked → _on_ground_clicked()

RenegadeCharacter.controller (setter)
    └── controller.move_to_requested → _on_move_to_requested()
    └── controller.interact_requested → _on_interact_requested()

CameraZoneManager
    └── zone.zone_entered → _on_zone_entered()
    └── zone.zone_exited → _on_zone_exited()

Inventory
    └── slot.slot_changed → _on_slot_changed()

HUD Components
    └── HUDData.changed → _update()
    └── SkyWeather.time_changed → _on_time_changed()
```

---

## Group Membership

| Group | Used By | Purpose |
|-------|---------|---------|
| `"player"` | CameraZone, Cursor3D | Detect player for zone triggers, cursor targeting |
| `"camera_zones"` | CameraZoneManager | Auto-discover zones in scene |
| `"interactable"` | Cursor3D, WorldPickup | Detect interactive objects |

---

## Class Hierarchy

```
Node
├── ControllerInterface
│   ├── PlayerController
│   └── AIController
├── Inventory
├── EquipmentManager
├── CameraZoneManager
├── LootDropper
└── (various managers)

Node3D
├── RenegadeCharacter (CharacterBody3D)
├── CameraSystem
├── CameraRig
├── Cursor3D
├── WeaponManager
├── ItemSlots
├── SkyWeather
├── UniversalDoor
└── WorldLabel

Area3D
├── CameraZone
│   └── FirstPersonZone
└── WorldPickup

Resource
├── CameraPreset
├── HUDData
├── WeatherPreset
├── ItemDefinition
│   ├── WeaponDefinition
│   ├── GearDefinition
│   └── ConsumableDefinition
├── InventorySlot
├── LootTable
└── LootEntry

RefCounted
├── CameraCollisionHandler
├── CameraAutoFramer
└── CameraIdleEffects

Control
├── InventoryGridUI (GridContainer)
├── InventorySlotUI (PanelContainer)
├── ItemInfoPanel (PanelContainer)
├── WeaponWheel
└── (HUD components)

CanvasLayer
├── DitherOverlay
└── PixelUpscaleDisplay

ShaderMaterial
├── OutlineMaterial
└── PixelUpscaleMaterial
```
