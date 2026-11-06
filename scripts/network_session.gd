extends Node

const PROTOCOL=3
const MAX_PLAYERS=8
var game
var online=false
var is_host=false
var dedicated=false
var admin_id=0
var admin_secret=""
var pending_secret=""
var nickname="Игрок"
var last_address=""
var status="Не подключено"
var players={}
var entities={}
var bot_count=2
var epoch=0
var snapshot_clock=0.0
var input_clock=0.0
var round_delay=0.0
var sequence=0
var last_sequences={}
var input_windows={}
var command_windows={}
var auth_windows={}
var last_snapshot_msec=0
var applying_snapshot=false
var rejected_admin_requests=0
var net_panel: PanelContainer
var diagnostics={"snapshots":0,"inputs":0}

func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS
 var preferences=ConfigFile.new()
 if preferences.load("user://settings.cfg")==OK:
  nickname=str(preferences.get_value("network","nickname","Игрок"))
  last_address=str(preferences.get_value("network","address",""))
 multiplayer.peer_disconnected.connect(_peer_left)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(func(): leave("Не удалось подключиться. Проверьте адрес; бесплатный сервер может запускаться около минуты."))
 multiplayer.server_disconnected.connect(func(): leave("Соединение с сервером закрыто."))

func host(port: int=24567, headless: bool=false) -> Error:
 leave("")
 var peer=WebSocketMultiplayerPeer.new()
 var bind_address=OS.get_environment("GAME_BIND_ADDRESS") if headless and not OS.get_environment("GAME_BIND_ADDRESS").is_empty() else "*"
 var result=peer.create_server(port,bind_address)
 if result!=OK:
  set_status("Не удалось открыть порт %d"%port)
  return result
 multiplayer.multiplayer_peer=peer
 online=true
 is_host=true
 dedicated=headless
 admin_id=0 if headless else 1
 admin_secret=OS.get_environment("GAME_ADMIN_TOKEN") if headless else ""
 if not headless: players[1]={"nick":nickname,"team":game.team}
 game.reset_training()
 game.start_match()
 set_status("Сервер запущен. Порт %d. Администратор: %s"%[port,"владелец хостинга" if headless else "вы"])
 return OK

func join_server(address: String, nick: String, key: String="") -> Error:
 leave("")
 var url=address.strip_edges()
 if url.begins_with("https://"): url="wss://"+url.trim_prefix("https://")
 elif url.begins_with("http://"): url="ws://"+url.trim_prefix("http://")
 if not (url.begins_with("ws://") or url.begins_with("wss://")):
  set_status("Адрес должен начинаться с ws:// или wss://")
  return ERR_INVALID_PARAMETER
 if not key.is_empty() and url.begins_with("ws://") and not (url.begins_with("ws://127.0.0.1:") or url.begins_with("ws://localhost:")):
  set_status("Для входа с паролем администратора используйте защищённый wss:// адрес")
  return ERR_INVALID_PARAMETER
 nickname=clean_name(nick)
 last_address=url
 game.save_settings()
 pending_secret=key
 var peer=WebSocketMultiplayerPeer.new()
 var result=peer.create_client(url)
 if result!=OK:
  pending_secret=""
  set_status("Не удалось начать подключение")
  return result
 multiplayer.multiplayer_peer=peer
 online=true
 is_host=false
 game.active=false
 game.reset_training()
 set_status("Подключение… Бесплатный сервер после простоя запускается не сразу.")
 return OK

func _connected():
 hello.rpc_id(1,PROTOCOL,nickname)
 if not pending_secret.is_empty():
  claim_admin.rpc_id(1,pending_secret)
  pending_secret=""

func clean_name(value: String) -> String:
 var text=value.strip_edges().replace("\n"," ").replace("\r"," ").replace("[","").replace("]","").left(24)
 return "Игрок" if text.is_empty() else text

func set_status(text: String):
 status=text
 if is_instance_valid(game.notice): game.notice.text=text

