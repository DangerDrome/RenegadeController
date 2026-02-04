extends Node3D
## Demo scene for the Dither Shader plugin.
## Press 1-5 to switch palettes, Q-T to switch dither patterns.
## Use arrow keys to adjust contrast/offset.

@onready var dither_overlay: DitherOverlay = $DitherOverlay
@onready var sphere: MeshInstance3D = $Primitives/Sphere
@onready var cube: MeshInstance3D = $Primitives/Cube
@onready var prism: MeshInstance3D = $Primitives/Prism

var _timer: float = 0.0

const PALETTE_NAMES := ["Mono", "Moonlight", "Eevee", "Hollow", "Rising Sun"]
const PATTERN_NAMES := ["Bayer 16x16", "Bayer 8x8", "Bayer 4x4", "Bayer 2x2", "Blue Noise"]


func _ready() -> void:
	print("Dither Demo Controls:")
	print("  1-5: Switch palette")
	print("  Q-T: Switch dither pattern")
	print("  Up/Down: Adjust contrast")
	print("  Left/Right: Adjust offset")
	print("  +/-: Adjust dither size")
	print("  Space: Toggle effect")


func _process(delta: float) -> void:
	_timer += delta

	# Animate primitives
	if sphere:
		sphere.position.y = 2.5 + sin(_timer) * 1.0
	if cube:
		cube.position.y = 2.5 + sin(_timer + PI * 0.5) * 1.0
		cube.rotation.y = _timer
	if prism:
		prism.position.y = 2.5 + sin(_timer + PI) * 1.0
		prism.rotation.z = _timer


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			# Palette switching (1-5)
			KEY_1:
				_set_palette(DitherOverlay.PalettePreset.MONO)
			KEY_2:
				_set_palette(DitherOverlay.PalettePreset.MOONLIGHT)
			KEY_3:
				_set_palette(DitherOverlay.PalettePreset.EEVEE)
			KEY_4:
				_set_palette(DitherOverlay.PalettePreset.HOLLOW)
			KEY_5:
				_set_palette(DitherOverlay.PalettePreset.RISING_SUN)
			# Pattern switching (Q-T)
			KEY_Q:
				_set_pattern(DitherOverlay.DitherPattern.BAYER_16X16)
			KEY_W:
				_set_pattern(DitherOverlay.DitherPattern.BAYER_8X8)
			KEY_E:
				_set_pattern(DitherOverlay.DitherPattern.BAYER_4X4)
			KEY_R:
				_set_pattern(DitherOverlay.DitherPattern.BAYER_2X2)
			KEY_T:
				_set_pattern(DitherOverlay.DitherPattern.BLUE_NOISE)
			# Contrast adjustment
			KEY_UP:
				dither_overlay.contrast = clampf(dither_overlay.contrast + 0.1, 0.0, 5.0)
				print("Contrast: %.2f" % dither_overlay.contrast)
			KEY_DOWN:
				dither_overlay.contrast = clampf(dither_overlay.contrast - 0.1, 0.0, 5.0)
				print("Contrast: %.2f" % dither_overlay.contrast)
			# Offset adjustment
			KEY_RIGHT:
				dither_overlay.lum_offset = clampf(dither_overlay.lum_offset + 0.05, -1.0, 1.0)
				print("Offset: %.2f" % dither_overlay.lum_offset)
			KEY_LEFT:
				dither_overlay.lum_offset = clampf(dither_overlay.lum_offset - 0.05, -1.0, 1.0)
				print("Offset: %.2f" % dither_overlay.lum_offset)
			# Dither size
			KEY_EQUAL, KEY_KP_ADD:
				dither_overlay.dither_size = clampi(dither_overlay.dither_size + 1, 1, 8)
				print("Dither size: %d" % dither_overlay.dither_size)
			KEY_MINUS, KEY_KP_SUBTRACT:
				dither_overlay.dither_size = clampi(dither_overlay.dither_size - 1, 1, 8)
				print("Dither size: %d" % dither_overlay.dither_size)
			# Toggle effect
			KEY_SPACE:
				dither_overlay.effect_enabled = not dither_overlay.effect_enabled
				print("Dither: %s" % ("ON" if dither_overlay.effect_enabled else "OFF"))


func _set_palette(preset: DitherOverlay.PalettePreset) -> void:
	dither_overlay.palette_preset = preset
	print("Palette: %s" % PALETTE_NAMES[preset])


func _set_pattern(preset: DitherOverlay.DitherPattern) -> void:
	dither_overlay.pattern_preset = preset
	print("Pattern: %s" % PATTERN_NAMES[preset])
