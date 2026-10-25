extends RefCounted

const BASE_PATH := "res://assets/quaternius_nature/FBX/"
const TEXTURE_PATH := "res://assets/quaternius_nature/Textures/"

const MODEL_GROUPS := {
	"palm": [
		"PalmTree_1.fbx", "PalmTree_2.fbx", "PalmTree_3.fbx",
		"PalmTree_4.fbx", "PalmTree_5.fbx",
	],
	"rock": [
		"Rock_1.fbx", "Rock_2.fbx", "Rock_3.fbx", "Rock_4.fbx", "Rock_5.fbx",
	],
	"bush": [
		"Bush.fbx", "Bush_Large.fbx", "Bush_Small.fbx",
		"Bush_Flowers.fbx", "Bush_Large_Flowers.fbx", "Bush_Small_Flowers.fbx",
	],
	"ground": [
		"Grass_Large_Extruded.fbx", "Grass_Large.fbx", "Grass_Small.fbx",
		"Plant_1.fbx", "Plant_2.fbx", "Plant_Flowers.fbx",
	],
	"dead_tree": [
		"DeadTree_1.fbx", "DeadTree_2.fbx", "DeadTree_3.fbx", "DeadTree_4.fbx",
		"DeadTree_5.fbx", "DeadTree_6.fbx", "DeadTree_7.fbx", "DeadTree_8.fbx",
		"DeadTree_9.fbx", "DeadTree_10.fbx",
	],
	"forest": [
		"BirchTree_1.fbx", "BirchTree_2.fbx", "BirchTree_3.fbx", "BirchTree_4.fbx", "BirchTree_5.fbx",
		"MapleTree_1.fbx", "MapleTree_2.fbx", "MapleTree_3.fbx", "MapleTree_4.fbx", "MapleTree_5.fbx",
		"NormalTree_1.fbx", "NormalTree_2.fbx", "NormalTree_3.fbx", "NormalTree_4.fbx", "NormalTree_5.fbx",
		"PineTree_1.fbx", "PineTree_2.fbx", "PineTree_3.fbx", "PineTree_4.fbx", "PineTree_5.fbx",
	],
	"flowers": [
		"Flower_1.fbx", "Flower_1_Clump.fbx", "Flower_2.fbx", "Flower_2_Clump.fbx",
		"Flower_3_Clump.fbx", "Flower_4_Clump.fbx", "Flower_5_Clump.fbx",
		"Petals_1.fbx", "Petals_2.fbx", "Petals_3.fbx", "Petals_4.fbx",
	],
}

const MATERIAL_TEXTURES := {
	"PalmTree_Trunk": "PalmTree_Trunk.png",
	"PalmTree_Leaves": "PalmTree_Leaves.png",
	"Rock": "Rocks.png",
	"Rocks": "Rocks.png",
	"Bush_Leaves": "Bush_Leaves.png",
	"Grass": "Grass.png",
	"Plant": "Grass.png",
	"Flowers": "Flowers.png",
	"NormalTree_Bark": "NormalTree_Bark.png",
	"NormalTree_Leaves": "NormalTree_Leaves.png",
	"BirchTree_Bark": "BirchTree_Bark.png",
	"BirchTree_Leaves": "BirchTree_Leaves.png",
	"MapleTree_Bark": "MapleTree_Bark.png",
	"MapleTree_Leaves": "MapleTree_Leaves.png",
	"PineTree_Bark": "PineTree_Bark.png",
	"PineTree_Leaves": "PineTree_Leaves.png",
}

const CUTOUT_MATERIALS := {
	"PalmTree_Leaves": true,
	"Bush_Leaves": true,
	"Grass": true,
	"Plant": true,
	"Flowers": true,
	"NormalTree_Leaves": true,
	"BirchTree_Leaves": true,
	"MapleTree_Leaves": true,
	"PineTree_Leaves": true,
}

static var _scene_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func instantiate(group_name: String, variant: int = -1) -> Node3D:
	var paths: Array = MODEL_GROUPS.get(group_name, [])
	if paths.is_empty():
		return null
	var index := variant
	if index < 0:
		index = randi_range(0, paths.size() - 1)
	var path := BASE_PATH + String(paths[posmod(index, paths.size())])
	var scene := _scene_cache.get(path) as PackedScene
	if scene == null:
		scene = load(path) as PackedScene
		if scene:
			_scene_cache[path] = scene
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	_apply_materials(instance, group_name)
	return instance


static func available_count(group_name: String) -> int:
	return (MODEL_GROUPS.get(group_name, []) as Array).size()


static func _apply_materials(instance: Node3D, group_name: String) -> void:
	if instance == null:
		return
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			var material_name: String = String(mesh_instance.mesh.surface_get_name(surface_index))
			if source_material and not source_material.resource_name.is_empty():
				material_name = source_material.resource_name
			var material := _material_for_name(material_name, group_name)
			if material:
				mesh_instance.set_surface_override_material(surface_index, material)


static func _material_for_name(material_name: String, group_name: String) -> StandardMaterial3D:
	var resolved_name := material_name
	if not MATERIAL_TEXTURES.has(resolved_name):
		if group_name == "rock":
			resolved_name = "Rock"
		elif group_name == "ground":
			resolved_name = "Grass"
		elif group_name == "dead_tree":
			resolved_name = "NormalTree_Bark"
		elif group_name == "flowers":
			resolved_name = "Flowers"
	var texture_file := String(MATERIAL_TEXTURES.get(resolved_name, ""))
	if texture_file.is_empty():
		return null
	if _material_cache.has(resolved_name):
		return _material_cache[resolved_name] as StandardMaterial3D
	var texture := load(TEXTURE_PATH + texture_file) as Texture2D
	if texture == null:
		return null
	var material := StandardMaterial3D.new()
	material.resource_name = "Nature_%s" % resolved_name
	material.albedo_texture = texture
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if CUTOUT_MATERIALS.has(resolved_name):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.35
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[resolved_name] = material
	return material
