extends RefCounted

static func mesh(game, parent: Node3D, pos: Vector3, shape: Mesh, color: Color, metal: float=0.0) -> MeshInstance3D:
 var m=MeshInstance3D.new()
 m.mesh=shape
 m.material_override=game.material(color,metal)
 parent.add_child(m)
 if parent==game.world: m.add_to_group("visual_detail")
 m.position=pos
 return m

static func cylinder(game, parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, horizontal: bool=false) -> MeshInstance3D:
 var shape=CylinderMesh.new()
 shape.top_radius=radius
 shape.bottom_radius=radius
 shape.height=height
 shape.radial_segments=12
 var m=mesh(game,parent,pos,shape,color,0.55)
 if horizontal: m.rotation_degrees.x=90
 return m

static func sign_text(game, pos: Vector3, text: String, color: Color, angle: float=0) -> Label3D:
 var l=Label3D.new()
 l.text=text
 l.font_size=64
 l.pixel_size=0.009
 l.modulate=color
 l.outline_size=8
 l.outline_modulate=Color("172630")
 game.world.add_child(l)
 l.add_to_group("visual_detail")
 l.position=pos
 l.rotation.y=angle
 return l

static func surface(game, pos: Vector3, size: Vector3, color: Color, texture: String, collision: bool=true):
 var b=game.block(pos,size,color,collision)
 b.get_child(0).material_override=game.surface_material(color,texture)
 return b

