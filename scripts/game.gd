extends Node3D

const Actor = preload("res://scripts/actor.gd")
const WEAPONS = [
 {"name":"Вектор • пистолет", "damage":25.0,"rate":0.24,"mag":12,"reload":1.3,"spread":0.012},
 {"name":"Рубеж • автомат", "damage":30.0,"rate":0.11,"mag":30,"reload":2.0,"spread":0.022},
 {"name":"Грань • снайперская", "damage":85.0,"rate":1.1,"mag":5,"reload":2.8,"spread":0.002},
 {"name":"Вихрь • ПП", "damage":19.0,"rate":0.07,"mag":35,"reload":1.7,"spread":0.035},
 {"name":"Гром • дробовик", "damage":16.0,"rate":0.8,"mag":7,"reload":2.4,"spread":0.09}]
var actors: Array = []
var player
var world: Node3D
var ui: CanvasLayer
var menu: PanelContainer
var hud: Label
var board: Label
var notice: Label
var scores = [0,0]
var remaining = 180.0
var active = false
var mode = 0
var map_id = 0
var team = 0
var difficulty = 1
var sensitivity = 0.0025
var button_scale = 1.0
var money = 3000
var elapsed = 0.0
var kills = 0
var deaths = 0
var volume = 0.25
var rng = RandomNumberGenerator.new()
var navigation: AStarGrid2D
var touch_layer: Control
var match_mode=0
var match_team=0

func _ready():
 rng.randomize()
 load_settings()
 setup_inputs()
 ui = CanvasLayer.new()
 add_child(ui)
 hud = label_at(Vector2(24,20),24)
 board = label_at(Vector2(430,140),22)
 board.visible = false
 notice = label_at(Vector2(420,70),24)
 var cross = label_at(Vector2(631,340),26)
 cross.text = "+"
 show_menu()

func setup_inputs():
 var keys = {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"crouch":KEY_CTRL,"sprint":KEY_SHIFT,"reload":KEY_R,"score":KEY_TAB,"buy":KEY_B,"knife":KEY_3,"grenade":KEY_G}
 for action in keys:
  if not InputMap.has_action(action): InputMap.add_action(action)
  var e = InputEventKey.new()
  e.physical_keycode = keys[action]
  InputMap.action_add_event(action,e)

func label_at(pos: Vector2, size: int) -> Label:
 var l = Label.new()
 l.position = pos
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_shadow_color",Color.BLACK)
 l.add_theme_constant_override("shadow_outline_size",4)
 ui.add_child(l)
 return l

func option(box: VBoxContainer, title: String, values: Array, callback: Callable):
 var l = Label.new()
 l.text = title
 box.add_child(l)
 var o = OptionButton.new()
 for v in values: o.add_item(v)
 o.item_selected.connect(callback)
 box.add_child(o)
 return o

func slider(box: VBoxContainer, title: String, low: float, high: float, value: float, callback: Callable):
 var l = Label.new()
 l.text = title
 box.add_child(l)
 var s = HSlider.new()
 s.min_value=low
 s.max_value=high
 s.step=(high-low)/100.0
 s.value=value
 s.value_changed.connect(callback)
 box.add_child(s)

