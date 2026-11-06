extends CharacterBody3D

var game
var human=false
var team=0
var hp=100.0
var armor=50.0
var frags=0
var deaths=0
var weapon=1
var ammo=30
var reserve=120
var cooldown=0.0
var reload_time=0.0
var dead_time=0.0
var camera: Camera3D
var gun: Node3D
var pitch=0.0
var target
var thinking=0.0
var destination=Vector3.ZERO
var aim=false
var touch_fire=false
var touch_crouch=false
var touch_sprint=false
var move_touch=Vector2.ZERO
var move_finger=-1
var look_finger=-1
var move_origin=Vector2.ZERO
var grenades=2
var recoil=0.0
var route=PackedVector2Array()
var entity_id=0
var peer_id=0
var display_name="Игрок"
var network_input={}
var input_received_at=0
var target_position=Vector3.ZERO
var send_clock=0.0
var pending_actions={}
var cash=3000
var unlocked=[0,1]
var last_visual_position=Vector3.ZERO
var walk_phase=0.0

func _ready():
 collision_layer=2
 collision_mask=3
 var c=CollisionShape3D.new()
 var capsule=CapsuleShape3D.new()
 capsule.radius=0.35
 capsule.height=1.8
 c.shape=capsule
 c.position.y=0.9
 add_child(c)
 if human:
  camera=Camera3D.new()
  camera.position.y=1.6
  camera.far=100
  add_child(camera)
  camera.current=true
  gun=Node3D.new()
  gun.position=Vector3(0.015,-0.06,-0.18)
  camera.add_child(gun)
  game.Visuals.weapon(game,gun,weapon)
 elif not game.dedicated:
  game.Visuals.soldier(game,self,team)

func respawn():
 position=game.spawn_position(team)
 rotation.y=PI if team==0 else 0.0
 pitch=0.0
 network_input={}
 input_received_at=0
 hp=100
 armor=50
 ammo=game.WEAPONS[weapon].mag
 reserve=120
 grenades=2
 dead_time=0
 visible=true
 collision_layer=2
 velocity=Vector3.ZERO

func equip(i: int):
 if game.net.online and not game.net.is_host and not game.net.applying_snapshot:
  game.net.request_action("equip",i)
  return
 weapon=i
 ammo=mini(ammo,int(game.WEAPONS[i].mag))
 reload_time=0
 if human and is_instance_valid(gun): game.Visuals.weapon(game,gun,weapon)

func _unhandled_input(e):
 if not human or not game.active or hp<=0: return
 if e is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  rotate_y(-e.relative.x*game.sensitivity)
  pitch=clampf(pitch-e.relative.y*game.sensitivity,-1.4,1.4)
 if e is InputEventMouseButton:
  if e.button_index==MOUSE_BUTTON_RIGHT: aim=e.pressed
 if e is InputEventScreenTouch:
  if e.pressed:
   if e.position.x<400 and move_finger<0:
    move_finger=e.index
    move_origin=e.position
   elif e.position.x>400 and look_finger<0: look_finger=e.index
  else:
   if e.index==move_finger:
    move_finger=-1
    move_touch=Vector2.ZERO
   if e.index==look_finger: look_finger=-1
 if e is InputEventScreenDrag:
  if e.index==move_finger: move_touch=((e.position-move_origin)/75).limit_length()
  if e.index==look_finger:
   rotate_y(-e.relative.x*game.sensitivity)
   pitch=clampf(pitch-e.relative.y*game.sensitivity,-1.4,1.4)

func touch_action(i: int, pressed: bool):
 match i:
  0: touch_fire=pressed
  1: aim=pressed
  2:
   if game.net.online and not game.net.is_host:
    if pressed: pending_actions.jump=true
   elif pressed and is_on_floor(): velocity.y=6
  3: touch_crouch=pressed
  4:
   if pressed: reload_weapon()
  5:
   if pressed: equip((weapon+1)%game.WEAPONS.size())
  6: touch_sprint=pressed
  7:
   if pressed: grenade()

