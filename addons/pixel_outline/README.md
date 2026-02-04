# Pixel Outline v2 - Automatic Depth + Normal Edge Detection

Pixel-perfect outlines that **work with Compatibility mode** AND have **automatic edge detection** like Forward+ shaders.

## What's New in v2

| Feature | v1 (ID Colors) | v2 (Depth+Normal) |
|---------|----------------|-------------------|
| Edge detection | Manual (ID colors) | Automatic (geometry-based) |
| Material setup | Set ID color per object | Just set albedo |
| Catches all edges | Only where you define | All depth/normal discontinuities |
| Per-object outline colors | ✅ Yes | ❌ Single color |
| Works with Compatibility | ✅ Yes | ✅ Yes |
| Transparent objects | ✅ Yes | ✅ Yes |

## Installation

1. Copy `addons/pixel_outline` to your project
2. **Project → Project Settings → Plugins** → Enable "Pixel Outline v2"

## Quick Start

### Easiest: Auto-Setup

```gdscript
# In your scene
@onready var outline = $OutlineSetup

func _ready():
    outline.source_camera = $Camera3D
    outline.auto_setup_materials = true  # Auto-configure all meshes!
    outline.setup()
```

### Manual Setup

```gdscript
func _ready():
    var outline = $OutlineSetup
    outline.source_camera = $Camera3D
    await outline.setup_completed
    
    # Option A: Use our materials
    var cube = MeshInstance3D.new()
    cube.mesh = BoxMesh.new()
    cube.material_override = OutlineMaterial.standard(Color.RED)
    cube.layers = 1 | 16  # Layers 1 + 5
    add_child(cube)
    
    # Option B: Keep your existing material
    var mesh = $MyExistingMesh
    OutlineMaterial.setup_mesh_keep_material(mesh)
```

## How It Works

**Dual Viewport Technique (Compatibility-safe):**

1. **Main Viewport** (layer 1): Renders scene with your materials
2. **Data Viewport** (layer 5): Renders depth + normals encoded into RGBA
3. **Post-Process**: Samples data texture, finds edges via depth/normal comparison

**Data Encoding:**
- R channel: Depth (clip space Z)
- G, B, A channels: View-space normal (XYZ mapped to 0-1)

## Material Options

### 1. OutlineMaterial.standard() - Recommended
StandardMaterial3D with toon shading + data pass:
```gdscript
mesh.material_override = OutlineMaterial.standard(Color.BLUE)
```

### 2. OutlineMaterial.simple() - Unshaded
Flat color, good for stylized looks:
```gdscript
mesh.material_override = OutlineMaterial.simple(Color.GREEN)
```

### 3. OutlineMaterial.toon() - Custom Shader
Our toon shader with data output:
```gdscript
mesh.material_override = OutlineMaterial.toon(Color.YELLOW)
```

### 4. Keep Your Material
Add data pass to any existing material:
```gdscript
OutlineMaterial.add_data_pass(my_custom_material)
mesh.layers = 1 | 16
```

## Inspector Properties

### Outline Appearance
| Property | Default | Description |
|----------|---------|-------------|
| `outline_color` | Black | Color of outlines |
| `outline_width` | 1.0 | Width in pixels |
| `outline_active` | true | Toggle outlines |

### Edge Detection
| Property | Default | Description |
|----------|---------|-------------|
| `depth_threshold` | 0.008 | Sensitivity for depth edges (lower = more edges) |
| `normal_threshold` | 0.3 | Sensitivity for normal edges (lower = more edges) |

### Style
| Property | Default | Description |
|----------|---------|-------------|
| `line_highlight` | 0.15 | Brightening on surface angle changes |
| `line_shadow` | 0.4 | Darkening on depth discontinuities |

## Layer Setup

Meshes must be visible on **both** layers:
- **Layer 1**: Main render (what you see)
- **Layer 5**: Data render (depth/normals)

```gdscript
mesh.layers = 1 | 16  # Binary: 1 = layer 1, 16 = layer 5 (1 << 4)
```

Or in Inspector: VisualInstance3D → Layers → Enable 1 and 5

## Comparison with 3D Pixel Art Shader

| Aspect | Pixel Outline v2 | 3D Pixel Art |
|--------|-----------------|--------------|
| Renderer | Any (Compatibility ✅) | Forward+/Mobile only |
| Render passes | 2 | 1 |
| Built-in textures | Not needed | hint_depth_texture, etc. |
| Material requirement | Data pass needed | None |
| Transparent objects | Works | Problematic |

## Troubleshooting

**No outlines appearing:**
- Check mesh `layers` includes both 1 and 16
- Ensure mesh has material with data pass (or use auto_setup_materials)
- Verify OutlineSetup has source_camera set

**Outlines too thick/thin:**
- Adjust `outline_width`
- Try different `depth_threshold` and `normal_threshold` values

**Missing some edges:**
- Lower `depth_threshold` for more depth edges
- Lower `normal_threshold` for more surface angle edges

**Too many edges / noisy:**
- Increase thresholds
- Check for z-fighting in your scene

**Outlines on wrong side:**
- This is normal for back-faces; outlines appear on the "front" of depth discontinuities

## Advanced: Custom Data Shader

If you need custom behavior, create your own spatial shader that outputs depth+normals on layer 5:

```glsl
shader_type spatial;
render_mode unshaded;

const int OUTLINE_LAYER = 16;

void fragment() {
    if ((int(CAMERA_VISIBLE_LAYERS) & OUTLINE_LAYER) != 0) {
        float depth = FRAGCOORD.z;
        vec3 encoded_normal = normalize(NORMAL) * 0.5 + 0.5;
        ALBEDO = vec3(depth, encoded_normal.x, encoded_normal.y);
        ALPHA = encoded_normal.z;
    } else {
        // Your regular rendering here
        ALBEDO = vec3(1.0);
    }
}
```

## License

MIT