func show_menu():
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if is_instance_valid(menu): menu.queue_free()
 menu=PanelContainer.new()
 menu.position=Vector2(440,90)
 menu.custom_minimum_size=Vector2(400,520)
 ui.add_child(menu)
 var b=VBoxContainer.new()
 b.add_theme_constant_override("separation",9)
 menu.add_child(b)
 var title=Label.new()
 title.text="РУБЕЖ / GAME FOR ME"
 title.add_theme_font_size_override("font_size",28)
 b.add_child(title)
 var maps=option(b,"Карта",["Портовый квартал","Цех 17","Песчаный форт"],func(i): map_id=i)
 maps.selected=map_id
 var modes=option(b,"Режим",["Командный бой","Каждый сам за себя"],func(i): mode=i)
 modes.selected=mode
 var teams=option(b,"Команда",["Дозор","Искра"],func(i): team=i)
 teams.selected=team
 option(b,"Боты",["Новичок","Боец","Ветеран"],func(i): difficulty=i).selected=difficulty
 slider(b,"Чувствительность",0.001,0.006,sensitivity,func(v): sensitivity=v)
 slider(b,"Звук",0,1,volume,func(v): volume=v)
 slider(b,"Размер сенсорных кнопок",0.7,1.4,button_scale,func(v): button_scale=v)
 var play=Button.new()
 play.text="Начать матч" if not active else "Продолжить"
 play.pressed.connect(func():
  save_settings()
  menu.queue_free()
  if not active: start_match()
  else:
   get_tree().paused=false
   Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
 b.add_child(play)
 if active:
  var restart=Button.new()
  restart.text="Новый матч с выбранными параметрами"
  restart.pressed.connect(func(): menu.queue_free(); get_tree().paused=false; start_match())
  b.add_child(restart)
 menu.process_mode=Node.PROCESS_MODE_ALWAYS

func material(color: Color, metal: float=0.0) -> StandardMaterial3D:
 var m=StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=0.8
 m.metallic=metal
 return m

func block(pos: Vector3, size: Vector3, color: Color, collision: bool=true, parent: Node=null):
 var body=StaticBody3D.new() if collision else Node3D.new()
 (world if parent==null else parent).add_child(body)
 body.position=pos
 var mesh=MeshInstance3D.new()
 var shape=BoxMesh.new()
 shape.size=size
 mesh.mesh=shape
 mesh.material_override=material(color)
 body.add_child(mesh)
 if collision:
  var c=CollisionShape3D.new()
  var s=BoxShape3D.new()
  s.size=size
  c.shape=s
  body.add_child(c)
  if navigation!=null and parent==null and size.y>0.5 and pos.y>0:
   for x in range(int(floor(pos.x-size.x/2-0.6)),int(ceil(pos.x+size.x/2+0.6))+1):
    for z in range(int(floor(pos.z-size.z/2-0.6)),int(ceil(pos.z+size.z/2+0.6))+1):
     var cell=Vector2i(x,z)
     if navigation.is_in_boundsv(cell): navigation.set_point_solid(cell)
 return body

func start_match():
 if is_instance_valid(world):
  remove_child(world)
  world.queue_free()
 actors.clear()
 world=Node3D.new()
 add_child(world)
 scores=[0,0]
 kills=0
 deaths=0
 money=3000
 elapsed=0
 remaining=180
 active=true
 match_mode=mode
 match_team=team
 notice.text="Магазин: B • покупка первые 12 секунд"
 if is_instance_valid(touch_layer): touch_layer.queue_free()
 build_map()
 for i in range(8):
  var a=Actor.new()
  a.game=self
  a.team=team if i==0 else i%2
  a.human=i==0
  world.add_child(a)
  actors.append(a)
  if i==0: player=a
  a.respawn()
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 if OS.has_feature("android"): touch_controls()

func build_map():
 navigation=AStarGrid2D.new()
 navigation.region=Rect2i(-29,-29,59,59)
 navigation.cell_size=Vector2.ONE
 navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 navigation.update()
 var palettes=[Color("879caa"),Color("62767a"),Color("c9a66b")]
 var base=palettes[map_id]
 var env=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("9bb8ca")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("c9d7e5")
 env.environment.ambient_light_energy=0.65
 world.add_child(env)
 var sun=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-50,-35,0)
 sun.light_color=Color("ffe1b0")
 sun.light_energy=1.3
 sun.shadow_enabled=true
 world.add_child(sun)
 block(Vector3(0,-0.5,0),Vector3(60,1,60),base.darkened(0.35))
 for x in [-30,30]: block(Vector3(x,3,0),Vector3(1,6,60),base)
 for z in [-30,30]: block(Vector3(0,3,z),Vector3(60,6,1),base)
 for x in [-19,0,19]:
  for z in [-14,14]:
   block(Vector3(x,3,z),Vector3(9,6,8),base)
   block(Vector3(x,6.15,z),Vector3(9.5,0.3,8.5),base.darkened(0.5))
   for w in [-2,2]:
    block(Vector3(x+w,3.5,z-4.03),Vector3(1.3,1.5,0.1),Color("28485b"),false)
   block(Vector3(x,0.1,z-4.7),Vector3(10,0.2,1),base.lightened(0.15))
 for x in [-23,-10,10,23]:
  for z in [-5,5]:
   block(Vector3(x,0.9,z),Vector3(3,1.8,3),base.darkened(0.2))
   block(Vector3(x,1.85,z),Vector3(3.15,0.12,3.15),Color("b2a17d"),false)
 for i in range(8):
  block(Vector3(-5+i*1.2,0.15*i,22),Vector3(1.2,0.3*(i+1),4),base)
 for z in [-24,24]:
  for x in [-25,-12,12,25]:
   block(Vector3(x,2.5,z),Vector3(0.16,5,0.16),Color("34424a"))
   block(Vector3(x,5,z),Vector3(1.2,0.2,0.5),Color("ffdda0"),false)
 if map_id==1:
  for x in [-26,26]:
   block(Vector3(x,3,0),Vector3(2,6,7),Color("d68b33"))
 if map_id==2:
  for x in [-27,27]: block(Vector3(x,4,20),Vector3(4,8,4),base)

