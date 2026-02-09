# Dithering Plugin

Advanced surface-stable dithering post-processing for Godot 4.x.

An evolution of the original Dither Shader plugin, rebuilt with multiple dithering algorithms, perceptual color matching (Oklab), and comprehensive control over every aspect of the effect.

## What's New vs. Original Plugin

| Feature | Original (dither_shader) | New (dithering) |
|---------|--------------------------|-----------------|
| Algorithms | Texture-based ordered only | 5 algorithms (Texture Ordered, Procedural Bayer, Error Diffusion Approx, White Noise, IGN) |
| Color Matching | Luminance-only palette | Luminance + Multi-color perceptual (Oklab, Weighted RGB) |
| Procedural | Requires texture for all modes | Procedural Bayer generates matrix in shader - no texture needed |
| Color Space | sRGB only | Optional linear RGB processing for accuracy |
| Shared Code | Duplicated between shaders | Shared `.gdshaderinc` function library |
| Error Diffusion | Not supported | Blue noise approximation of error diffusion |
| IGN | Not supported | Jimenez 2014 Interleaved Gradient Noise |

## Algorithms

### 0: Texture-Based Ordered Dithering
Classic approach. Compares luminance against a tiled threshold texture (Bayer matrix or blue noise). The bread-and-butter for Obra Dinn-style effects. Use Bayer patterns for world-space (surface-stable), blue noise for screen-space (film grain).

### 1: Procedural Bayer
Generates the Bayer threshold matrix entirely in the shader using the recursive formula — no texture required. Supports 2×2 through 16×16 matrices. Useful when you want zero texture dependencies or want to experiment with Bayer sizes dynamically.

### 2: Blue Noise Error Diffusion Approximation
Uses a blue noise texture with modified threshold logic to approximate error-diffusion dithering (Floyd-Steinberg, Atkinson, etc.) on the GPU. True error diffusion is sequential and can't run in a fragment shader, but this achieves visually similar results — organic clustering without the structured grid of Bayer, and without the ugly clumping of white noise.

### 3: White Noise
Random threshold per pixel. Produces the characteristic "TV static" look. Included for completeness and artistic use — it's the lowest quality dithering algorithm but sometimes that's exactly what you want.

### 4: Interleaved Gradient Noise (Jimenez 2014)
A noise function designed specifically for real-time rendering by Jorge Jimenez for Call of Duty: Advanced Warfare. Better temporal stability than white noise, no texture needed, and produces organic-looking results. Good middle ground between procedural Bayer (too structured) and white noise (too random).

## Palette Modes

### Luminance Mode (Default)
Converts the scene to luminance, maps through a 1D palette texture (dark on left, bright on right). This is the classic Obra Dinn approach — efficient and clean.

### Multi-Color Mode
Instead of going through luminance, finds the two nearest palette colors to each pixel's actual RGB value and dithers between them. Uses perceptual color distance (Oklab by default) for accurate matching. This enables dithering with arbitrary multi-color palettes where luminance ordering doesn't capture the full picture.

## Color Distance Metrics

| Mode | Speed | Quality | Description |
|------|-------|---------|-------------|
| RGB | Fastest | Lowest | Euclidean distance in sRGB space |
| Weighted RGB | Fast | Medium | Redmean approximation — weights channels by perceptual importance |
| Oklab | Medium | Best | Full perceptual color space conversion (Björn Ottosson 2020) |

## Installation

1. Copy the `addons/dithering` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings → Plugins
3. Add a `DitheringOverlay` node to your scene

## Quick Start

**Option A: Use the preset scene**
1. Instance `addons/dithering/presets/dithering_overlay.tscn` into your scene
2. Configure in the inspector

**Option B: Create from scratch**
1. Add a `DitheringOverlay` node to your scene
2. Enable world-space and/or screen-space mode
3. Select an algorithm and palette
4. Adjust parameters

## Surface-Stable (World-Space) Dithering

The world-space mode projects the dither pattern onto 3D geometry using the depth buffer and triplanar mapping. The pattern "sticks" to surfaces — when the camera moves, the dither dots don't crawl or swim. This is the technique used in Return of the Obra Dinn.