func leave(message: String="Отключено"):
 online=false
 is_host=false
 admin_id=0
 players.clear()
 entities.clear()
 last_sequences.clear()
 input_windows.clear()
 command_windows.clear()
 auth_windows.clear()
 pending_secret=""
 admin_secret=""
 last_snapshot_msec=0
 if multiplayer.multiplayer_peer!=null:
  multiplayer.multiplayer_peer.close()
  multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
 get_tree().paused=false
 if not message.is_empty():
  game.active=false
  set_status(message)
  if not game.dedicated and is_instance_valid(game.ui): game.show_menu()

func allowed(bucket: Dictionary, id: int, limit: int) -> bool:
 var now=Time.get_ticks_msec()
 var entry=bucket.get(id,{"start":now,"count":0})
 if now-int(entry.start)>1000:
  entry={"start":now,"count":0}
 entry.count+=1
 bucket[id]=entry
 return entry.count<=limit

@rpc("any_peer","call_remote","reliable")
func hello(protocol: int, nick: String):
 if not online or not is_host: return
 var id=multiplayer.get_remote_sender_id()
 if players.has(id): return
 if protocol!=PROTOCOL or players.size()>=MAX_PLAYERS:
  multiplayer.multiplayer_peer.disconnect_peer(id)
  return
 var counts=[0,0]
 for member in players.values(): counts[int(member.team)]+=1
 players[id]={"nick":clean_name(nick),"team":0 if counts[0]<=counts[1] else 1}
 spawn_entity(id,players[id].team,players[id].nick)
 world_info.rpc_id(id,epoch,game.map_id,game.match_mode,bot_count)
 send_snapshot()

func populate():
 entities.clear()
 epoch+=1
 round_delay=0
 for id in players:
  spawn_entity(id,int(players[id].team),str(players[id].nick))
 for i in range(bot_count): spawn_entity(-i-1,i%2,"Бот %d"%(i+1))
 if multiplayer.get_peers().size()>0:
  world_info.rpc(epoch,game.map_id,game.match_mode,bot_count)
 send_snapshot()

func spawn_entity(id: int, faction: int, nick: String):
 var actor=game.Actor.new()
 actor.game=game
 actor.entity_id=id
 actor.peer_id=id if id>0 else 0
 actor.display_name=nick
 actor.team=faction
 actor.human=not dedicated and id==multiplayer.get_unique_id()
 actor.name="Entity_%d"%id
 game.world.add_child(actor)
 game.actors.append(actor)
 entities[id]=actor
 if actor.human:
  game.player=actor
  game.money=actor.cash
 actor.respawn()
 return actor

@rpc("authority","call_remote","reliable")
func world_info(round_id: int, map: int, mode: int, bots: int):
 if is_host or not online: return
 epoch=round_id
 game.map_id=clampi(map,0,2)
 game.mode=clampi(mode,0,1)
 bot_count=bots
 entities.clear()
 game.start_match()
 if is_instance_valid(game.menu): game.menu.queue_free()
 set_status("Подключено. F8 — сервер и администрация")

func send_snapshot():
 if not is_host or multiplayer.get_peers().is_empty(): return
 var state=[]
 for id in entities:
  var a=entities[id]
  state.append({"id":id,"team":a.team,"nick":a.display_name,"pos":a.position,"yaw":a.rotation.y,"pitch":a.pitch,"hp":a.hp,"armor":a.armor,"weapon":a.weapon,"ammo":a.ammo,"reserve":a.reserve,"frags":a.frags,"deaths":a.deaths,"cash":a.cash,"reload":a.reload_time,"dead":a.dead_time,"grenades":a.grenades})
 snapshot.rpc(epoch,game.remaining,game.elapsed,game.scores,admin_id,game.active,state)

