extends SceneTree
func _initialize(): call_deferred("capture")
func capture():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 root.size=Vector2i(1280,720)
 DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
 for frame in range(8): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/screenshots/menu.png")
 game.menu.queue_free()
 for map_id in range(3):
  game.map_id=map_id
  game.start_match()
  game.training.invincible=true
  for actor in game.actors:
   if not actor.human: actor.set_physics_process(false)
  game.player.position=Vector3(9,0,-24)
  game.player.look_at(Vector3(9,0,5))
  for frame in range(12): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/screenshots/map-%d.png"%map_id)
 game.training.reveal_bots=true
 game.actors[1].position=Vector3(10,0,10)
 for frame in range(3): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/screenshots/training-overlay.png")
 game.show_training()
 for frame in range(3): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/screenshots/training-menu.png")
 paused=false
 if is_instance_valid(game.training_panel): game.training_panel.queue_free()
 game.net.nickname="Владелец"
 game.net.host(24686)
 game.net.last_address=""
 game.net.show_panel()
 for frame in range(3): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/screenshots/network-admin.png")
 game.net.leave("")
 game.queue_free()
 await process_frame
 quit()
