import os, json
from PIL import Image, ImageDraw
# Run from tool/app_icon after `node gen.js` (renders the layers from SVG).
R=os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
full=Image.open('full.png').convert('RGB')
def rs(img,s): return img.resize((s,s),Image.LANCZOS)
dens={'mdpi':1,'hdpi':1.5,'xhdpi':2,'xxhdpi':3,'xxxhdpi':4}
res=f'{R}/android/app/src/main/res'
for d,k in dens.items():
    s=int(48*k)
    t=rs(full,s).convert('RGBA'); m=Image.new('L',(s*4,s*4),0)
    ImageDraw.Draw(m).rounded_rectangle((0,0,s*4-1,s*4-1),s*4*0.2,fill=255)
    t.putalpha(m.resize((s,s),Image.LANCZOS)); t.save(f'{res}/mipmap-{d}/ic_launcher.png',optimize=True)
    a=int(108*k)
    for n in ('bg','fg','mono'):
        img=Image.open(f'{n}.png'); img=img.convert('RGB' if n=='bg' else 'RGBA')
        name={'bg':'ic_launcher_background','fg':'ic_launcher_foreground','mono':'ic_launcher_monochrome'}[n]
        rs(img,a).save(f'{res}/mipmap-{d}/{name}.png',optimize=True)
    os.makedirs(f'{res}/drawable-{d}',exist_ok=True)
    rs(Image.open('notif.png').convert('RGBA'),int(24*k)).save(f'{res}/drawable-{d}/ic_notification.png',optimize=True)
os.makedirs(f'{res}/mipmap-anydpi-v26',exist_ok=True)
open(f'{res}/mipmap-anydpi-v26/ic_launcher.xml','w').write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''')
os.makedirs(f'{res}/raw',exist_ok=True)
open(f'{res}/raw/keep.xml','w').write('''<?xml version="1.0" encoding="utf-8"?>
<!-- The reminder notification names this icon from Dart, so the release
     build must not strip it as unused. -->
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
''')
ios=f'{R}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
for e in json.load(open(f'{ios}/Contents.json'))['images']:
    s=round(float(e['size'].split('x')[0])*int(e['scale'][0]))
    rs(full,s).save(f"{ios}/{e['filename']}",optimize=True)
w=f'{R}/web'
for s in (192,512):
    rs(full,s).save(f'{w}/icons/Icon-maskable-{s}.png',optimize=True)
    t=rs(full,s).convert('RGBA'); m=Image.new('L',(s,s),0); ImageDraw.Draw(m).rounded_rectangle((0,0,s-1,s-1),s*0.2,fill=255); t.putalpha(m)
    t.save(f'{w}/icons/Icon-{s}.png',optimize=True)
rs(full,32).save(f'{w}/favicon.png',optimize=True)
os.makedirs(f'{R}/tool/app_icon',exist_ok=True)
