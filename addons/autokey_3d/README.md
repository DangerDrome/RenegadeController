# AutoKey 3D

A Godot 4.6 editor plugin that adds **auto-keyframing** for 3D animations, similar to Unreal Engine's Sequencer auto-key feature.

## Features

- **Auto-Key Toggle**: A button in the Animation panel toolbar - when enabled (turns red), changes to any tracked property automatically insert keyframes at the playhead position
- **Manual Insert Buttons**: Quickly insert Position, Rotation, Scale, or All keys for selected Node3D objects via the dock
- **Auto-Create Tracks**: Optionally create missing animation tracks automatically
- **Visual Feedback**: Shows confirmation when keys are inserted

## Installation

1. Copy the `addons/autokey_3d` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings -> Plugins -> AutoKey 3D

## Usage

### Auto-Key (Main Feature)

1. Open the Animation panel (bottom panel) and select an animation
2. Look for the Auto-Key button in the Animation panel toolbar (key icon)
3. Click to enable auto-key (button turns red)
4. Now when you move/rotate/scale any object with tracks in the animation, keys are automatically inserted at the current playhead position

### Manual Key Insertion

1. Select Node3D object(s) in the scene
2. Position the playhead at the desired time
3. Use the AutoKey 3D dock (right panel) to click Position/Rotation/Scale/All buttons

## How It Works

When auto-key is enabled:
- The plugin polls every 50ms to detect property changes on all tracks
- When any tracked property's value changes, a keyframe is inserted at the current playhead position
- Works with gizmo manipulation, inspector edits, and any other property changes

## Supported Track Types

- Position 3D tracks
- Rotation 3D tracks
- Scale 3D tracks
- Value tracks (any property)
- Bezier tracks
- Blend shape tracks

## Known Limitations

- The auto-key button is injected into Godot's internal editor UI - this may need updates for future Godot versions
- Auto-key state is cleared when switching animations

## Developer Notes: Finding the Animation Panel Toolbars

For future reference, here's how to locate the Animation panel's bottom toolbar programmatically:

### Bottom Toolbar (Timeline Controls)
- **Class**: `HFlowContainer` (NOT HBoxContainer!)
- **Location**: Sibling of `AnimationTrackEditor`, found by searching the parent of AnimationTrackEditor
- **Contains**: Bezier mode toggle, filter/sort buttons, "Insert at current time" button, snap controls, FPS settings, time input, zoom slider
- **How to find**:
```gdscript
var track_editor := _find_node_by_class(get_editor_interface().get_base_control(), "AnimationTrackEditor")
var parent := track_editor.get_parent()
# Search parent for HFlowContainer
_find_all_by_class(parent, "HFlowContainer", results)
# The first HFlowContainer is the bottom toolbar
```

### Top Toolbar (AnimationPlayerEditor)
- **Class**: `HBoxContainer`
- **Location**: Direct child of the VBoxContainer parent of AnimationTrackEditor
- **Contains**: Animation dropdown, Autoplay button, Animation properties, Onion skinning, Pin button
- **Identifying feature**: Has 7+ buttons and 1 OptionButton (animation selector)

### Key Button Tooltips in Bottom Toolbar
| Index | Tooltip |
|-------|---------|
| 4 | "Bezier Default Mode..." |
| 6 | "Toggle between the bezier curve editor and track editor." |
| 7 | "Toggle function names in the track editor." |
| 8 | "Only show tracks from nodes selected in tree." |
| 11 | "Insert at current time." |
| 13-15 | Snap controls |

## License

MIT License - use freely in your projects.
