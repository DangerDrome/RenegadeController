# Plugin Modularity Guide

This document describes the patterns used to ensure plugins can work independently while still communicating with each other.

## Core Principles

1. **Soft Dependencies**: Plugins should gracefully degrade when optional dependencies are missing
2. **Public APIs**: Cross-plugin communication must use public methods, never private fields
3. **Feature Detection**: Use `has_method()` checks before calling methods on external nodes
4. **Dynamic Discovery**: Find nodes via class names or groups, not hardcoded paths

## Pattern: Soft Dependency with Class Lookup

```gdscript
# Find a node by class name anywhere in the scene tree
func _find_external_system() -> void:
    _external = HUDEvents.find_node_by_class(get_tree().root, "ClassName")
    if not _external:
        # Gracefully degrade - feature disabled but no crash
        return

    # Connect signals if available
    if _external.has_signal("some_signal"):
        _external.some_signal.connect(_on_some_signal)
```

## Pattern: Safe Method Calls

```gdscript
# Always check method existence before calling
if _manager and _manager.has_method("get_realized_npcs"):
    var npcs: Dictionary = _manager.get_realized_npcs()
    for npc_id in npcs:
        # Process NPCs...

# For optional features
if _system and _system.has_method("is_feature_enabled"):
    if _system.is_feature_enabled():
        # Use feature...
```

## Pattern: Public Getters for Internal State

When other plugins need access to internal data, expose public getter methods:

```gdscript
# Private internal state
var _realized_npcs: Dictionary = {}
var _current_zone: CameraZone = null

# Public API for cross-plugin access
func get_realized_npcs() -> Dictionary:
    return _realized_npcs.duplicate()  # Return copy for safety

func get_current_zone() -> CameraZone:
    return _current_zone
```

## Pattern: Configurable Fallback Resources

When a plugin needs resources from another plugin, make the path configurable:

```gdscript
## Optional fallback icon - configure in inspector if default not found
@export var fallback_icon: Texture2D

func _ready() -> void:
    if fallback_icon:
        _icon = fallback_icon
    else:
        # Try known locations
        var paths: Array[String] = [
            "res://addons/chronos/icons/default.png",
            "res://addons/legacy_name/icons/default.png",
        ]
        for path in paths:
            if FileAccess.file_exists(path):
                _icon = load(path)
                break
```

## Plugin Dependencies

### modular_hud
- **Soft depends on**: Chronos (time/weather display), renegade_npc (NPC stats)
- **Uses**: `HUDEvents.find_node_by_class()` for dynamic discovery
- **Degrades gracefully**: Components hide themselves when data unavailable

### renegade_npc
- **Soft depends on**: GameClock, ReputationManager (autoloads)
- **Provides**: `NPCManager.get_realized_npcs()`, `NPCManager.get_stats()`

### chronos
- **Soft depends on**: HUDEvents (for broadcasting time/weather changes)
- **Provides**: `is_session_initialized()`, `is_at_session_start()`, `get_weather_icon()`

### renegade_controller
- **No external dependencies** (core character controller)
- **Provides**: `CameraZoneManager.get_current_zone()`, `CameraZoneManager.get_active_zone_count()`

### renegade_visuals
- **Soft depends on**: renegade_controller (auto-discovers CharacterBody3D parent)
- **Provides**:
  - `CharacterVisuals.get_skeleton()`, `get_animation_tree()`, `get_controller()`
  - `CharacterVisuals.get_skeleton_config()`, `get_mesh_instance()`, `get_character_instance()`
  - `CharacterVisuals.is_ik_ready()`, `get_left_leg_ik()`, `get_right_leg_ik()`, etc.
- **Signals**: `movement_updated`, `hit_received`, `ragdoll_requested`, `ik_setup_complete`
- **Auto-setup**: Creates TwoBoneIK3D at runtime when `auto_setup_ik = true`

## Adding New Cross-Plugin Features

When adding features that communicate between plugins:

1. **Never access private fields** (prefixed with `_`)
2. **Add public getter methods** to the source plugin
3. **Use `has_method()` checks** in the consuming plugin
4. **Make resources configurable** with `@export` properties
5. **Document the dependency** in this file