static func build(game):
 game.navigation=AStarGrid2D.new()
 game.navigation.region=Rect2i(-29,-29,59,59)
 game.navigation.cell_size=Vector2.ONE
 game.navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 game.navigation.update()
 var id=game.map_id
 var base=[Color("9dadb3"),Color("899b9e"),Color("baa077")][id]
 var env=WorldEnvironment.new()
 var e=Environment.new()
 env.environment=e
 e.background_mode=Environment.BG_SKY
 var sky=Sky.new()
 var atmosphere=ProceduralSkyMaterial.new()
 atmosphere.sky_top_color=Color("28648c") if id!=2 else Color("688c9a")
 atmosphere.sky_horizon_color=Color("8faebf") if id!=2 else Color("c7b696")
 atmosphere.ground_bottom_color=Color("28323b")
 atmosphere.ground_horizon_color=atmosphere.sky_horizon_color
 atmosphere.sun_angle_max=12
 sky.sky_material=atmosphere
 e.sky=sky
 e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color=Color("a8c4d6")
 e.ambient_light_energy=0.38
 e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 e.fog_enabled=game.graphics>0
 e.fog_mode=Environment.FOG_MODE_DEPTH
 e.fog_light_color=atmosphere.sky_horizon_color
 e.fog_density=0.002
 e.fog_depth_begin=35
 e.fog_depth_end=120
 game.world.add_child(env)
 var sun=DirectionalLight3D.new()
 sun.name="Sun"
 sun.rotation_degrees=Vector3(-42,-32,0) if id!=1 else Vector3(-28,45,0)
 sun.light_color=Color("ffe0ad")
 sun.light_energy=0.95
 sun.shadow_enabled=game.graphics>0
 sun.directional_shadow_max_distance=65
 sun.shadow_bias=0.04
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 game.world.add_child(sun)
 surface(game,Vector3(0,-0.5,0),Vector3(60,1,60),Color("92978d") if id!=2 else Color("d9bd87"),"paving" if id!=2 else "sand")
 for x in [-30,30]: surface(game,Vector3(x,2.5,0),Vector3(1,5,60),base.darkened(0.15),"brick")
 for z in [-30,30]: surface(game,Vector3(0,2.5,z),Vector3(60,5,1),base.darkened(0.15),"brick")
 for x in [-19,0,19]:
  for z in [-14,14]:
   var facade=base if x!=0 else base.darkened(0.15)
   surface(game,Vector3(x,3,z),Vector3(9,6,8),facade,"plaster" if id!=1 else "metal")
   surface(game,Vector3(x,0.6,z),Vector3(9.1,1.2,8.1),base.darkened(0.35),"brick")
   surface(game,Vector3(x,6.15,z),Vector3(9.5,0.3,8.5),Color("778084"),"metal")
   for side in [-1,1]:
    var front=z+side*4.08
    for w in [-2.7,0,2.7]:
     for y in [2.4,4.7]:
      game.block(Vector3(x+w,y,front),Vector3(1.65,1.65,0.15),Color("788d8e"),false)
      game.block(Vector3(x+w,y,front+side*0.09),Vector3(1.35,1.35,0.1),Color("294958"),false)
      game.block(Vector3(x+w,y-0.8,front+side*0.1),Vector3(1.85,0.15,0.4),base.lightened(0.2),false)
      game.block(Vector3(x+w,y,front+side*0.16),Vector3(0.07,1.35,0.07),Color("9eafb0"),false)
     if id==0:
      game.block(Vector3(x+w,3.7,front+side*0.55),Vector3(2,0.12,1),Color("507b86"),false)
    surface(game,Vector3(x,0.1,front+side*0.65),Vector3(10,0.2,1.2),base.lightened(0.08),"paving")
    # Narrow balcony rails and a signage strip add readable architectural scale.
    for w in [-3,3]: cylinder(game,game.world,Vector3(x+w,5,front+side*0.25),0.045,2.6,Color("788d91"))
   for side in [-1,1]:
    for w in [-2.4,0,2.4]:
     for y in [2.4,4.7]:
      game.block(Vector3(x+side*4.57,y,z+w),Vector3(0.15,1.65,1.65),Color("667f87"),false)
      game.block(Vector3(x+side*4.67,y,z+w),Vector3(0.08,1.35,1.35),Color("294958"),false)
      game.block(Vector3(x+side*4.72,y-0.83,z+w),Vector3(0.4,0.15,1.85),base,false)
   for corner in [-4.35,4.35]:
    cylinder(game,game.world,Vector3(x+corner,3,z-4.2),0.07,6,Color("657f84"))
   if id==0:
    game.block(Vector3(x,3.55,z-4.22),Vector3(4.6,0.55,0.2),Color("214b5b"),false)
    sign_text(game,Vector3(x,3.55,z-4.36),"PORT / 0%d"%(int(x+20)/19+1),Color("e5ded0"),PI)
   elif id==1:
    cylinder(game,game.world,Vector3(x-2,7,z),0.65,2.4,Color("879895"))
    cylinder(game,game.world,Vector3(x+2,7,z),0.4,2.0,Color("647578"))
   else:
    for w in range(-4,5,2):
     surface(game,Vector3(x+w,6.55,z-3.7),Vector3(0.8,0.6,0.6),base,"brick",false)
   game.block(Vector3(x+1.5,6.6,z),Vector3(2.1,0.7,1.3),Color("b3bdb9"),false)
   for fin in range(6): game.block(Vector3(x+0.6+fin*0.32,6.6,z-0.68),Vector3(0.1,0.45,0.08),Color("66777b"),false)
 # Shipping crates, cover and readable material seams.
 for x in [-23,-10,10,23]:
  for z in [-5,5]:
   surface(game,Vector3(x,0.9,z),Vector3(3,1.8,3),Color("a68b61"),"wood")
   for w in [-1.35,1.35]:
    game.block(Vector3(x+w,0.9,z-1.52),Vector3(0.12,1.8,0.08),Color("4c5757"),false)
   for y in [0.15,1.65]: game.block(Vector3(x,y,z-1.54),Vector3(3,0.12,0.1),Color("4c5757"),false)
   sign_text(game,Vector3(x,0.9,z-1.6),"R / 17",Color("ede2bd"),PI)
 for i in range(8):
  surface(game,Vector3(-5+i*1.2,0.15*i,22),Vector3(1.2,0.3*(i+1),4),base,"brick")
 for z in [-24,24]:
  for x in [-25,-12,12,25]:
   cylinder(game,game.world,Vector3(x,2.5,z),0.07,5,Color("3a4b52"))
   game.block(Vector3(x,5,z),Vector3(1.1,0.18,0.5),Color("e9d8a2"),false)
 # Distinct map landmarks, positioned away from the central combat lanes.
 if id==0:
  for x in [-27,27]:
   for z in [-22,22]:
    cylinder(game,game.world,Vector3(x,0.5,z),0.55,1,Color("537778"))
    for j in range(3):
     var leaves=SphereMesh.new()
     leaves.radius=0.85
     leaves.height=1.5
     mesh(game,game.world,Vector3(x+(j-1)*0.3,1.5+j*0.35,z),leaves,Color("486b50"))
  for x in [-18,18]:
   surface(game,Vector3(x,0.08,0),Vector3(0.14,0.02,48),Color("dbd1aa"),"plaster",false)
 elif id==1:
  for x in [-27,27]:
   for z in [-21,0,21]:
    cylinder(game,game.world,Vector3(x,1.1,z),0.55,2.2,Color("b06a3d"))
    for y in [0.2,1.9]: cylinder(game,game.world,Vector3(x,y,z),0.57,0.1,Color("485454"))
  for x in [-24,24]:
   game.block(Vector3(x,7,0),Vector3(0.3,1.1,26),Color("b38a3c"),false)
   for z in [-11,11]: game.block(Vector3(x,3.5,z),Vector3(0.3,7,0.3),Color("b38a3c"),false)
 else:
  for x in [-27,27]:
   surface(game,Vector3(x,4,21),Vector3(4,8,4),base,"brick")
   game.block(Vector3(x,8.2,21),Vector3(4.5,0.3,4.5),base.darkened(0.2),false)
 # Distant skyline expands the view beyond the playable boundary.
 for i in range(14):
  var x=-65+i*10
  var height=8+(i*13)%15
  surface(game,Vector3(x,height/2.0,48+(i%3)*5),Vector3(7,height,8),base.darkened(0.22),"plaster",false)
  if game.graphics>0:
   for y in range(3,height,3):
    game.block(Vector3(x,y,43.9+(i%3)*5),Vector3(4,0.9,0.1),Color("54727c"),false)
 enhance_environment(game)
 game.apply_quality()