func spawn_position(t: int) -> Vector3:
 for attempt in range(100):
  var pos=Vector3(rng.randf_range(-25,25),2,(-25 if t==0 else 25)+rng.randf_range(-2,2))
  if match_mode==1: pos=Vector3(rng.randf_range(-26,26),2,rng.randf_range(-26,26))
  if not navigation.is_point_solid(Vector2i(roundi(pos.x),roundi(pos.z))): return pos
 return Vector3(0,2,-25 if t==0 else 25)

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
 var start=Vector2i(clampi(roundi(from.x),-29,29),clampi(roundi(from.z),-29,29))
 var end=Vector2i(clampi(roundi(to.x),-29,29),clampi(roundi(to.z),-29,29))
 if navigation.is_point_solid(start) or navigation.is_point_solid(end): return PackedVector2Array()
 return navigation.get_point_path(start,end)

func save_settings():
 var c=ConfigFile.new()
 c.set_value("controls","sensitivity",sensitivity)
 c.set_value("controls","button_scale",button_scale)
 c.set_value("audio","volume",volume)
 c.save("user://settings.cfg")

func load_settings():
 var c=ConfigFile.new()
 if c.load("user://settings.cfg")==OK:
  sensitivity=c.get_value("controls","sensitivity",0.0025)
  button_scale=c.get_value("controls","button_scale",1.0)
  volume=c.get_value("audio","volume",0.25)

func _process(delta):
 if not active: return
 elapsed+=delta
 remaining-=delta
 hud.text="ДОЗОР %d  :  %d ИСКРА     %02d:%02d\nЗдоровье %d   Броня %d   ₽%d\n%s   %d / %d\nR перезарядка • B магазин • G граната • Tab счёт" % [scores[0],scores[1],int(remaining)/60,int(remaining)%60,maxi(0,int(player.hp)),int(player.armor),money,WEAPONS[player.weapon].name,player.ammo,player.reserve]
 board.visible=Input.is_action_pressed("score")
 if board.visible:
  board.text="ИГРОК          УБИЙСТВА / СМЕРТИ\n"
  for i in range(actors.size()): board.text+=("Вы" if i==0 else "Бот %d"%i)+"                %d / %d\n"%[actors[i].frags,actors[i].deaths]
 if remaining<=0 or scores.max()>=40: finish_match()
 if elapsed>12 and notice.text.begins_with("Магазин"): notice.text=""

