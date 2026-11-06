extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 var errors=0
 if game.net.host(0)!=OK:
  push_error("Cannot start admin test server")
  quit(1)
  return
 var owner=game.player
 var bot=game.actors[1]
 game.net.admin_action("power_invincible",1)
 owner.damage(1000,bot)
 if owner.hp!=100: errors+=1; push_error("Invulnerability did not protect admin")
 else: print("PASS: server prevents admin damage")
 bot.damage(30,owner)
 if bot.hp>=100: errors+=1; push_error("Admin powers leaked to bot")
 else: print("PASS: admin powers do not protect opponents")
 game.net.admin_action("power_invincible",0)
 owner.damage(10,bot)
 if owner.hp>=100: errors+=1; push_error("Cannot disable invulnerability")
 else: print("PASS: disabling invulnerability restores damage")
 game.net.admin_action("power_invincible",1)
 game.net.admin_id=0
 owner.damage(10,bot)
 if owner.has_power("invincible"): errors+=1; push_error("Revoked administrator retained powers")
 else: print("PASS: losing admin rights revokes powers")
 game.net.leave("")
 game.queue_free()
 await process_frame
 quit(errors)