static func weapon(game, root: Node3D, index: int):
 for child in root.get_children():
  root.remove_child(child)
  child.queue_free()
 var packed=load("res://assets/models/weapon-%d.glb"%index) as PackedScene
 if packed!=null:
  var model=packed.instantiate()
  root.add_child(model)
  model.position=Vector3(0.28,-0.24,-0.55)
 # Gloves, sleeves and a supporting left arm frame the weapon.
 for side in [-1,1]:
  var pos=Vector3(0.28 if side==1 else 0.17,-0.43 if side==1 else -0.33,-0.39 if side==1 else -0.8)
  var glove=SphereMesh.new()
  glove.radius=0.075
  glove.height=0.18
  mesh(game,root,pos,glove,Color("5c6256"))
  var sleeve=game.block(pos+Vector3(0.02,-0.07,0.18),Vector3(0.14,0.16,0.32),Color("3e535b"),false,root)
  sleeve.rotation_degrees.x=-20

static func soldier(game, actor: Node3D, team: int):
 var uniform=Color("476477") if team==0 else Color("8d7656")
 game.block(Vector3(0,0.98,0),Vector3(0.47,0.66,0.28),uniform,false,actor)
 game.block(Vector3(0,1.03,-0.18),Vector3(0.43,0.45,0.12),Color("303e44"),false,actor)
 for x in [-0.15,0,0.15]: game.block(Vector3(x,0.91,-0.26),Vector3(0.11,0.18,0.1),uniform.darkened(0.2),false,actor)
 for x in [-0.16,0.16]:
  var hip=Node3D.new()
  hip.name="LeftLeg" if x<0 else "RightLeg"
  actor.add_child(hip)
  hip.position=Vector3(x,.7,0)
  game.block(Vector3(0,-.32,0),Vector3(.19,.65,.22),uniform.darkened(.15),false,hip)
  game.block(Vector3(0,-.61,-.06),Vector3(.22,.18,.36),Color("30383a"),false,hip)
  var arm=game.block(Vector3(x*1.8,1.08,-0.1),Vector3(0.17,0.48,0.2),uniform,false,actor)
  arm.rotation.x=-0.75
 var head=SphereMesh.new()
 head.radius=0.2
 head.height=0.44
 mesh(game,actor,Vector3(0,1.55,0),head,Color("b9a78f"))
 var helmet=SphereMesh.new()
 helmet.radius=0.235
 helmet.height=0.32
 mesh(game,actor,Vector3(0,1.72,0),helmet,uniform.darkened(0.15))
 game.block(Vector3(0,1.58,-0.19),Vector3(0.33,0.1,0.06),Color("1b3038"),false,actor)
 game.block(Vector3(0.2,1.18,-0.4),Vector3(0.12,0.13,0.6),Color("253039"),false,actor)

static func tracer(game, origin: Vector3, end: Vector3):
 if game.graphics==0 or origin.distance_to(end)<0.2: return
 var line=MeshInstance3D.new()
 var shape=CylinderMesh.new()
 shape.top_radius=0.012
 shape.bottom_radius=0.006
 shape.height=origin.distance_to(end)
 shape.radial_segments=4
 line.mesh=shape
 var m=StandardMaterial3D.new()
 m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.albedo_color=Color(1,0.8,0.42,0.5)
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 line.material_override=m
 game.world.add_child(line)
 line.global_position=(origin+end)*0.5
 line.quaternion=Quaternion(Vector3.UP,(end-origin).normalized())
 var tween=game.create_tween()
 tween.tween_property(m,"albedo_color:a",0.0,0.06)
 tween.tween_callback(line.queue_free)