**Projection Modes:**
- **XZ Floors** — Projects onto horizontal surfaces
- **XY Z-Walls** — Projects onto Z-facing walls
- **YZ X-Walls** — Projects onto X-facing walls
- **Auto Hard** — Picks dominant axis per pixel (may seam)
- **Triplanar Blend** — Smooth blend across all 3 axes (best quality, default)

**Key Parameters:**
- `world_scale` — Size of the pattern in world units (larger = bigger dots)
- `triplanar_sharpness` — How sharply projection blends between axes
- `moire_reduction` — Blurs pattern at small scales to reduce moiré
- `edge_softness` — Soft dither transitions instead of hard step

## Masking

Both screen-space and world-space modes support masking to control where the dither effect is applied:

- **Shadow Mask** — Only apply dither to dark areas
- **Highlight Mask** — Only apply dither to bright areas
- **Edge Mask** (world-space only) — Apply to depth/normal edges
- **Depth Mask** (world-space only) — Fade effect by camera distance

## Debug Modes (World-Space)

| Mode | Shows |
|------|-------|
| Depth | Linearized depth buffer |
| World Pos | Reconstructed world position (RGB) |
| Normal | Surface normals |
| Screen UV | Screen-space UV coordinates |
| Passthrough | Original scene without dithering |
| Dither UV | Dither texture UV coordinates |
| Threshold | Raw threshold values from algorithm |
| Luminance | Computed luminance values |
| Checker | Procedural checker pattern (tests projection) |
| Triplanar Weights | R=X, G=Y, B=Z axis weights |
| Mask | Current mask values |
| Algorithm Output | Raw output of the selected algorithm |

## Creating Custom Palettes

1. Create a horizontal gradient image (any size, 1px tall is fine)
2. Place colors from dark (left) to light (right)
3. Import with Filter: Nearest, no compression
4. Set palette preset to CUSTOM and assign your texture

For multi-color mode, the palette colors don't need to be luminance-ordered — the perceptual distance metric handles arbitrary color arrangements.

## Architecture

```
addons/dithering/
├── plugin.cfg / plugin.gd          # Plugin registration
├── src/
│   ├── dither_functions.gdshaderinc # Shared algorithm library (Oklab, Bayer, blend modes, etc.)
│   ├── dither_screen.gdshader       # Screen-space canvas_item shader
│   ├── dither_world.gdshader        # World-space spatial shader (depth buffer access)
│   ├── dithering_overlay.gd         # Main control node (DitheringOverlay)
│   ├── world_label.gd              # Crisp 2D text above dither
│   └── world_label_manager.gd      # Label container
├── assets/
│   ├── patterns/                    # Bayer matrices + blue noise textures
│   └── palettes/                    # Color palette textures
├── presets/                         # Ready-to-use scene presets
└── demo/                            # Demo scene
```

The `.gdshaderinc` file contains all shared functions — Oklab conversions, procedural Bayer generation, color distance metrics, palette matching, blend modes, and depth reconstruction utilities. Both shaders `#include` this file, eliminating code duplication.

## References

- [Surma "Ditherpunk"](https://surma.dev/things/ditherpunk/) — Comprehensive survey of dithering algorithms
- [Lucas Pope TIGSource Devlog](https://forums.tigsource.com/index.php?topic=40832.msg1363742) — Obra Dinn surface-stable dithering
- [Rune Skovbo Johansen "Dither3D"](https://runevision.com/tech/dither3d/) — Surface-stable fractal dithering
- [tufourn Dither3D-Godot](https://github.com/tufourn/Dither3D-Godot) — Godot port of Dither3D
- [Björn Ottosson "Oklab"](https://bottosson.github.io/posts/oklab/) — Perceptual color space
- [Moments in Graphics](http://momentsingraphics.de/BlueNoise.html) — Free blue noise textures
- [Sam Bigos godot_dither_shader](https://github.com/samuelbigos/godot_dither_shader) — Original Godot dither shader

## License

MIT License — See LICENSE file for details.
