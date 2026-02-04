# Pixel Upscale Plugin

Pixel-perfect upscaling for low-resolution 3D rendering in Godot 4.x.

Based on [t3ssel8r's technique](https://youtu.be/d6tp43wZqps), adapted to Godot by [denovodavid](https://git.sr.ht/~denovodavid/3d-pixel-art-in-godot).

## Features

- Crisp pixel art scaling without shimmer or aliasing
- Smooth subpixel camera movement
- Adjustable sharpness
- Works with GL Compatibility renderer
- Easy drop-in scene

## How It Works

The shader uses an adaptive box filter that:
1. Detects when a pixel spans multiple texels
2. Applies smooth interpolation only at texel boundaries
3. Keeps pixels sharp everywhere else

This gives you the best of both worlds: crisp pixels with smooth camera movement.

## Quick Start

1. Instance `presets/pixel_upscale_display.tscn` as your scene root
2. Add your game content as children of the `SubViewport` node
3. Set `internal_width` and `internal_height` to your desired render resolution

## PixelUpscaleDisplay Properties

| Property | Description |
|----------|-------------|
| `internal_width` | Render width in pixels (e.g., 480 for 480p). Set to 0 to disable. |
| `internal_height` | Render height in pixels (e.g., 270 for 270p). Set to 0 to disable. |
| `sharpness` | Filter sharpness (1.0 = crisp, 0.0 = bilinear). |
| `effect_enabled` | Toggle the upscale effect. |
| `enable_3d` | Enable 3D rendering in the SubViewport. |
| `transparent_bg` | Enable transparent background. |
| `msaa` | Anti-aliasing level (Disabled, 2x, 4x, 8x). |

## Typical Setup

```
PixelUpscaleDisplay (this node)
└── SubViewport
    ├── Camera3D
    ├── DirectionalLight3D
    ├── Player
    └── Level
```

Your entire game scene goes inside the SubViewport. The PixelUpscaleDisplay handles rendering it at low resolution and scaling it up with the pixel-perfect shader.

## Resolution Examples

| Internal Res | Aspect | Style |
|-------------|--------|-------|
| 320 x 180 | 16:9 | Very chunky pixels |
| 480 x 270 | 16:9 | PS1/Saturn style |
| 640 x 360 | 16:9 | Balanced |
| 960 x 540 | 16:9 | Subtle pixelation |

## Combining with Dither Shader

For a full retro look, add the DitherOverlay inside the SubViewport:

```
PixelUpscaleDisplay
└── SubViewport
    ├── DitherOverlay (dither effect)
    ├── Camera3D
    └── ... your scene
```

This applies dithering at the low internal resolution, then upscales it crisply.

## License

Based on code by t3ssel8r (MIT) and denovodavid.
