extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_combat_sandbox_requested")
	for _frame in range(12):
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("/private/tmp/combat_sandbox_qa.png")
	if error != OK:
		push_error("COMBAT_SANDBOX_CAPTURE_FAILED: %s" % error_string(error))
		quit(1)
		return
	print("COMBAT_SANDBOX_CAPTURE_OK")
	quit(0)
