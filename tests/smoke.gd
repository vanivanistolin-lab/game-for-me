extends SceneTree

var failures=0
func check(ok: bool, message: String):
 if not ok:
  failures+=1
  push_error(message)
 else: print("PASS: "+message)

func _initialize():
 call_deferred("run")

func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 check(is_instance_valid(game.menu),"Russian main menu loads")
 for map_id in range(3):
  game.map_id=map_id
  game.start_match()
  await physics_frame
  check(game.actors.size()==8,"Map %d has eight combatants"%map_id)
  check(game.player.camera.current,"FPS camera active")
 var player=game.player
 for index in range(5):
  player.equip(index)
  check(player.gun.get_child(0).get_child_count()>0,"Weapon model %d loads"%index)
 var enemy=game.actors[1]
 enemy.team=1-player.team
 player.equip(1)
 player.ammo=1
 player.shoot()
 check(player.ammo==0,"Firing consumes ammo")
 player.reload_weapon()
 check(player.reload_time>0,"Reload begins")
 player.reload_time=0.001
 await physics_frame
 await physics_frame
 check(player.ammo>0 and player.reserve<120,"Reload transfers reserve ammo")
 enemy.armor=50
 enemy.damage(30,player)
 check(enemy.hp<100 and enemy.armor<50,"Damage applies health and armor")
 enemy.damage(1000,player)
 check(enemy.hp<=0 and player.frags==1,"Kill is credited")
 enemy.dead_time=0.001
 await physics_frame
 await physics_frame
 check(enemy.hp==100,"Dead bot respawns")
 player.touch_action(0,true)
 check(player.touch_fire,"Touch fire enabled")
 player.touch_action(0,false)
 check(not player.touch_fire,"Touch release stops fire")
 var bot=game.actors[2]
 var initial=bot.position
 for frame in range(600): await physics_frame
 check(bot.position.distance_to(initial)>1,"Bot navigates during live simulation")
 var living=0
 for a in game.actors:
  if a.hp>0: living+=1
 check(living>0,"Live simulation retains active combatants")
 check(game.surface_cache.size()>=6,"Textured surfaces are instantiated")
 game.graphics=0
 game.apply_quality()
 check(not game.world.get_node("Sun").shadow_enabled,"Low graphics disables shadows")
 game.graphics=2
 game.apply_quality()
 check(game.world.get_node("Sun").shadow_enabled,"High graphics enables shadows")
 game.training.invincible=true
 player.hp=100
 player.armor=50
 player.damage(1000,enemy)
 check(player.hp==100 and player.armor==50,"Training invulnerability protects player")
 game.training.invincible=false
 player.damage(10,enemy)
 check(player.hp<100,"Disabling invulnerability restores damage")
 game.training.infinite_ammo=true
 player.ammo=1
 player.cooldown=0
 player.reload_time=0
 player.shoot()
 check(player.ammo==1,"Training infinite ammo retains ammunition")
 game.training.no_recoil=true
 player.cooldown=0
 player.recoil=0.2
 player.shoot()
 check(player.recoil==0,"Training no recoil clears recoil")
 game.training.infinite_ammo=false
 game.training.no_recoil=false
 player.cooldown=0
 player.shoot()
 check(player.ammo==0,"Disabling training restores ammo consumption")
 game.show_training()
 check(game.get_tree().paused and is_instance_valid(game.training_panel),"Training menu pauses live match")
 var controls=game.training_panel.get_child(0).get_children()
 controls[1].button_pressed=true
 check(game.training.invincible and game.practice_used,"Training checkbox marks practice match")
 controls[-1].pressed.emit()
 await process_frame
 check(not game.get_tree().paused,"Closing training restores match")
 game.remaining=0.001
 await process_frame
 await process_frame
 check(not game.active,"Timer ends match")
 print("SMOKE COMPLETE failures=",failures)
 for sound in game.world.get_children():
  if sound is AudioStreamPlayer:
   sound.stop()
   sound.stream=null
 await process_frame
 game.queue_free()
 await process_frame
 await process_frame
 quit(failures)
