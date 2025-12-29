@tool
extends Node

@export var road_container: Node3D
@export var guardrail_mesh: Mesh
@export var generate: bool = false: set = _set_generate

func _set_generate(value):
	if value:
		generate_guardrails()
	generate = false

func generate_guardrails():
	if not road_container:
		print("RoadContainer not assigned")
		return
	if not guardrail_mesh:
		print("Guardrail Mesh not assigned")
		return
	
	print("Generating guardrails...")
	
	# Ensure edge curves are generated
	var original_create_edge = false
	if "create_edge_curves" in road_container:
		original_create_edge = road_container.create_edge_curves
		road_container.create_edge_curves = true
	else:
		print("Error: Assigned node is not a RoadContainer (missing create_edge_curves)")
		return
	
	# Force update might be needed? Usually setting the property triggers it.
	
	# Container for our generated nodes
	var container_name = "GuardRails_Generated"
	var rails_root = road_container.get_node_or_null(container_name)
	if rails_root:
		rails_root.free() # Delete old one
	
	rails_root = Node3D.new()
	rails_root.name = container_name
	road_container.add_child(rails_root)
	rails_root.owner = road_container.get_tree().edited_scene_root
	
	# Collect points
	var points = []
	for child in road_container.get_children():
		if child.has_method("get_class") and child.get_class() == "RoadPoint": # RoadPoint is a class_name but checking script is safer
			points.append(child)
		elif child.get_script() and child.get_script().resource_path.contains("road_point.gd"):
			points.append(child)
	
	if points.size() == 0:
		print("No RoadPoints found")
		return

	# Find start point
	var start_point = null
	for pt in points:
		# Check if this point is a target of any other point in this list
		var is_target = false
		for other in points:
			if other == pt: continue
			# next_pt_init is a NodePath
			if other.next_pt_init and other.get_node_or_null(other.next_pt_init) == pt:
				is_target = true
				break
		if not is_target:
			start_point = pt
			break
	
	if not start_point:
		start_point = points[0]
		print("Could not determine start point, using first found: ", start_point.name)
	
	var current_pt = start_point
	var left_curve_points = PackedVector3Array()
	var right_curve_points = PackedVector3Array()
	
	var visited = {}
	
	while current_pt:
		if visited.has(current_pt):
			break
		visited[current_pt] = true
		
		# Find segment
		var segment = null
		for child in current_pt.get_children():
			# Check for RoadSegment. It might not have a class_name exposed globally easily
			if child.name.begins_with("RoadSegment") or child.has_method("generate_edge_curves"):
				segment = child
				break
		
		if segment:
			# Get edge curves
			# RoadSegment generates "edge_R" and "edge_F" as children of the RoadPoint (current_pt)
			# Wait, RoadSegment.gd says: _par.add_child(edge_R). _par is get_parent().
			# RoadSegment is child of RoadPoint. So _par is RoadPoint.
			# So edge_R is child of RoadPoint.
			
			var edge_r = current_pt.get_node_or_null("edge_R")
			var edge_f = current_pt.get_node_or_null("edge_F")
			
			if edge_r and edge_r is Path3D:
				var curve = edge_r.curve
				var transform = edge_r.global_transform
				for i in range(curve.point_count):
					var global_pos = transform * curve.get_point_position(i)
					right_curve_points.append(global_pos)
					
			if edge_f and edge_f is Path3D:
				var curve = edge_f.curve
				var transform = edge_f.global_transform
				for i in range(curve.point_count):
					var global_pos = transform * curve.get_point_position(i)
					left_curve_points.append(global_pos)
		
		# Move to next
		if current_pt.next_pt_init:
			var next = current_pt.get_node_or_null(current_pt.next_pt_init)
			if next:
				current_pt = next
			else:
				current_pt = null
		else:
			current_pt = null

	# Create Paths
	create_path_and_mesh(rails_root, "LeftGuardRail", left_curve_points)
	create_path_and_mesh(rails_root, "RightGuardRail", right_curve_points)
	
	# Restore setting
	road_container.create_edge_curves = original_create_edge
	print("Guardrail generation complete.")

func create_path_and_mesh(parent, name, global_points):
	if global_points.size() < 2:
		return
		
	var path = Path3D.new()
	path.name = name + "_Path"
	parent.add_child(path)
	path.owner = parent.owner
	
	path.curve = Curve3D.new()
	for pos in global_points:
		path.curve.add_point(path.to_local(pos))
		
	# Instantiate PathMesh3D
	var pm = ClassDB.instantiate("PathMesh3D")
	if not pm:
		print("PathMesh3D class not found")
		return
		
	pm.name = name
	parent.add_child(pm)
	pm.owner = parent.owner
	
	pm.mesh = guardrail_mesh
	pm.path = path.get_path()
	
	# Optional: Configure PathMesh3D properties if needed
	# pm.distribution = 0 # DISTRIBUTION_TYPE_DIVIDE (example)
