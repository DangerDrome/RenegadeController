# RenegadeController — Plugin Integration Map

**Updated:** 2026-02-05

This document describes how the 8 plugins in this repository connect and depend on each other.

---

## Plugin Overview

| Plugin | Type | Dependencies | Autoloads |
|--------|------|--------------|-----------|
| **renegade_controller** | Core gameplay | None | None |
| **modular_hud** | UI system | sky_weather (soft) | HUDEvents |
| **sky_weather** | Environment | HUDEvents (soft), NPCBrainHooks (soft) | None |
| **universal_door** | Level mechanics | None | None |
| **dither_shader** | Visual effect | None | None |
| **pixel_outline** | Visual effect | None | None |
| **pixel_upscale** | Visual effect | None | None |
| **material_icons_importer** | Editor tool | None | None |

---

## Dependency Diagram

```
                    ┌─────────────────────────────┐
                    │    material_icons_importer  │
                    │       (Editor Only)         │
                    └─────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         STANDALONE PLUGINS                           │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐       │
│  │renegade_controller│ │ universal_door  │ │ dither_shader   │       │
│  │                 │ │                 │ │                 │       │
│  │ • Character     │ │ • Door types    │ │ • Dither effect │       │
│  │ • Camera        │ │ • Teleporter    │ │ • WorldLabel    │       │
│  │ • Inventory     │ │                 │ │                 │       │
│  │ • Zones         │ └─────────────────┘ └─────────────────┘       │
│  └─────────────────┘                                                │
│  ┌─────────────────┐ ┌─────────────────┐                           │
│  │  pixel_outline  │ │  pixel_upscale  │                           │
│  │                 │ │                 │                           │
│  │ • Outline shader│ │ • Upscale shader│                           │
│  └─────────────────┘ └─────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      INTEGRATED PLUGINS                              │
│                                                                      │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │   modular_hud   │ ──────► │   sky_weather   │                   │
│  │                 │  soft   │                 │                   │
│  │ • HUDEvents     │  dep    │ • Day/night     │                   │
│  │ • HUD components│         │ • Weather       │                   │
│  └────────┬────────┘         └────────┬────────┘                   │
│           │                           │                             │
│           │ provides                  │ optional                    │
│           ▼                           ▼                             │
│  ┌─────────────────┐         ┌─────────────────┐                   │
│  │   HUDEvents     │ ◄────── │  NPCBrainHooks  │                   │
│  │   (Autoload)    │         │  (External)     │                   │
│  └─────────────────┘         └─────────────────┘                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Integration Details

### modular_hud ↔ sky_weather

**Integration Type:** Soft dependency (graceful degradation)

**How It Works:**

1. **Sky HUD components** search for SkyWeather node at runtime:
   ```gdscript
   # In sky_time_display.gd, sky_day_display.gd, etc.
   func _ready() -> void:
       visible = false
       await get_tree().process_frame
       _find_sky_weather()
   
   func _find_sky_weather() -> void:
       _sky_weather = _find_node_by_class(get_tree().root, "SkyWeather")
       if not _sky_weather:
           return  # Stay hidden
       visible = true
       # Connect to signals...
   ```

2. **SkyWeather pushes to HUDEvents** (if available):
   ```gdscript
   # In sky_weather.gd
   func _emit_hud_time() -> void:
       var hud_events := get_node_or_null("/root/HUDEvents")
       if hud_events and hud_events.has_signal("time_changed"):
           hud_events.emit_signal("time_changed", time, get_period())
   ```

**Components Affected:**
- `sky_time_display.gd` — Shows current time
- `sky_day_display.gd` — Shows day count
- `sky_weather_icon.gd` — Shows weather icon
- `sky_speed_display.gd` — Shows time scale
- `time_weather_display.gd` — Composite display

**Behavior When sky_weather Not Present:**
- Sky HUD components remain `visible = false`
- No errors or warnings
- Other HUD components work normally

---

### sky_weather → HUDEvents

**Integration Type:** Optional push (defensive coding)

**How It Works:**
```gdscript
# sky_weather.gd
func _emit_hud_time() -> void:
    var hud_events := get_node_or_null("/root/HUDEvents")
    if hud_events and hud_events.has_signal("time_changed"):
        hud_events.emit_signal("time_changed", time, get_period())

func _emit_hud_weather() -> void:
    var hud_events := get_node_or_null("/root/HUDEvents")
    if hud_events and hud_events.has_signal("weather_changed"):
        hud_events.emit_signal("weather_changed", weather.resource_name if weather else "")
```

**Behavior When HUDEvents Not Present:**
- SkyWeather continues to function normally
- Time/weather changes only emit via SkyWeather's own signals
- No errors

---

### sky_weather → NPCBrainHooks

**Integration Type:** Optional condition registration

**How It Works:**
```gdscript
# sky_weather.gd
func _register_npc_hooks() -> void:
    if Engine.is_editor_hint():
        return
    var hooks := get_node_or_null("/root/NPCBrainHooks")
    if not hooks:
        return
    
    # Register 7 conditions
    hooks.register_condition(&"is_night", _is_night)
    hooks.register_condition(&"is_day", _is_day)
    hooks.register_condition(&"is_dawn", _is_dawn)
    hooks.register_condition(&"is_dusk", _is_dusk)
    hooks.register_condition(&"is_raining", _is_raining)
    hooks.register_condition(&"is_cloudy", _is_cloudy)
    hooks.register_condition(&"is_foggy", _is_foggy)