static func build_collision_map(game):
 game.navigation=AStarGrid2D.new()
 game.navigation.region=Rect2i(-29,-29,59,59)
 game.navigation.cell_size=Vector2.ONE
 game.navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 game.navigation.update()
 game.block(Vector3(0,-0.5,0),Vector3(60,1,60),Color.WHITE)
 for x in [-30,30]: game.block(Vector3(x,2.5,0),Vector3(1,5,60),Color.WHITE)
 for z in [-30,30]: game.block(Vector3(0,2.5,z),Vector3(60,5,1),Color.WHITE)
 for x in [-19,0,19]:
  for z in [-14,14]:
   game.block(Vector3(x,3,z),Vector3(9,6,8),Color.WHITE)
   game.block(Vector3(x,0.6,z),Vector3(9.1,1.2,8.1),Color.WHITE)
   game.block(Vector3(x,6.15,z),Vector3(9.5,0.3,8.5),Color.WHITE)
   for side in [-1,1]: game.block(Vector3(x,0.1,z+side*4.73),Vector3(10,0.2,1.2),Color.WHITE)
 for x in [-23,-10,10,23]:
  for z in [-5,5]: game.block(Vector3(x,0.9,z),Vector3(3,1.8,3),Color.WHITE)
 for i in range(8): game.block(Vector3(-5+i*1.2,0.15*i,22),Vector3(1.2,0.3*(i+1),4),Color.WHITE)
 if game.map_id==2:
  for x in [-27,27]: game.block(Vector3(x,4,21),Vector3(4,8,4),Color.WHITE)

static func enhance_environment(game):
 # Details remain outside the collision model so clients and server share geometry.
 for x in [-19,0,19]:
  for z in [-14,14]:
   for side in [-1,1]:
    var front=z+side*4.3
    # Entry doors, small projecting balconies and AC vents break up repeated facades.
    game.block(Vector3(x,1.15,front),Vector3(1.25,2.25,0.12),Color("3d5358"),false)
    game.block(Vector3(x+0.4,1.1,front+side*0.09),Vector3(0.07,0.12,0.08),Color("b8af8d"),false)
    for y in [0.25,2.3]: game.block(Vector3(x,y,front),Vector3(1.5,0.08,0.25),Color("a4a392"),false)
    game.block(Vector3(x-2.7,1.5,front+side*0.4),Vector3(2.25,0.12,1.2),Color("819091"),false)
    for w in range(7):
     cylinder(game,game.world,Vector3(x-3.7+w*.33,2,front+side*.93),0.024,1.0,Color("43575f"))
    game.block(Vector3(x-2.7,2.5,front+side*.93),Vector3(2.3,.06,.06),Color("52646a"),false)
    game.block(Vector3(x+3.4,3.1,front+side*.25),Vector3(1,.6,.55),Color("9caaa8"),false)
    for v in range(5): game.block(Vector3(x+3.4,2.9+v*.09,front+side*.55),Vector3(.8,.025,.03),Color("536a70"),false)
    # A translucent glint gives windows varied reflections without costly SSR.
    for w in [-2.7,2.7]:
     for y in [2.4,4.7]:
      var glint=game.block(Vector3(x+w-.3,y+.2,front+side*.04),Vector3(.14,1.0,.015),Color("60828e"),false)
      glint.rotation.z=-.3
 for x in [-28,28]:
  for z in [-9,9]:
   for i in range(4):
    var leaf=SphereMesh.new()
    leaf.radius=.45+i*.04
    leaf.height=.7
    var plant=mesh(game,game.world,Vector3(x+(i%2)*.2,0.45+i*.22,z),leaf,Color("3e684a"))
    plant.add_to_group("visual_detail")
 # Sagging overhead utility cables create silhouettes above the alleys.
 for x in [-11,11]:
  for i in range(12):
   var z=-25+i*4.2
   var a=Vector3(x,6.6-sin(float(i)/12*PI)*1.2,z)
   var b=Vector3(x,6.6-sin(float(i+1)/12*PI)*1.2,z+4.2)
   var wire=cylinder(game,game.world,(a+b)*.5,.018,a.distance_to(b),Color("26363e"))
   wire.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
   wire.add_to_group("visual_detail")
 # Road markings and drains ground the scene at human scale.
 for z in range(-24,28,6):
  game.block(Vector3(9,.015,z),Vector3(.1,.015,2),Color("c5c1a5"),false)
 for x in [-7,7]:
  for z in [-22,22]:
   game.block(Vector3(x,.025,z),Vector3(.8,.02,1),Color("3b474c"),false)
   for v in range(5): game.block(Vector3(x-.3+v*.15,.04,z),Vector3(.04,.02,.85),Color("7c8580"),false)

static func impact(game, pos: Vector3, color: Color, size: float):
 var m=MeshInstance3D.new()
 var sphere=SphereMesh.new()
 sphere.radius=size
 sphere.height=size*2
 m.mesh=sphere
 var material=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.albedo_color=color
 m.material_override=material
 game.world.add_child(m)
 m.global_position=pos
 var t=game.create_tween().set_parallel(true)
 t.tween_property(m,"scale",Vector3.ONE*2.3,.12)
 t.tween_property(material,"albedo_color:a",0.0,.16)
 t.chain().tween_callback(m.queue_free)