func _physics_process(dt):
 if game.net.online and not game.net.is_host:
  position=position.lerp(target_position,minf(1,dt*18))
  if human and game.active: client_controls(dt)
  return
 if not game.active: return
 cooldown=maxf(0,cooldown-dt)
 if hp<=0:
  dead_time-=dt
  if dead_time<=0: respawn()
  return
 if reload_time>0:
  reload_time-=dt
  if reload_time<=0:
   var amount=mini(int(game.WEAPONS[weapon].mag)-ammo,reserve)
   ammo+=amount
   reserve-=amount
 var direction=Vector3.ZERO
 if human:
  camera.rotation.x=pitch+recoil
  recoil=move_toward(recoil,0,dt*0.6)
  camera.fov=lerpf(camera.fov,48.0 if aim else 78.0,dt*12)
  var crouch=Input.is_action_pressed("crouch") or touch_crouch
  camera.position.y=lerpf(camera.position.y,1.05 if crouch else 1.6,dt*12)
  var v=Input.get_vector("left","right","forward","back")+move_touch
  direction=(transform.basis*Vector3(v.x,0,v.y)).normalized()
  var speed=3.0 if crouch or aim else (8.0 if Input.is_action_pressed("sprint") or touch_sprint else 5.0)
  direction*=speed
  if game.net.online and game.control_is_blocked(): direction=Vector3.ZERO
  if not (game.net.online and game.control_is_blocked()):
   if Input.is_action_just_pressed("jump") and is_on_floor(): velocity.y=6
   if Input.is_action_just_pressed("reload"): reload_weapon()
   if Input.is_action_just_pressed("grenade"): grenade()
   if Input.is_action_just_pressed("knife"): knife()
   if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED) or touch_fire:
    if not (game.net.online and game.control_is_blocked()): shoot()
  gun.rotation.z=sin(game.elapsed*9)*0.015*direction.length()/5
  gun.position.z=lerpf(gun.position.z,-0.06 if cooldown>game.WEAPONS[weapon].rate*0.7 else -0.18,dt*18)
  animate_weapon(dt,direction.length()>0.1)
 elif peer_id>0:
  var input=network_input if Time.get_ticks_msec()-input_received_at<600 else {}
  rotation.y=input.get("yaw",rotation.y)
  pitch=input.get("pitch",pitch)
  aim=input.get("aim",false)
  var move: Vector2=input.get("move",Vector2.ZERO)
  var speed=3.0 if input.get("crouch",false) or aim else (8.0 if input.get("sprint",false) else 5.0)
  direction=(transform.basis*Vector3(move.x,0,move.y)).normalized()*speed if move.length()>0 else Vector3.ZERO
  if input.get("jump",false) and is_on_floor(): velocity.y=6
  if input.get("reload",false): reload_weapon()
  if input.get("grenade",false): grenade()
  if input.get("knife",false): knife()
  for event in ["jump","reload","grenade","knife"]: network_input[event]=false
  if input.get("fire",false): shoot()
 else:
  thinking-=dt
  if thinking<=0:
   thinking=0.3
   target=null
   var distance=999.0
   for a in game.actors:
    if a==self or a.hp<=0 or (game.match_mode==0 and a.team==team): continue
    var d=global_position.distance_to(a.global_position)
    if d<distance and clear_sight(a):
     target=a
     distance=d
   if target!=null:
    destination=target.global_position
    if hp<40: destination=global_position+(global_position-target.global_position).normalized()*5
   elif global_position.distance_to(destination)<2 or game.rng.randf()<0.05:
    destination=Vector3(game.rng.randf_range(-26,26),0,game.rng.randf_range(-26,26))
   route=game.route(global_position,destination)
  var waypoint=destination
  if route.size()>1:
   waypoint=Vector3(route[1].x,global_position.y,route[1].y)
   if global_position.distance_to(waypoint)<0.5: route.remove_at(0)
  var offset=waypoint-global_position
  offset.y=0
  if offset.length()>0.25:
   direction=offset.normalized()*3.5
   if is_on_wall():
    direction=direction.rotated(Vector3.UP,1.2)
    if is_on_floor(): velocity.y=5.0
  if target!=null and is_instance_valid(target) and clear_sight(target):
   var point=target.global_position
   point.y=global_position.y
   if global_position.distance_to(point)>0.1: look_at(point)
   if global_position.distance_to(target.global_position)<22: direction*=0.25
   shoot()
  if ammo==0: reload_weapon()
 velocity.x=direction.x
 velocity.z=direction.z
 if not is_on_floor(): velocity.y-=18*dt
 move_and_slide()
 if position.y < -10: respawn()

