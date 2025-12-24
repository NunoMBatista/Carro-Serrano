extends Node

@export var shader_path: String = "res://shaders/bayer_dither.shader"
@export_range(1.0, 64.0, 1.0) var resolution_downsampling: float = 8.0
@export_range(2.0, 64.0, 1.0) var bit_depth: float = 4.0
@export_range(0.0, 2.0, 0.1) var dither_strength: float = 1.0

func _ready():
	var node = self
	# Find nearest CanvasLayer ancestor (the scene has a `Control` CanvasLayer)
	var canvas_parent = null
	while node:
		if node is CanvasLayer:
			canvas_parent = node
			break
		node = node.get_parent()

	if not canvas_parent:
		canvas_parent = get_tree().get_root()

	var cr = ColorRect.new()
	cr.name = "BayerPostProcess"
	canvas_parent.add_child.call_deferred(cr)
	# Fill the parent control/viewport
	if cr.has_method("set_anchors_preset"):
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		cr.anchor_left = 0
		cr.anchor_top = 0
		cr.anchor_right = 1
		cr.anchor_bottom = 1

	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_as_relative = false
	cr.z_index = 1000

	var mat = ShaderMaterial.new()
	var sh = null
	# If the path points to a plain text shader file, read it directly to avoid
	# ResourceLoader emitting errors for unknown extensions (e.g. .shader).
	if FileAccess.file_exists(shader_path):
		var f := FileAccess.open(shader_path, FileAccess.READ)
		if f != null:
			var code := f.get_as_text()
			f.close()
			var shader_obj := Shader.new()
			shader_obj.code = code
			sh = shader_obj
		else:
			push_error("[apply_bayer] Failed to open shader file: " + str(shader_path))
	else:
		# Otherwise try ResourceLoader for packed resources (.tres/.res etc.)
		sh = ResourceLoader.load(shader_path)
		if not sh:
			push_error("[apply_bayer] Failed to load shader resource: " + str(shader_path))

	if sh:
		mat.shader = sh
		mat.set_shader_parameter("bit_depth", float(bit_depth))
		mat.set_shader_parameter("resolution_downsampling", float(resolution_downsampling))
		mat.set_shader_parameter("dither_strength", float(dither_strength))
		print("[apply_bayer] Shader loaded and applied (", shader_path, ")")
	else:
		push_error("[apply_bayer] Failed to load shader resource and fallback failed: " + str(shader_path))

	cr.material = mat

	# Don't call get_path() here because node may not yet be fully inside tree in some cases.
	print("[apply_bayer] Created ColorRect name:", cr.name, " parent:", canvas_parent)