@rpc("authority","call_remote","reliable")
func snapshot(round_id: int, time_left: float, elapsed: float, score: Array, owner: int, running: bool, state: Array):
 if is_host or not online or round_id!=epoch: return
 last_snapshot_msec=Time.get_ticks_msec()
 diagnostics.snapshots+=1
 game.remaining=time_left
 game.elapsed=elapsed
 game.scores=score
 game.active=running
 admin_id=owner
 var present={}
 players.clear()
 for entry in state:
  var id=int(entry.id)
  present[id]=true
  if id>0: players[id]={"nick":entry.nick,"team":entry.team}
  var actor=entities.get(id)
  if not is_instance_valid(actor): actor=spawn_entity(id,entry.team,entry.nick)
  actor.target_position=entry.pos
  if actor.position.distance_to(entry.pos)>4: actor.position=entry.pos
  if not actor.human: actor.rotation.y=entry.yaw
  var respawned=actor.hp<=0 and entry.hp>0
  if actor.human and respawned:
   actor.rotation.y=entry.yaw
   actor.pitch=entry.pitch
  actor.hp=entry.hp
  actor.armor=entry.armor
  actor.ammo=entry.ammo
  actor.reserve=entry.reserve
  actor.frags=entry.frags
  actor.deaths=entry.deaths
  actor.cash=entry.cash
  actor.reload_time=entry.reload
  actor.dead_time=entry.dead
  actor.grenades=entry.grenades
  actor.visible=actor.hp>0 or actor.human
  actor.collision_layer=2 if actor.hp>0 else 0
  if actor.weapon!=entry.weapon:
   applying_snapshot=true
   actor.equip(entry.weapon)
   applying_snapshot=false
  if actor.human: game.money=actor.cash
 for id in entities.keys():
  if not present.has(id): remove_entity(id)
 if is_instance_valid(game.player) and is_instance_valid(game.hud):
  game.hud.visible=true
  game.crosshair.visible=running
 if not running and is_instance_valid(game.notice): game.notice.text="Матч завершён. Следующий раунд через несколько секунд."

func remove_entity(id: int):
 if entities.has(id):
  var actor=entities[id]
  game.actors.erase(actor)
  actor.queue_free()
  entities.erase(id)

func _peer_left(id: int):
 if not online or not is_host: return
 players.erase(id)
 remove_entity(id)
 last_sequences.erase(id)
 input_windows.erase(id)
 command_windows.erase(id)
 auth_windows.erase(id)
 if admin_id==id: admin_id=0
 send_snapshot()

func sanitized_input(raw: Dictionary) -> Dictionary:
 var direction=raw.get("move",Vector2.ZERO)
 if not direction is Vector2 or not is_finite(direction.x) or not is_finite(direction.y): direction=Vector2.ZERO
 var yaw=raw.get("yaw",0.0)
 var pitch=raw.get("pitch",0.0)
 if not (yaw is float or yaw is int) or not is_finite(float(yaw)): yaw=0.0
 if not (pitch is float or pitch is int) or not is_finite(float(pitch)): pitch=0.0
 var clean={"move":direction.limit_length(1),"yaw":wrapf(float(yaw),-PI,PI),"pitch":clampf(float(pitch),-1.4,1.4)}
 for key in ["fire","aim","sprint","crouch","jump","reload","grenade","knife"]:
  clean[key]=raw.get(key,false) is bool and raw.get(key,false)
 return clean

@rpc("any_peer","call_remote","reliable")
func submit_input(seq: int, raw: Dictionary):
 if not is_host or not online or not game.active: return
 var id=multiplayer.get_remote_sender_id()
 if not entities.has(id) or not allowed(input_windows,id,50): return
 if seq<=int(last_sequences.get(id,-1)): return
 last_sequences[id]=seq
 entities[id].network_input=sanitized_input(raw)
 entities[id].input_received_at=Time.get_ticks_msec()
 diagnostics.inputs+=1

func transmit_input(raw: Dictionary):
 if not online or is_host or not is_instance_valid(game.player): return
 sequence+=1
 submit_input.rpc_id(1,sequence,raw)

func request_action(action: String, value: int=0):
 if is_host: execute_action(1,action,value)
 elif online: player_action.rpc_id(1,action,value)

@rpc("any_peer","call_remote","reliable")
func player_action(action: String, value: int=0):
 if not is_host or not online: return
 var id=multiplayer.get_remote_sender_id()
 if not allowed(command_windows,id,12): return
 execute_action(id,action,value)