func clear_sight(a) -> bool:
 var q=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.45,a.global_position+Vector3.UP*1.3,3,[get_rid()])
 var hit=get_world_3d().direct_space_state.intersect_ray(q)
 return not hit.is_empty() and hit.collider==a

func reload_weapon():
 if game.net.online and not game.net.is_host:
  game.net.request_action("reload")
  return
 if reload_time<=0 and ammo<game.WEAPONS[weapon].mag and reserve>0: reload_time=game.WEAPONS[weapon].reload

func shoot():
 if game.net.online and not game.net.is_host: return
 if has_power("infinite_ammo") and ammo<=0: ammo=game.WEAPONS[weapon].mag
 if has_power("no_recoil"): recoil=0
 if cooldown>0 or reload_time>0 or ammo<=0: return
 if not (has_power("infinite_ammo")): ammo-=1
 var w=game.WEAPONS[weapon]
 cooldown=w.rate*(1 if human else 2.5-game.difficulty*0.6)
 var origin=global_position+Vector3.UP*1.45
 var forward=-global_transform.basis.z
 if human:
  origin=camera.global_position
  forward=-camera.global_transform.basis.z
  if not has_power("no_recoil"): recoil+=0.012
  game.sound()
 elif peer_id>0:
  origin=global_position+Vector3.UP*(1.05 if network_input.get("crouch",false) else 1.6)
  forward=(-global_transform.basis.z).rotated(global_transform.basis.x,pitch)
 elif target!=null:
  forward=(target.global_position+Vector3.UP*1.3-origin).normalized()
 var tracer_end=origin+forward*70
 var pellets=7 if weapon==4 else 1
 for i in range(pellets):
  var spread=w.spread*(0.3 if aim else 1.0)*(1.0 if human else 4.0-game.difficulty)
  if has_power("no_recoil"): spread=0.0
  var ray=(forward+Vector3(game.rng.randf_range(-spread,spread),game.rng.randf_range(-spread,spread),game.rng.randf_range(-spread,spread))).normalized()
  var q=PhysicsRayQueryParameters3D.create(origin,origin+ray*90,3,[get_rid()])
  var hit=get_world_3d().direct_space_state.intersect_ray(q)
  if not hit.is_empty():
   if i==0: tracer_end=hit.position
   game.effect(hit.position,Color("ffd37a"))
   if hit.collider is CharacterBody3D:
    var a=hit.collider
    if game.match_mode==1 or a.team!=team:
     a.damage(w.damage*(3.0 if hit.position.y-a.global_position.y>1.35 else 1.0),self)
 game.effect(origin+forward*0.9,Color("ffb133"),0.08)
 if game.net.online: game.net.publish_shot(self,origin,tracer_end)
 if not game.dedicated: game.Visuals.tracer(game,origin,tracer_end)

func damage(amount: float, attacker):
 if game.net.online and not game.net.is_host: return
 if has_power("invincible"): return
 if hp<=0: return
 var absorbed=minf(armor,amount*0.45)
 armor-=absorbed
 hp-=amount-absorbed
 if not human and is_instance_valid(attacker):
  target=attacker
  destination=attacker.global_position
 if hp<=0:
  game.died(self,attacker)
  dead_time=3
  collision_layer=0
  if not human: visible=false

func knife():
 if game.net.online and not game.net.is_host:
  game.net.request_action("knife")
  return
 if cooldown>0: return
 cooldown=0.6
 for a in game.actors:
  if a!=self and (game.match_mode==1 or a.team!=team) and global_position.distance_to(a.global_position)<2.6 and clear_sight(a):
   a.damage(65,self)

