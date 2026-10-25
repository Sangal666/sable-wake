extends RefCounted

const BASE_PATH := "res://assets/quaternius_pirate_kit/glTF/"

const CREW_PATHS := [
	BASE_PATH + "Characters_Anne.gltf",
	BASE_PATH + "Characters_Captain_Barbarossa.gltf",
	BASE_PATH + "Characters_Henry.gltf",
	BASE_PATH + "Characters_Mako.gltf",
	BASE_PATH + "Characters_Sharky.gltf",
]

const PROP_PATHS := {
	"barrel": BASE_PATH + "Prop_Barrel.gltf",
	"bucket": BASE_PATH + "Prop_Bucket.gltf",
	"cannon": BASE_PATH + "Prop_Cannon.gltf",
	"chest": BASE_PATH + "Prop_Chest_Closed.gltf",
	"gold_chest": BASE_PATH + "Prop_Chest_Gold.gltf",
	"anchor": BASE_PATH + "Prop_Anchor.gltf",
	"palm_1": BASE_PATH + "Environment_PalmTree_1.gltf",
	"palm_2": BASE_PATH + "Environment_PalmTree_2.gltf",
	"palm_3": BASE_PATH + "Environment_PalmTree_3.gltf",
	"rock_1": BASE_PATH + "Environment_Rock_1.gltf",
	"rock_2": BASE_PATH + "Environment_Rock_2.gltf",
	"rock_3": BASE_PATH + "Environment_Rock_3.gltf",
	"rock_4": BASE_PATH + "Environment_Rock_4.gltf",
	"rock_5": BASE_PATH + "Environment_Rock_5.gltf",
	"dock": BASE_PATH + "Environment_Dock.gltf",
}

static var _scene_cache: Dictionary = {}


static func instantiate_crew(index: int) -> Node3D:
	if CREW_PATHS.is_empty():
		return null
	return _instantiate_scene(CREW_PATHS[posmod(index, CREW_PATHS.size())])


static func instantiate_prop(prop_name: String) -> Node3D:
	var path := String(PROP_PATHS.get(prop_name, ""))
	if path.is_empty():
		return null
	return _instantiate_scene(path)


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := find_animation_player(child)
		if found:
			return found
	return null


static func _instantiate_scene(path: String) -> Node3D:
	var scene := _scene_cache.get(path) as PackedScene
	if scene == null:
		scene = load(path) as PackedScene
		if scene:
			_scene_cache[path] = scene
	if scene == null:
		return null
	return scene.instantiate() as Node3D
