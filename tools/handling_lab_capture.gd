extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/ship_handling_lab.tscn") as PackedScene
	var lab := scene.instantiate()
	root.add_child(lab)
	for frame in range(20):
		await physics_frame
	var brig := lab.get_node_or_null("LabBrig")
	if brig == null:
		return _fail("Handling lab did not spawn the Brig")
	brig.set_sail_step(3)
	for frame in range(120):
		await physics_frame
	if not await _save_frame("/private/tmp/blackflag_handling_brig_qa.png"):
		return

	lab.call("_select_ship", 3)
	for frame in range(80):
		await physics_frame
	var man_o_war := lab.get_node_or_null("LabMano'War")
	if man_o_war == null:
		return _fail("Handling lab did not spawn the Man o' War")
	man_o_war.set_sail_step(2)
	for frame in range(80):
		await physics_frame
	if not await _save_frame("/private/tmp/blackflag_handling_manowar_qa.png"):
		return

	print("HANDLING_LAB_CAPTURE_OK brig=/private/tmp/blackflag_handling_brig_qa.png manowar=/private/tmp/blackflag_handling_manowar_qa.png")
	quit(0)


func _save_frame(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty():
		return _fail("Handling lab capture returned an empty image")
	var error := image.save_png(path)
	if error != OK:
		return _fail("Handling lab capture failed: %s" % error_string(error))
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
