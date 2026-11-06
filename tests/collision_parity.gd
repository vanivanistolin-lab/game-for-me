extends SceneTree
func _initialize(): call_deferred("run")
func geometry(game) -> Array:
 var result=[]
 for body in game.world.get_children():
  if not body is StaticBody3D: continue
  for child in body.get_children():
   if child is CollisionShape3D and child.shape is BoxShape3D:
    var p=body.position
    var s=child.shape.size
    result.append("%.3f,%.3f,%.3f / %.3f,%.3f,%.3f"%[p.x,p.y,p.z,s.x,s.y,s.z])
 result.sort()
 return result
func navigation(game) -> Array:
 var cells=[]
 for x in range(-29,30):
  for z in range(-29,30):
   if game.navigation.is_point_solid(Vector2i(x,z)): cells.append(Vector2i(x,z))
 return cells
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 var failures=0
 for map in range(3):
  game.map_id=map
  game.dedicated=false
  game.start_match()
  var visual_geometry=geometry(game)
  var visual_navigation=navigation(game)
  game.dedicated=true
  game.start_match()
  if geometry(game)!=visual_geometry:
   push_error("Server collision geometry differs on map %d"%map)
   failures+=1
  else: print("PASS: collision parity map ",map)
  if navigation(game)!=visual_navigation:
   push_error("Server navigation differs on map %d"%map)
   failures+=1
  else: print("PASS: navigation parity map ",map)
 game.queue_free()
 await process_frame
 print("COLLISION PARITY failures=",failures)
 quit(failures)
