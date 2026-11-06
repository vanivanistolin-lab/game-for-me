extends Control
var game
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_dt):
 queue_redraw()
func _draw():
 if not is_instance_valid(game) or not game.active or not game.training.reveal_bots: return
 var camera=game.player.camera
 for a in game.actors:
  if a==game.player or a.hp<=0: continue
  if game.match_mode==0 and a.team==game.player.team: continue
  var top=a.global_position+Vector3.UP*1.95
  if camera.is_position_behind(top): continue
  var head=camera.unproject_position(top)
  var feet=camera.unproject_position(a.global_position)
  var height=clampf(feet.y-head.y,12,300)
  var rect=Rect2(head-Vector2(height*.22,0),Vector2(height*.44,height))
  var color=Color("f2a85e")
  draw_rect(rect,color,false,1.5)
  draw_line(rect.position-Vector2(4,0),rect.position+Vector2(-4,height),Color("243137"),3)
  draw_line(rect.position+Vector2(-4,height),rect.position+Vector2(-4,height*(1-a.hp/100.0)),Color("8edaa1"),3)
  draw_string(ThemeDB.fallback_font,head+Vector2(-20,-8),"БОТ · %d м"%int(game.player.global_position.distance_to(a.global_position)),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