func _unhandled_input(e):
 if e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE and active:
  get_tree().paused=true
  show_menu()
 if not active or get_tree().paused: return
 if e is InputEventKey and e.pressed:
  if e.keycode==KEY_1: player.equip(0)
  if e.keycode==KEY_2: player.equip(1)
  if e.keycode==KEY_B: shop()

func shop():
 if elapsed>12:
  notice.text="Покупка доступна первые 12 секунд матча"
  return
 var panel=PanelContainer.new()
 panel.position=Vector2(450,180)
 ui.add_child(panel)
 var box=VBoxContainer.new()
 panel.add_child(box)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for i in range(WEAPONS.size()):
  var b=Button.new()
  b.text=WEAPONS[i].name+" — ₽1000"
  b.pressed.connect(func():
   if money>=1000:
    money-=1000
    player.equip(i)
    player.ammo=WEAPONS[i].mag
   panel.queue_free()
   Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
  box.add_child(b)
 var close=Button.new()
 close.text="Закрыть"
 close.pressed.connect(func(): panel.queue_free(); Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
 box.add_child(close)

func finish_match():
 active=false
 notice.text="Матч завершён! "+("Ничья" if scores[0]==scores[1] else ("Победа Дозора" if scores[0]>scores[1] else "Победа Искры"))
 if match_mode==1:
  var winner=actors[0]
  for a in actors:
   if a.frags>winner.frags: winner=a
  notice.text="Матч завершён! Победитель: "+("Вы" if winner.human else "Бот")+" • %d убийств"%winner.frags
 show_menu()

func died(victim, killer):
 victim.deaths+=1
 if is_instance_valid(killer):
  killer.frags+=1
  scores[killer.team]+=1
  if killer.human: money+=300

func effect(pos: Vector3, color: Color, size: float=0.15):
 var m=MeshInstance3D.new()
 var s=SphereMesh.new()
 s.radius=size
 s.height=size*2
 m.mesh=s
 m.material_override=material(color)
 world.add_child(m)
 m.global_position=pos
 var tween=create_tween()
 tween.tween_property(m,"scale",Vector3.ONE*0.05,0.18)
 tween.tween_callback(m.queue_free)

func sound():
 var stream=AudioStreamWAV.new()
 stream.format=AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate=22050
 var bytes=PackedByteArray()
 bytes.resize(4400)
 for i in range(2200):
  var sample=int(rng.randf_range(-1,1)*18000*exp(-float(i)/240))
  bytes.encode_s16(i*2,sample)
 stream.data=bytes
 var a=AudioStreamPlayer.new()
 a.stream=stream
 a.volume_db=linear_to_db(maxf(0.001,volume))
 world.add_child(a)
 a.finished.connect(a.queue_free)
 a.play()

func touch_controls():
 touch_layer=Control.new()
 touch_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
 ui.add_child(touch_layer)
 var hint=Label.new()
 hint.text="◉\nДвижение: левая часть экрана"
 hint.position=Vector2(35,510)
 touch_layer.add_child(hint)
 var names=["ОГОНЬ","ПРИЦЕЛ","ПРЫЖОК","ПРИСЕСТЬ","ПЕРЕЗАРЯДКА","ОРУЖИЕ","БЕГ","ГРАНАТА"]
 for i in range(names.size()):
  var b=Button.new()
  b.text=names[i]
  b.position=Vector2(990+(i%2)*130,370+(i/2)*75)
  b.size=Vector2(120,65)*button_scale
  touch_layer.add_child(b)
  b.button_down.connect(func(): player.touch_action(i,true))
  b.button_up.connect(func(): player.touch_action(i,false))
 var pause=Button.new()
 pause.text="ПАУЗА"
 pause.position=Vector2(1120,15)
 touch_layer.add_child(pause)
 pause.pressed.connect(func(): get_tree().paused=true; show_menu())