func execute_action(id: int, action: String, value: int):
 if not entities.has(id) or not game.active: return
 var a=entities[id]
 if a.hp<=0: return
 match action:
  "equip":
   if value in a.unlocked: a.equip(value)
  "buy":
   if game.elapsed<=12 and value>=0 and value<game.WEAPONS.size() and a.cash>=1000:
    if value not in a.unlocked:
     a.cash-=1000
     a.unlocked.append(value)
     a.equip(value)
     a.ammo=game.WEAPONS[value].mag
    else: a.equip(value)
  "reload": a.reload_weapon()
  "grenade": a.grenade()
  "knife": a.knife()

func admin_action(action: String, value: int=0):
 if is_host: execute_admin(1,action,value)
 elif online: admin_command.rpc_id(1,action,value)

@rpc("any_peer","call_remote","reliable")
func admin_command(action: String, value: int=0):
 if not is_host or not online: return
 var id=multiplayer.get_remote_sender_id()
 if allowed(command_windows,id,12): execute_admin(id,action,value)

func execute_admin(id: int, action: String, value: int):
 if id!=admin_id or not players.has(id):
  rejected_admin_requests+=1
  if id!=1: message.rpc_id(id,"Нет прав администратора")
  return
 match action:
  "map":
   if value<0 or value>2: return
   game.map_id=value
   game.start_match()
  "mode":
   if value<0 or value>1: return
   game.mode=value
   game.start_match()
  "restart": game.start_match()
  "bots":
   bot_count=clampi(value,0,6)
   game.start_match()
  "kick":
   if value!=id and players.has(value):
    multiplayer.multiplayer_peer.disconnect_peer(value)
    _peer_left(value)
 send_snapshot()

@rpc("any_peer","call_remote","reliable")
func claim_admin(key: String):
 if not is_host or not dedicated: return
 var id=multiplayer.get_remote_sender_id()
 if not players.has(id) or not allowed(auth_windows,id,3): return
 if key.length()<16 or key.length()>256 or admin_secret.length()<16:
  message.rpc_id(id,"Пароль администратора неверен или не задан на сервере")
  return
 if Crypto.new().constant_time_compare(key.to_utf8_buffer(),admin_secret.to_utf8_buffer()):
  admin_id=id
  message.rpc_id(id,"Вы вошли как администратор. F8 — панель сервера.")
  send_snapshot()
 else: message.rpc_id(id,"Пароль администратора неверен")

@rpc("authority","call_remote","reliable")
func message(text: String): set_status(text)

func is_admin() -> bool:
 return online and admin_id==multiplayer.get_unique_id()

func publish_shot(actor, origin: Vector3, end: Vector3):
 if not online or not is_host: return
 shot_fx.rpc(actor.entity_id,origin,end)

@rpc("authority","call_remote","reliable")
func shot_fx(id: int, origin: Vector3, end: Vector3):
 if not entities.has(id): return
 var a=entities[id]
 if a.human:
  a.recoil+=0.012
  a.cooldown=game.WEAPONS[a.weapon].rate
  game.sound()
 if not game.dedicated:
  game.Visuals.tracer(game,origin,end)
  game.effect(end,Color("ffd289"),.1)

func end_round():
 if not is_host: return
 game.active=false
 round_delay=8
 send_snapshot()

func _process(dt):
 if not online: return
 if is_host:
  if round_delay>0:
   round_delay-=dt
   if round_delay<=0: game.start_match()
  snapshot_clock+=dt
  if snapshot_clock>=0.075:
   snapshot_clock=0
   send_snapshot()
 elif last_snapshot_msec>0 and Time.get_ticks_msec()-last_snapshot_msec>20000:
  leave("Сервер не отвечает")

