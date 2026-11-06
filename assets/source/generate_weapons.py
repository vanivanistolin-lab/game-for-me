"""Original procedural weapon meshes. Run using Blender --background --python this_file."""
import bpy,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'models'
ROOT.mkdir(parents=True,exist_ok=True)
def mat(name,color,metal,rough):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=rough
 return m
steel=mat('blued steel',(.075,.1,.12),.8,.3)
frame=mat('black polymer',(.055,.07,.075),.05,.65)
tan=mat('ceramic sand finish',(.36,.30,.20),.25,.5)
edge=mat('brushed steel',(.26,.30,.31),.8,.27)
glass=mat('optic coating',(.02,.23,.27),.6,.17)
rubber=mat('grip rubber',(.035,.04,.04),0,.9)
def box(name,pos,dim,material,bevel=.012,rotation=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]),rotation=rotation)
 o=bpy.context.object;o.name=name;o.dimensions=(dim[0],dim[2],dim[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(material)
 mod=o.modifiers.new('Manufactured rounded edges','BEVEL');mod.width=bevel;mod.segments=3
 mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def tube(name,pos,radius,length,material):
 # Blender Y forward becomes Godot -Z after glTF axis conversion.
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=length,location=(pos[0],-pos[2],pos[1]),rotation=(math.pi/2,0,0))
 o=bpy.context.object;o.name=name;o.data.materials.append(material)
 for f in o.data.polygons: f.use_smooth=True
 b=o.modifiers.new('Rim bevel','BEVEL');b.width=.004;b.segments=2
 o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
for index in range(5):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 pistol=index==0
 length=.32 if pistol else (.64 if index==2 else .48)
 box('Receiver',(0,0,0),(.13,.15,length),tan if index in [1,2] else steel)
 box('Trigger grip',(0,-.16,.12),(.085,.22,.13),rubber,.018)
 box('Trigger guard',(0,-.105,.015),(.075,.025,.14),steel,.007)
 box('Trigger guard front',(0,-.07,-.06),(.075,.08,.025),steel,.005)
 box('Trigger',(0,-.065,.005),(.012,.06,.02),edge,.004)
 box('Ejection port',(.066,.015,-.02),(.007,.055,.15),frame,.003)
 box('Bolt',(.072,.015,-.005),(.008,.025,.08),edge,.002)
 barrel_start=-length/2-.13
 barrel_length=.16 if pistol else (.48 if index==2 else .27)
 tube('Barrel',(0,0,barrel_start),.022,barrel_length,steel)
 tube('Muzzle brake',(0,0,barrel_start-barrel_length/2),.033,.08,frame)
 tube('Dark bore',(0,0,barrel_start-barrel_length/2-.041),.018,.003,rubber)
 if not pistol:
  box('Handguard',(0,0,-length/2-.10),(.13,.15,.25),tan if index==1 else frame)
  box('Stock spine',(0,0,length/2+.14),(.08,.09,.25),steel)
  box('Adjustable stock',(0,-.025,length/2+.29),(.13,.20,.22),tan if index in [1,2] else frame)
  box('Shoulder pad',(0,-.03,length/2+.41),(.14,.22,.025),rubber,.006)
  for i in range(7):
   box('Cooling vent',(.066,.01,-length/2-.02-i*.027),(.005,.045,.014),rubber,.002)
   box('Rail tooth',(0,.083,.16-i*.05),(.105,.018,.024),edge,.002)
  for i in range(4):
   box('Magazine section',(0,-.12-i*.045,.02-i*.012),(.085,.065,.14),frame,.008)
  for x in [-.032,.032]: box('Magazine groove',(x,-.20,-.065),(.009,.17,.006),edge,.002)
 else:
  for i in range(7): box('Slide serration',(.068,.025,.055+i*.015),(.005,.09,.006),frame,.001)
 box('Rear sight',(0,.095,length*.35),(.09,.045,.025),steel,.003)
 box('Front sight',(0,.10,-length*.5),(.025,.055,.025),steel,.002)
 if index==2:
  for z in [-.17,.09]: box('Scope mount',(0,.13,z),(.065,.10,.06),steel)
  tube('Scope',(0,.2,-.07),.055,.42,frame)
  tube('Scope objective',(0,.2,-.29),.068,.06,steel)
  tube('Scope lens',(0,.2,-.322),.055,.003,glass)
  box('Scope elevation dial',(0,.26,-.02),(.055,.04,.06),frame,.006)
 if index==4:
  tube('Magazine tube',(0,-.075,-.35),.025,.48,steel)
  box('Pump',(0,-.025,-.34),(.14,.14,.24),tan,.025)
  for i in range(6): box('Pump groove',(0,-.09,-.25-i*.033),(.14,.008,.01),rubber,.002)
 if index==3:
  box('Extended magazine',(0,-.27,.01),(.065,.29,.09),steel)
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(ROOT/f'weapon-{index}.glb'),export_format='GLB',export_apply=True,export_yup=True)
print('Five original bevelled weapon models exported')
