extends Node3D

const NetworkSession = preload("res://scripts/network_session.gd")
const Visuals = preload("res://scripts/visuals.gd")
const TrainingOverlay = preload("res://scripts/training_overlay.gd")
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
var graphics=1
var material_cache={}
var surface_cache={}
var training={"invincible":false,"infinite_ammo":false,"reveal_bots":false,"no_recoil":false}
var training_panel: PanelContainer
var practice_used=false
var status_top: Label
var interface_theme: Theme
var crosshair: Label
var net: Node
var dedicated=false

func _ready():
 rng.randomize()
 load_settings()
 setup_inputs()
 net=NetworkSession.new()
 net.game=self
 net.name="Network"
 add_child(net)
 dedicated=OS.get_environment("GAME_SERVER")=="1" or OS.get_cmdline_user_args().has("--server")
 if dedicated:
  graphics=0
  var port=int(OS.get_environment("PORT")) if not OS.get_environment("PORT").is_empty() else 10000
  net.bot_count=clampi(int(OS.get_environment("GAME_BOTS")),0,6) if not OS.get_environment("GAME_BOTS").is_empty() else 2
  Engine.max_fps=30
  var result=net.host(port,true)
  if result!=OK: get_tree().quit(1)
  else: print("GameForMe server listening on port ",port)
  return
 interface_theme=create_theme()
 ui = CanvasLayer.new()
 add_child(ui)
 hud = label_at(Vector2(26,580),20)
 var backing=StyleBoxFlat.new()
 backing.bg_color=Color(0.025,0.055,0.075,0.85)
 backing.content_margin_left=18
 backing.content_margin_right=18
 backing.content_margin_top=10
 backing.content_margin_bottom=10
 backing.border_width_left=3
 backing.border_color=Color("d4ad67")
 hud.add_theme_stylebox_override("normal",backing)
 status_top=label_at(Vector2(440,20),24)
 board = label_at(Vector2(430,140),22)
 board.visible = false
 notice = label_at(Vector2(420,105),21)
 crosshair=label_at(Vector2(631,340),26)
 crosshair.text="+"
 crosshair.visible=false
 var overlay=TrainingOverlay.new()
 overlay.game=self
 ui.add_child(overlay)
 world=Node3D.new()
 add_child(world)
 build_map()
 var preview=Camera3D.new()
 world.add_child(preview)
 preview.position=Vector3(16,12,26)
 preview.look_at(Vector3(0,2,0))
 preview.current=true
 hud.visible=false
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
 menu.theme=interface_theme
 menu.position=Vector2(55,35)
 menu.custom_minimum_size=Vector2(420,650)
 ui.add_child(menu)
 var scroll=ScrollContainer.new()
 scroll.custom_minimum_size=Vector2(420,610)
 menu.add_child(scroll)
 var b=VBoxContainer.new()
 b.custom_minimum_size.x=365
 b.add_theme_constant_override("separation",8)
 scroll.add_child(b)
 var title=Label.new()
 title.text="РУБЕЖ / 03"
 title.add_theme_font_size_override("font_size",34)
 b.add_child(title)
 var maps=option(b,"Карта",["Портовый квартал","Цех 17","Песчаный форт"],func(i): map_id=i)
 maps.selected=map_id
 var modes=option(b,"Режим",["Командный бой","Каждый сам за себя"],func(i): mode=i)
 modes.selected=mode
 var teams=option(b,"Команда",["Дозор","Искра"],func(i): team=i)
 teams.selected=team
 option(b,"Боты",["Новичок","Боец","Ветеран"],func(i): difficulty=i).selected=difficulty
 option(b,"Графика",["Низкое • без теней","Стандарт • тени","Высокое • сглаживание"],func(i): graphics=i; apply_quality()).selected=graphics
 slider(b,"Чувствительность",0.001,0.006,sensitivity,func(v): sensitivity=v)
 slider(b,"Звук",0,1,volume,func(v): volume=v)
 slider(b,"Размер сенсорных кнопок",0.7,1.4,button_scale,func(v): button_scale=v)
 var play=Button.new()
 play.text="Продолжить" if active or net.online else "Начать матч"
 play.pressed.connect(func():
  save_settings()
  menu.queue_free()
  if not active and not net.online: start_match()
  else:
   get_tree().paused=false
   Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
 b.add_child(play)
 var trainer=Button.new()
 trainer.text="Офлайн-тренировка / F6"
 trainer.pressed.connect(show_training)
 b.add_child(trainer)
 b.move_child(play,1)
 b.move_child(trainer,2)
 var network_button=Button.new()
 network_button.text="Сетевая игра / сервер • F8"
 network_button.pressed.connect(net.show_panel)
 b.add_child(network_button)
 b.move_child(network_button,2)
 if net.online:
  trainer.disabled=true
 if active and not net.online:
  var restart=Button.new()
  restart.text="Новый матч с выбранными параметрами"
  restart.pressed.connect(func(): menu.queue_free(); get_tree().paused=false; start_match())
  b.add_child(restart)
 menu.process_mode=Node.PROCESS_MODE_ALWAYS

func material(color: Color, metal: float=0.0) -> StandardMaterial3D:
 var key=color.to_html()+str(metal)
 if material_cache.has(key): return material_cache[key]
 var m=StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=0.78 if metal==0 else 0.36
 m.metallic=metal
 material_cache[key]=m
 return m

func surface_material(color: Color, texture: String) -> StandardMaterial3D:
 var key=color.to_html()+texture
 if surface_cache.has(key): return surface_cache[key]
 var m=material(color).duplicate()
 m.albedo_texture=load("res://assets/textures/"+texture+".png")
 m.normal_enabled=graphics>0
 m.normal_texture=load("res://assets/textures/"+texture+"-normal.png")
 m.normal_scale=0.65
 m.roughness_texture=load("res://assets/textures/"+texture+"-roughness.png")
 m.roughness=1.0
 m.uv1_triplanar=true
 m.uv1_world_triplanar=true
 m.uv1_scale=Vector3.ONE*0.45
 m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 surface_cache[key]=m
 return m

func apply_quality():
 for material in surface_cache.values(): material.normal_enabled=graphics>0
 get_viewport().msaa_3d=Viewport.MSAA_2X if graphics==2 else Viewport.MSAA_DISABLED
 get_viewport().scaling_3d_scale=0.75 if graphics==0 else 1.0
 if is_instance_valid(world):
  for item in get_tree().get_nodes_in_group("visual_detail"):
   if world.is_ancestor_of(item): item.visible=graphics>0
  for node in world.get_children():
   if node is DirectionalLight3D: node.shadow_enabled=graphics>0
   if node is WorldEnvironment: node.environment.fog_enabled=graphics>0


func block(pos: Vector3, size: Vector3, color: Color, collision: bool=true, parent: Node=null):
 var body=StaticBody3D.new() if collision else Node3D.new()
 (world if parent==null else parent).add_child(body)
 body.position=pos
 if not collision and parent==null: body.add_to_group("visual_detail")
 if not dedicated:
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
 if not dedicated:
  hud.visible=true
  crosshair.visible=true
 practice_used=training.values().has(true)
 scores=[0,0]
 kills=0
 deaths=0
 money=3000
 elapsed=0
 remaining=180
 active=true
 match_mode=mode
 match_team=team
 if not dedicated: notice.text="Магазин: B • покупка первые 12 секунд"
 if is_instance_valid(touch_layer): touch_layer.queue_free()
 build_map()
 if net.online:
  if net.is_host: net.populate()
  if not dedicated: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  return
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
 if dedicated: Visuals.build_collision_map(self)
 else: Visuals.build(self)

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
 c.set_value("graphics","quality",graphics)
 if is_instance_valid(net):
  c.set_value("network","address",net.last_address)
  c.set_value("network","nickname",net.nickname)
 c.save("user://settings.cfg")

func load_settings():
 var c=ConfigFile.new()
 if c.load("user://settings.cfg")==OK:
  sensitivity=c.get_value("controls","sensitivity",0.0025)
  button_scale=c.get_value("controls","button_scale",1.0)
  volume=c.get_value("audio","volume",0.25)
  graphics=clampi(int(c.get_value("graphics","quality",1)),0,2)

func _process(delta):
 if not active: return
 if not net.online or net.is_host:
  elapsed+=delta
  remaining-=delta
  if net.online and (remaining<=0 or score_limit_reached()):
   net.end_round()
   return
 if dedicated or not is_instance_valid(player): return
 if net.online: money=player.cash
 status_top.text="ДОЗОР  %02d    /    %02d  ИСКРА     %02d:%02d"%[scores[0],scores[1],int(remaining)/60,int(remaining)%60]
 hud.text="ЗДОРОВЬЕ %03d   БРОНЯ %02d   ₽%d\n%s    %02d / %03d\nR перезарядка · B магазин · G граната · F6 тренировка"%[maxi(0,int(player.hp)),int(player.armor),money,WEAPONS[player.weapon].name,player.ammo,player.reserve]
 if net.online: hud.text=hud.text.replace("F6 тренировка","F8 сервер")
 if net.online: status_top.text+="\nСЕТЬ · "+("АДМИНИСТРАТОР" if net.is_admin() else "ИГРОК")
 if practice_used: status_top.text+="\nОФЛАЙН-ТРЕНИРОВКА"

 board.visible=Input.is_action_pressed("score")
 if board.visible:
  board.text="ИГРОК          УБИЙСТВА / СМЕРТИ\n"
  for a in actors: board.text+=(a.display_name if net.online else ("Вы" if a.human else "Бот"))+"                %d / %d\n"%[a.frags,a.deaths]
 if not net.online and (remaining<=0 or score_limit_reached()): finish_match()
 if elapsed>12 and notice.text.begins_with("Магазин"): notice.text=""

func _unhandled_input(e):
 if e is InputEventKey and e.pressed and e.keycode==KEY_F8:
  net.show_panel()
  return
 if e is InputEventKey and e.pressed and e.keycode==KEY_F6:
  show_training()
  return
 if e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE and active:
  if not net.online: get_tree().paused=true
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
   if net.online:
    net.request_action("buy",i)
   elif money>=1000:
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
 crosshair.visible=false
 notice.text="Матч завершён! "+("Ничья" if scores[0]==scores[1] else ("Победа Дозора" if scores[0]>scores[1] else "Победа Искры"))
 if match_mode==1:
  var winner=actors[0]
  for a in actors:
   if a.frags>winner.frags: winner=a
  notice.text="Матч завершён! Победитель: "+("Вы" if winner.human else "Бот")+" • %d убийств"%winner.frags
 if practice_used: notice.text="ТРЕНИРОВКА · "+notice.text
 show_menu()

func died(victim, killer):
 victim.deaths+=1
 if is_instance_valid(killer):
  killer.frags+=1
  scores[killer.team]+=1
  if net.online and killer.peer_id>0:
   killer.cash+=300
   if killer.human: money=killer.cash
  elif killer.human: money+=300

func effect(pos: Vector3, color: Color, size: float=0.15):
 if dedicated: return
 Visuals.impact(self,pos,color,size)

func sound():
 if dedicated: return
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
 pause.pressed.connect(func():
  if not net.online: get_tree().paused=true
  show_menu())

func show_training():
 if net.online:
  notice.text="Тренировочные функции доступны только офлайн"
  return
 if is_instance_valid(training_panel): return
 var was_paused=get_tree().paused
 get_tree().paused=true
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 training_panel=PanelContainer.new()
 training_panel.theme=interface_theme
 training_panel.position=Vector2(500,135)
 training_panel.custom_minimum_size=Vector2(430,330)
 training_panel.process_mode=Node.PROCESS_MODE_ALWAYS
 ui.add_child(training_panel)
 var box=VBoxContainer.new()
 training_panel.add_child(box)
 var title=Label.new()
 title.text="ОФЛАЙН-ТРЕНИРОВКА\nВстроенные настройки игры против ботов"
 box.add_child(title)
 var names={"invincible":"Бессмертие","infinite_ammo":"Бесконечные патроны и гранаты","reveal_bots":"Показывать ботов за стенами","no_recoil":"Без отдачи и разброса"}
 for key in names:
  var check=CheckButton.new()
  check.text=names[key]
  check.button_pressed=training[key]
  check.toggled.connect(func(v): training[key]=v; practice_used=practice_used or v)
  box.add_child(check)
 var close=Button.new()
 close.text="Готово"
 close.pressed.connect(func():
  training_panel.queue_free()
  get_tree().paused=was_paused
  if active and not was_paused and not is_instance_valid(menu): Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
 box.add_child(close)

func create_theme() -> Theme:
 var t=Theme.new()
 t.default_font_size=17
 var panel=StyleBoxFlat.new()
 panel.bg_color=Color("13232f")
 panel.content_margin_left=20
 panel.content_margin_right=20
 panel.content_margin_top=18
 panel.content_margin_bottom=18
 panel.border_width_top=3
 panel.border_color=Color("d2ad68")
 panel.corner_radius_bottom_left=8
 panel.corner_radius_bottom_right=8
 t.set_stylebox("panel","PanelContainer",panel)
 for type in ["Button","OptionButton"]:
  for state in ["normal","hover","pressed","focus"]:
   var box=StyleBoxFlat.new()
   box.bg_color=Color("263e4e") if state=="normal" else Color("416071")
   box.content_margin_left=12
   box.content_margin_right=12
   box.content_margin_top=8
   box.content_margin_bottom=8
   box.corner_radius_top_left=4
   box.corner_radius_top_right=4
   box.corner_radius_bottom_left=4
   box.corner_radius_bottom_right=4
   if state=="focus":
    box.border_width_bottom=2
    box.border_color=Color("d2ad68")
   t.set_stylebox(state,type,box)
  t.set_color("font_color",type,Color("e7edf0"))
 return t

func reset_training():
 for key in training: training[key]=false
 practice_used=false
 if is_instance_valid(training_panel): training_panel.queue_free()
 get_tree().paused=false

func control_is_blocked() -> bool:
 return (is_instance_valid(menu) and not menu.is_queued_for_deletion()) or (is_instance_valid(net.net_panel) and not net.net_panel.is_queued_for_deletion())

func score_limit_reached() -> bool:
 if match_mode==0: return scores.max()>=40
 for actor in actors:
  if actor.frags>=40: return true
 return false
