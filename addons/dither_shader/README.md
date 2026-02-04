# Dither Shader Plugin

An Obra Dinn-style dither post-processing effect for Godot 4.x.

Based on [godot_dither_shader](https://github.com/samuelbigos/godot_dither_shader) by Sam Bigos (MIT license).

## Features

- Customizable color palettes (any number of colors)
- Multiple dither patterns (Bayer matrices, blue noise)
- Adjustable bit depth, contrast, offset, and pixel size
- Easy to use as a CanvasLayer overlay
- Works with both 2D and 3D scenes

## Installation

1. Copy the `addons/dither_shader` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings → Plugins
3. Add a `DitherOverlay` node to your scene

## Quick Start

**Option A: Use the preset scene (recommended)**
1. Instance `addons/dither_shader/presets/dither_overlay.tscn` into your scene
2. Adjust parameters in the inspector

**Option B: Create from scratch**
1. Add a `DitherOverlay` node as a child of your main scene
2. Assign a dither pattern texture (from `assets/patterns/`)
3. Assign a color palette texture (from `assets/palettes/`)
4. Adjust parameters as needed

## DitherOverlay Properties

### Presets
| Property | Description |
|----------|-------------|
| `pattern_preset` | Quick-select dither pattern (Bayer 2x2 to 16x16, Blue Noise, Custom) |
| `palette_preset` | Quick-select color palette (Mono, Moonlight, Eevee, Hollow, Rising Sun, Custom) |

### Custom Textures
| Property | Description |
|----------|-------------|
| `dither_pattern` | Custom dither pattern texture (set preset to CUSTOM to use) |
| `color_palette` | Custom color palette texture (set preset to CUSTOM to use) |

### Effect Parameters
| Property | Description |
|----------|-------------|
| `bit_depth` | Luminance banding (2-64). Lower = more distinct bands. |
| `contrast` | Luminance scale (0.0-5.0). Higher = more contrast. |
| `lum_offset` | Luminance shift (-1.0 to 1.0). Positive = brighter. |
| `dither_size` | Pixel size (1-8). Higher = more pixelated. |
| `color_mix` | Mix between original scene (0.0) and dither effect (1.0). |
| `blend_mode` | How dither blends with scene (Normal, Add, Subtract, Multiply, Screen, Overlay, Soft Light, Hard Light, Color Dodge, Color Burn, Difference). |
| `effect_enabled` | Toggle the effect on/off at runtime. |

## Included Assets

### Dither Patterns (`assets/patterns/`)
- `bayer16tile2.png` - 16x16 Bayer matrix (smoothest)
- `bayer8tile4.png` - 8x8 Bayer matrix
- `bayer4tile8.png` - 4x4 Bayer matrix
- `bayer2tile16.png` - 2x2 Bayer matrix (most blocky)
- `blue_noise.png` - Blue noise (organic look)

### Color Palettes (`assets/palettes/`)
- `palette_mono.png` - Black and white
- `palette_moonlight.png` - Cool blue tones
- `palette_eeve.png` - Warm brown/sepia
- `palette_hollow.png` - Purple/blue fantasy
- `palette_rising_sun.png` - Warm sunset colors

## Creating Custom Palettes

1. Create a horizontal gradient image (any size)
2. Place colors from dark (left) to light (right)
3. Import with filtering disabled
4. Assign to `color_palette`

Example: A 4-color palette would be 4 pixels wide by 1 pixel tall.

## Creating Custom Dither Patterns

1. Create a square grayscale image (power of 2: 2x2, 4x4, 8x8, 16x16)
2. Fill with values representing the dither threshold pattern
3. Import with:
   - Repeat: Enabled
   - Filter: Nearest (disabled)
4. Assign to `dither_pattern`

## WorldLabel - Crisp Text Above Dither

Use `WorldLabel` nodes to display crisp 2D text that tracks 3D positions without being affected by the dither effect. This is useful for floating labels, item names, or any text that should remain readable.

### Usage

1. Add a `WorldLabel` node as a child of any 3D object
2. Set the `text` property to your desired label
3. The label will automatically render as crisp 2D text above the dither effect

### WorldLabel Properties

| Property | Description |
|----------|-------------|
| `text` | The text to display |
| `font_size` | Font size in pixels (8-128) |
| `color` | Text color |
| `outline_color` | Outline color for readability |
| `outline_size` | Outline thickness in pixels (0-16) |
| `pixel_offset` | Offset from 3D position in screen pixels |
| `max_distance` | Distance at which label fully fades out (0 = no fade) |
| `fade_start_distance` | Distance at which label starts fading |
| `label_visible` | Toggle label visibility |

### How It Works

WorldLabel creates a 2D `Label` on a high-layer `CanvasLayer` that renders above the dither effect. Each frame, it projects the 3D world position to screen coordinates. Works automatically with SubViewport setups (handles scaling).

## Demo Scene

Run `demo/dither_demo.tscn` to see the effect in action.

Controls:
- `1-5`: Switch palette
- `Q-T`: Switch dither pattern
- `Up/Down`: Adjust contrast
- `Left/Right`: Adjust offset
- `+/-`: Adjust dither size
- `Space`: Toggle effect

## License

MIT License - See LICENSE file for details.

Original shader by Sam Bigos.
Bayer matrix textures by [tromero](https://github.com/tromero/BayerMatrix) (MIT).
Blue noise from [Moments in Graphics](http://momentsingraphics.de/BlueNoise.html).
