extends SceneTree

const NatureAssets := preload("res://scripts/nature_assets.gd")


func _initialize() -> void:
	for group_name in NatureAssets.MODEL_GROUPS:
		for variant in range(NatureAssets.available_count(group_name)):
			var instance := NatureAssets.instantiate(group_name, variant)
			if instance == null:
				push_error("NATURE_ASSET_LOAD_FAILED group=%s variant=%d" % [group_name, variant])
				quit(1)
				return
			root.add_child(instance)
			var bounds := _combined_aabb(instance)
			print("NATURE_ASSET group=%s variant=%d size=%s" % [group_name, variant, bounds.size])
			if variant == 0:
				_print_materials(group_name, instance)
			instance.free()
	print("NATURE_ASSET_SMOKE_OK")
	quit()


func _combined_aabb(root_node: Node) -> AABB:
	var result := AABB()
	var initialized := false
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.transform * mesh_instance.get_aabb()
		if initialized:
			result = result.merge(local_bounds)
		else:
			result = local_bounds
			initialized = true
	return result


func _print_materials(group_name: String, root_node: Node) -> void:
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)
			var texture_path := ""
			if material is BaseMaterial3D and material.albedo_texture:
				texture_path = material.albedo_texture.resource_path
			print("NATURE_MATERIAL group=%s node=%s surface=%s material=%s texture=%s" % [
				group_name,
				mesh_instance.name,
				mesh_instance.mesh.surface_get_name(surface_index),
				material.resource_name if material else "none",
				texture_path,
			])