func grenade():
 if game.net.online and not game.net.is_host:
  game.net.request_action("grenade")
  return
 if has_power("infinite_ammo") and grenades<=0: grenades=1
 if grenades<=0 or hp<=0: return
 if not (has_power("infinite_ammo")): grenades-=1
 var position_target=global_position-global_transform.basis.z*8
 position_target.y=1
 var q=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,position_target,1)
 var hit=get_world_3d().direct_space_state.intersect_ray(q)
 if not hit.is_empty(): position_target=hit.position
 var marker=game.block(position_target,Vector3.ONE*0.2,Color("638442"),false)
 await get_tree().create_timer(1.5).timeout
 if not is_instance_valid(marker): return
 marker.queue_free()
 game.effect(position_target,Color("ff742e"),2)
 if game.net.online: game.net.explosion.rpc(position_target)
 for a in game.actors:
  var d=a.global_position.distance_to(position_target)
  if d<7 and (a==self or game.match_mode==1 or a.team!=team):
   var check=PhysicsRayQueryParameters3D.create(position_target+Vector3.UP*0.2,a.global_position+Vector3.UP,1)
   if get_world_3d().direct_space_state.intersect_ray(check).is_empty(): a.damage(100*(1-d/7),self)

func client_controls(dt: float):
 camera.rotation.x=pitch+recoil
 recoil=move_toward(recoil,0,dt*0.6)
 cooldown=maxf(0,cooldown-dt)
 var blocked=game.control_is_blocked()
 camera.fov=lerpf(camera.fov,48.0 if aim else 78.0,dt*12)
 camera.position.y=lerpf(camera.position.y,1.05 if Input.is_action_pressed("crouch") or touch_crouch else 1.6,dt*12)
 gun.position.z=lerpf(gun.position.z,-0.06 if cooldown>game.WEAPONS[weapon].rate*0.7 else -0.18,dt*18)
 animate_weapon(dt,Input.get_vector("left","right","forward","back").length()>0.1 or move_touch.length()>0.1)
 for event in ["jump","reload","grenade","knife"]:
  if Input.is_action_just_pressed(event): pending_actions[event]=true
 send_clock+=dt
 if send_clock<0.035: return
 send_clock=0
 var command={"move":Vector2.ZERO if blocked else (Input.get_vector("left","right","forward","back")+move_touch),"yaw":rotation.y,"pitch":pitch,"fire":not blocked and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or touch_fire),"aim":aim,"sprint":Input.is_action_pressed("sprint") or touch_sprint,"crouch":Input.is_action_pressed("crouch") or touch_crouch}
 for event in ["jump","reload","grenade","knife"]: command[event]=not blocked and pending_actions.get(event,false)
 pending_actions.clear()
 game.net.transmit_input(command)

func animate_weapon(dt: float, moving: bool):
 var bob=sin(game.elapsed*9)*.012 if moving and not aim else sin(game.elapsed*1.8)*.002
 gun.position.x=lerpf(gun.position.x,-.28 if aim else .015,dt*10)
 gun.position.y=lerpf(gun.position.y,(.045 if weapon==2 else .14) if aim else -.06+bob,dt*10)
 gun.rotation.x=lerp_angle(gun.rotation.x,-.45 if reload_time>0 else 0.0,dt*8)

func _process(dt):
 if human or game.dedicated or not game.active: return
 var distance=(position-last_visual_position).length()
 last_visual_position=position
 if distance>0.001 and distance<1:
  walk_phase+=distance*5
 var amplitude=0.4 if distance>0.001 and distance<1 else 0.0
 var left=get_node_or_null("LeftLeg")
 var right=get_node_or_null("RightLeg")
 if left!=null:
  left.rotation.x=lerpf(left.rotation.x,sin(walk_phase)*amplitude,minf(1,dt*12))
  right.rotation.x=lerpf(right.rotation.x,-sin(walk_phase)*amplitude,minf(1,dt*12))

func has_power(power: String) -> bool:
 if game.net.online:
  return peer_id>0 and peer_id==game.net.admin_id and game.net.admin_powers.get(power,false)
 return human and game.training.get(power,false)
