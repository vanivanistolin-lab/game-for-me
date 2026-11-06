"""Create original surface detail maps from the project's own textures (Pillow)."""
from PIL import Image,ImageFilter
from pathlib import Path
import math
root=Path(__file__).resolve().parents[1]/'textures'
for kind in ['plaster','brick','paving','metal','wood','sand']:
 src=Image.open(root/(kind+'.png')).convert('L').filter(ImageFilter.GaussianBlur(.8))
 w,h=src.size;p=src.load();normal=Image.new('RGB',(w,h));n=normal.load();rough=Image.new('L',(w,h));r=rough.load()
 strength=2.4 if kind in ['brick','paving'] else .7
 for y in range(h):
  for x in range(w):
   dx=(p[(x+1)%w,y]-p[(x-1)%w,y])/255*strength
   dy=(p[x,(y+1)%h]-p[x,(y-1)%h])/255*strength
   norm=math.sqrt(dx*dx+dy*dy+1)
   n[x,y]=(int(127.5*(1-dx/norm)),int(127.5*(1+dy/norm)),int(127.5*(1+1/norm)))
   r[x,y]=int(max(70,min(245,(135 if kind=='metal' else 205)+p[x,y]*.15)))
 normal.save(root/(kind+'-normal.png'))
 rough.save(root/(kind+'-roughness.png'))
print('Original normal and roughness maps generated')