```

**Behavior When NPCBrainHooks Not Present:**
- SkyWeather continues to function normally
- AI systems can't query time/weather conditions
- No errors

---

## Autoload Registration

### HUDEvents (modular_hud)

**Registered By:** `modular_hud/plugin.gd`
```gdscript
func _enter_tree() -> void:
    add_autoload_singleton("HUDEvents", "res://addons/modular_hud/core/hud_events.gd")
```

**Signals Provided:**
```gdscript
signal damage_taken(amount: float, direction: Vector2)
signal notification_requested(text: String)
signal objective_updated(id: String, progress: float)
signal time_changed(hour: float, period: String)
signal weather_changed(weather_name: String)
```

**Usage Pattern:**
```gdscript
# Emitting (from game code or sky_weather)
HUDEvents.damage_taken.emit(10.0, Vector2.LEFT)

# Listening (from HUD components)
HUDEvents.damage_taken.connect(_on_damage_taken)
```

---

## Visual Effect Stacking

The visual effect plugins can be combined in any order:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      RENDERING PIPELINE                              │
│                                                                      │
│  ┌─────────────────┐                                                │
│  │   Main Scene    │                                                │
│  │   (3D World)    │                                                │
│  └────────┬────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────┐     ┌─────────────────┐                       │
│  │  pixel_outline  │ ──► │  OutlineSetup   │ (dual viewport)       │
│  │                 │     │  creates outline │                       │
│  └────────┬────────┘     └─────────────────┘                       │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────┐     ┌─────────────────┐                       │
│  │  dither_shader  │ ──► │  DitherOverlay  │ (post-process)        │
│  │                 │     │  applies dither  │                       │
│  └────────┬────────┘     └─────────────────┘                       │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────┐     ┌─────────────────┐                       │
│  │  pixel_upscale  │ ──► │PixelUpscaleDisp │ (integer scale)       │
│  │                 │     │  crisp pixels    │                       │
│  └────────┬────────┘     └─────────────────┘                       │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────┐                                                │
│  │   Final Output  │                                                │
│  └─────────────────┘                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Recommended Order:**
1. pixel_outline (renders to separate viewport)
2. dither_shader (post-process on main viewport)
3. pixel_upscale (final upscaling)

---

## Group-Based Communication

Plugins use Godot groups for cross-node communication:

| Group | Plugin | Purpose |
|-------|--------|---------|
| `"player"` | renegade_controller | Zone detection, cursor targeting |
| `"camera_zones"` | renegade_controller | Zone auto-discovery |
| `"interactable"` | renegade_controller | Cursor detection |

**No cross-plugin groups** — plugins are cleanly isolated.

---

## Adding New Plugin Integrations

### To Integrate with sky_weather:

1. **Option A:** Listen directly to SkyWeather signals
   ```gdscript
   var sky := _find_node_by_class(get_tree().root, "SkyWeather")
   if sky:
       sky.time_changed.connect(_on_time_changed)
   ```

2. **Option B:** Listen to HUDEvents (if available)
   ```gdscript
   var hud := get_node_or_null("/root/HUDEvents")
   if hud:
       hud.time_changed.connect(_on_time_changed)
   ```

### To Integrate with renegade_controller:

1. **Add to interactable group:**
   ```gdscript
   func _ready() -> void:
       add_to_group("interactable")
   
   func on_cursor_enter() -> void:
       # Highlight
   
   func on_cursor_exit() -> void:
       # Unhighlight
   
   func on_interact() -> void:
       # Handle interaction
   ```

2. **Access player/camera:**
   ```gdscript
   var players := get_tree().get_nodes_in_group("player")
   if not players.is_empty():
       var player: RenegadeCharacter = players[0]
   ```

---

## Conflict Considerations

### Potential Conflicts:

1. **Multiple post-process effects:** DitherOverlay + other CanvasLayer effects may stack unexpectedly. Test layer ordering.

2. **Viewport resolution:** pixel_outline and pixel_upscale both manage viewports. Ensure only one controls the main viewport size.

3. **Input handling:** renegade_controller captures mouse for Cursor3D. Other plugins should not intercept mouse input without coordination.

### No Known Conflicts:

- All plugins have been tested together in the demo scene
- Signal names are namespaced (no collisions)
- Autoloads use unique names

---

## Quick Reference

### "Can I use X without Y?"

| If I use... | Do I need...? | Answer |
|-------------|---------------|--------|
| renegade_controller | anything else | No — fully standalone |
| modular_hud | sky_weather | No — sky components hide gracefully |
| sky_weather | modular_hud | No — signals still work |
| universal_door | anything | No — fully standalone |
| dither_shader | anything | No — fully standalone |
| pixel_outline | anything | No — fully standalone |
| pixel_upscale | anything | No — fully standalone |

**All plugins are designed to work independently or together.**