func show_panel():
 if is_instance_valid(net_panel): return
 net_panel=PanelContainer.new()
 net_panel.theme=game.interface_theme
 net_panel.process_mode=Node.PROCESS_MODE_ALWAYS
 net_panel.position=Vector2(455,35)
 net_panel.custom_minimum_size=Vector2(650,650)
 game.ui.add_child(net_panel)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var scroll=ScrollContainer.new()
 scroll.custom_minimum_size=Vector2(600,610)
 net_panel.add_child(scroll)
 var box=VBoxContainer.new()
 box.custom_minimum_size.x=570
 box.add_theme_constant_override("separation",7)
 scroll.add_child(box)
 var title=Label.new()
 title.text="СЕТЕВАЯ ИГРА / АДМИНИСТРАТОР"
 box.add_child(title)
 var info=Label.new()
 info.text=status.left(90)
 info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 box.add_child(info)
 var name_field=LineEdit.new()
 name_field.placeholder_text="Ваш ник"
 name_field.text=nickname
 box.add_child(name_field)
 var address=LineEdit.new()
 address.placeholder_text="wss://ваш-сервер.onrender.com или ws://IP:24567"
 address.text=last_address
 box.add_child(address)
 var key=LineEdit.new()
 key.secret=true
 key.placeholder_text="Пароль администратора (только для владельца)"
 box.add_child(key)
 var connect_button=Button.new()
 connect_button.text="Подключиться к серверу"
 connect_button.pressed.connect(func():
  join_server(address.text,name_field.text,key.text)
  key.text=""
  net_panel.queue_free())
 box.add_child(connect_button)
 if not online:
  var deploy=Button.new()
  deploy.text="Бесплатный сервер • открыть Render"
  deploy.pressed.connect(func(): OS.shell_open("https://render.com/deploy?repo=https://github.com/vanivanistolin-lab/game-for-me"))
  box.add_child(deploy)
  var create=Button.new()
  create.text="Создать локальный сервер • вы администратор"
  create.pressed.connect(func():
   nickname=clean_name(name_field.text)
   host()
   if is_instance_valid(game.menu): game.menu.queue_free()
   net_panel.queue_free())
  box.add_child(create)
 if is_admin():
  for map in range(3):
   var button=Button.new()
   button.text="Карта: "+["Портовый квартал","Цех 17","Песчаный форт"][map]
   button.pressed.connect(func(): admin_action("map",map); net_panel.queue_free())
   box.add_child(button)
  var mode_button=Button.new()
  mode_button.text="Режим: "+("Командный → FFA" if game.match_mode==0 else "FFA → Командный")
  mode_button.pressed.connect(func(): admin_action("mode",1-game.match_mode); net_panel.queue_free())
  box.add_child(mode_button)
  var restart=Button.new()
  restart.text="Перезапустить матч"
  restart.pressed.connect(func(): admin_action("restart"); net_panel.queue_free())
  box.add_child(restart)
  var bot_button=Button.new()
  bot_button.text="Боты: %d → %d (перезапуск)"%[bot_count,(bot_count+2)%8]
  bot_button.pressed.connect(func(): admin_action("bots",(bot_count+2)%8); net_panel.queue_free())
  box.add_child(bot_button)
  var target=OptionButton.new()
  for id in players:
   if id!=admin_id:
    target.add_item(str(players[id].nick),id)
  box.add_child(target)
  var kick=Button.new()
  kick.text="Исключить выбранного игрока"
  kick.disabled=target.item_count==0
  kick.pressed.connect(func():
   if target.item_count>0: admin_action("kick",target.get_selected_id())
   net_panel.queue_free())
  box.add_child(kick)
 if online:
  var disconnect=Button.new()
  disconnect.text="Отключиться"
  disconnect.pressed.connect(func(): leave(); net_panel.queue_free())
  box.add_child(disconnect)
 var close=Button.new()
 close.text="Закрыть"
 close.pressed.connect(func():
  net_panel.queue_free()
  if game.active and not is_instance_valid(game.menu): Input.mouse_mode=Input.MOUSE_MODE_CAPTURED)
 box.add_child(close)
 box.move_child(close,1)

@rpc("authority","call_remote","reliable")
func explosion(pos: Vector3):
 game.effect(pos,Color("ff742e"),2)
