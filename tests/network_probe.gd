extends SceneTree
var game
var role="guest"
var output_dir=""
var port=24681
var failures=0
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
  if arg.begins_with("--output="): output_dir=arg.trim_prefix("--output=")
  if arg.begins_with("--port="): port=int(arg.trim_prefix("--port="))
 call_deferred("run")
func check(ok: bool, description: String):
 if not ok:
  failures+=1
  push_error(description)
 else: print("PASS: ",role," ",description)
func wait_for(predicate: Callable, seconds: float=10.0) -> bool:
 var end=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<end:
  if predicate.call(): return true
  await process_frame
 return false
func mark(name: String):
 var file=FileAccess.open(output_dir+"/"+name,FileAccess.WRITE)
 file.store_string("ready")
func run():
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var key=OS.get_environment("TEST_ADMIN_TOKEN") if role=="admin" else ""
 check(game.net.join_server("ws://127.0.0.1:%d"%port,role,key)==OK,"WebSocket connection starts")
 var joined=await wait_for(func(): return is_instance_valid(game.player) and game.net.diagnostics.snapshots>0)
 check(joined,"Receives player and server state")
 if not joined: quit(1); return
 game.player.set_physics_process(false)
 if role=="guest": await guest()
 else: await admin()
 var file=FileAccess.open(output_dir+"/"+role+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"failures":failures}))
 game.net.leave("")
 game.queue_free()
 await process_frame
 quit(failures)
func guest():
 check(not game.net.is_admin(),"Guest has no administrative privileges")
 game.net.claim_admin.rpc_id(1,"wrong-password-at-least-sixteen")
 game.net.admin_action("map",1)
 game.net.admin_action("power_invincible",1)
 await create_timer(0.4).timeout
 check(not game.net.admin_powers.invincible,"Guest cannot enable admin cheats")
 check(game.map_id==0 and not game.net.is_admin(),"Wrong key and unauthorized map change rejected")
 game.show_training()
 check(not is_instance_valid(game.training_panel),"Offline training is blocked in multiplayer")
 var clean=game.net.sanitized_input({"move":Vector2(999,0),"hp":99999,"pos":Vector3(999,999,999),"yaw":0.0,"pitch":0.0})
 check(clean.move.length()<=1 and not clean.has("hp") and not clean.has("pos"),"Input rejects forged health and position")
 var start=game.player.target_position
 var initial=game.player.ammo
 for i in range(10):
  game.net.transmit_input({"move":Vector2(999,0),"yaw":0.0,"pitch":0.0,"fire":true,"hp":99999,"position":Vector3(999,999,999)})
  await create_timer(0.045).timeout
 await create_timer(0.2).timeout
 check(game.player.target_position.distance_to(start)<5,"Server clamps impossible movement speed")
 check(game.player.hp<=100 and game.player.ammo<initial,"Server controls health and ammunition")
 mark("guest-ready")
 var changed=await wait_for(func(): return game.map_id==2,15)
 check(changed,"Guest receives administrator map switch")
 mark("guest-map-ready")
 var disconnected=await wait_for(func(): return not game.net.online,15)
 check(disconnected,"Kicked client disconnects")
func admin():
 check(await wait_for(func(): return game.net.is_admin()),"Correct secret grants admin rights")
 check(await wait_for(func(): return game.net.players.size()==2),"Two real clients share a match")
 check(await wait_for(func(): return FileAccess.file_exists(output_dir+"/guest-ready")),"Guest tests completed")
 game.net.admin_action("power_invincible",1)
 game.net.admin_action("power_infinite_ammo",1)
 game.net.admin_action("power_no_recoil",1)
 check(await wait_for(func(): return game.player.has_power("invincible") and game.player.has_power("infinite_ammo") and game.player.has_power("no_recoil")),"Server grants powers only to authenticated admin")
 var ammo=game.player.ammo
 for i in range(5):
  game.net.transmit_input({"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"fire":true})
  await create_timer(.05).timeout
 check(game.player.ammo==ammo,"Admin firing preserves ammo on real server")
 game.net.admin_action("heal")
 check(await wait_for(func(): return game.player.hp==100 and game.player.armor==100),"Admin heal executes on server")
 game.net.admin_action("power_infinite_ammo",0)
 check(await wait_for(func(): return not game.player.has_power("infinite_ammo")),"Administrator can disable powers")
 game.net.admin_action("map",2)
 check(await wait_for(func(): return game.map_id==2),"Administrator changes map")
 check(game.net.is_admin(),"Administrator remains owner after map change")
 game.player.set_physics_process(false)
 check(await wait_for(func(): return FileAccess.file_exists(output_dir+"/guest-map-ready")),"Map change synchronized to guest")
 var guest_id=0
 for id in game.net.players:
  if id!=game.multiplayer.get_unique_id(): guest_id=id
 check(guest_id>0,"Guest has distinct network identity")
 game.net.admin_action("kick",guest_id)
 check(await wait_for(func(): return not game.net.players.has(guest_id)),"Administrator can remove guest")
