extends SceneTree
func _initialize(): call_deferred("start")
func start():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.rng.seed=1234
 game.net.bot_count=0
 game.start_match()
 print("NETWORK_TEST_SERVER_READY")
