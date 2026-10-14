"""Package captured native Home pixels; no artwork painting or synthesis."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import base64, json, hashlib
import numpy as np

import sys
OUT = Path(sys.argv[1]).resolve()
heroes = ['bumblebeefullbody', 'optimus']
font = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 24)
small = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 18)
frames = {h:[Image.open(OUT/f'frames/{h}-{i:03}.ppm').convert('RGB') for i in range(54)] for h in heroes}
report = {'native_frames':108, 'scheduled_action_ms':600, 'physical_latency_measured':False, 'heroes':{}}
for h in heroes:
    idle = np.array(frames[h][0])
    # Status/battery pixels and return-to-idle are checked against native output.
    same_idle = all(np.array_equal(idle,np.array(frames[h][i])) for i in list(range(12))+list(range(33,54)))
    stable_chrome = all(np.array_equal(idle[:64],np.array(im)[:64]) and
                        np.array_equal(idle[399:],np.array(im)[399:]) for im in frames[h])
    assert same_idle and stable_chrome
    report['heroes'][h] = {'exact_idle_return':same_idle, 'status_and_battery_unchanged':stable_chrome,
                           'idle_jpeg_sha256':hashlib.sha256((OUT/f'fitted/{h}-0.jpg').read_bytes()).hexdigest()}
    for i, im in enumerate(frames[h]): im.save(OUT/f'frames/{h}-{i:03}.png')

combined=[]
for i in range(54):
    im=Image.new('RGB',(964,570),'#11171f');draw=ImageDraw.Draw(im)
    draw.text((233,24),'大黄蜂 · 挥手回应',font=font,anchor='mm',fill='white')
    draw.text((731,24),'擎天柱 · 举拳点头',font=font,anchor='mm',fill='white')
    for j,h in enumerate(heroes):im.paste(frames[h][i],(j*498,55))
    state='待机' if i<12 or i>=33 else ('按下 · 即时反馈' if i<15 else '松开 · 角色回应')
    draw.text((482,548),state,font=small,anchor='mm',fill='#96b7ce')
    combined.append(im)
# Fixed palette shared by all frames prevents per-frame colour flicker.
palette=Image.new('RGB',(466*6,466))
for j,(h,i) in enumerate([(h,i) for h in heroes for i in [0,16,23]]):palette.paste(frames[h][i],(j*466,0))
palette=palette.quantize(colors=256)
gif=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in combined]
gif[0].save(OUT/'tap-motion-preview.gif',save_all=True,append_images=gif[1:],duration=[30,30,40]*18,loop=0,optimize=False,disposal=2)

sheet=Image.new('RGB',(466*5,516*2),'#11171f');draw=ImageDraw.Draw(sheet)
for y,h in enumerate(heroes):
    for x,i in enumerate([0,12,16,23,33]):
        sheet.paste(frames[h][i],(x*466,y*516+40))
        draw.text((x*466+233,y*516+20),['待机','按下','动作一','动作二','回位'][x],font=small,anchor='mm',fill='white')
sheet.save(OUT/'keyframes.png')
(OUT/'validation.json').write_text(json.dumps(report,indent=2))

payload={}
for h in heroes:
    payload[h]=[]
    for i in range(54):payload[h].append('data:image/png;base64,'+base64.b64encode((OUT/f'frames/{h}-{i:03}.png').read_bytes()).decode())
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>StopWatch 点击动作样片</title><style>
*{box-sizing:border-box}body{margin:0;background:#10151d;color:#edf2f8;font:16px -apple-system,BlinkMacSystemFont,sans-serif}
main{max-width:1080px;margin:auto;padding:36px 24px}h1{font-size:28px;margin:0 0 12px}p{color:#a9b6c6;line-height:1.7;margin:10px 0 26px}
.row{display:grid;grid-template-columns:1fr 1fr;gap:32px}.hero{text-align:center}.hero h2{font-size:20px;font-weight:600}
canvas{width:100%;max-width:466px;height:auto;background:#000;border-radius:50%;touch-action:none;cursor:pointer;box-shadow:0 0 0 2px #293342}
.state{color:#91b8cd;min-height:24px;margin:18px 0 8px}.history{color:#7f8c9e;font-size:13px;min-height:20px}.controls{display:flex;gap:12px;justify-content:center;margin-top:22px}button{background:#273a50;border:1px solid #47617c;color:white;padding:12px 18px;border-radius:10px;cursor:pointer}
.note{font-size:13px;text-align:center;color:#7f8c9e;margin-top:24px}@media(max-width:720px){.row{grid-template-columns:1fr}main{padding:24px 16px}}</style>
<main><h1>点一下，角色回应你</h1><p>点击角色试试：按下轻缩，松开后做一个招牌动作。连续点击可立即重新触发；拖出中央区域会取消本次点击。</p>
<div class="row"><section class="hero"><h2>大黄蜂 · 挥手回应</h2><canvas width="466" height="466" data-hero="bumblebeefullbody" aria-label="点击大黄蜂，预览挥手动作"></canvas><div class="state" id="bumblebeefullbody-state">正在加载</div><div class="history" id="bumblebeefullbody-history">尚未点击</div></section>
<section class="hero"><h2>擎天柱 · 举拳点头</h2><canvas width="466" height="466" data-hero="optimus" aria-label="点击擎天柱，预览举拳点头动作"></canvas><div class="state" id="optimus-state">正在加载</div><div class="history" id="optimus-history">尚未点击</div></section></div>
<div class="controls"><button id="demo" disabled>循环演示两位角色</button><button id="stop" disabled>回到待机</button></div>
<p class="note">实际主页像素 · 点击回应约 600ms · 浏览器动作样片<br>此页用于评估动作观感，未测量设备触控延迟或震动。</p></main><script>
const frames=PAYLOAD;let demo=false, nextDemo=0;const actors=[];
function point(e,c){const r=c.getBoundingClientRect();return {x:(e.clientX-r.left)*466/r.width,y:(e.clientY-r.top)*466/r.height}}
const inside=p=>p.x>=64&&p.x<=402&&p.y>=64&&p.y<=398;
Promise.all(Object.entries(frames).map(async([hero,urls])=>{const images=await Promise.all(urls.map(src=>new Promise((resolve,reject)=>{const im=new Image;im.onload=()=>resolve(im);im.onerror=reject;im.src=src})));const c=document.querySelector(`[data-hero="${hero}"]`),ctx=c.getContext('2d'),label=document.getElementById(hero+'-state'),history=document.getElementById(hero+'-history');const a={hero,images,c,ctx,label,history,start:null,press:null,last:-1,count:0,cancelled:0,interrupted:false};actors.push(a);
c.addEventListener('pointerdown',e=>{const p=point(e,c);if(!inside(p)||a.press)return;demo=false;a.interrupted=a.start!==null;a.start=null;a.press={...p,time:performance.now(),id:e.pointerId,cancelled:false};c.setPointerCapture(e.pointerId)});
c.addEventListener('pointermove',e=>{if(!a.press||a.press.id!==e.pointerId)return;const p=point(e,c);if(!inside(p)||Math.hypot(p.x-a.press.x,p.y-a.press.y)>=52)a.press.cancelled=true});
c.addEventListener('pointerup',e=>{if(!a.press||a.press.id!==e.pointerId)return;const p=point(e,c),valid=!a.press.cancelled&&inside(p)&&performance.now()-a.press.time<500&&Math.hypot(p.x-a.press.x,p.y-a.press.y)<52;a.press=null;a.start=valid?performance.now():null;if(valid){a.count++;a.history.textContent=`已回应 ${a.count} 次 · ${a.interrupted?'连点已重启':'本次点击已触发'}`}else{a.cancelled++;a.history.textContent=`已取消 ${a.cancelled} 次 · 本次未触发动作`}if(c.hasPointerCapture(e.pointerId))c.releasePointerCapture(e.pointerId)});
c.addEventListener('pointercancel',()=>{a.press=null;a.start=null});
})).then(()=>{document.querySelectorAll('button').forEach(b=>b.disabled=false);requestAnimationFrame(tick)});
function tick(t){if(demo&&t>=nextDemo){actors.forEach(a=>{a.press=null;a.start=t});nextDemo=t+1800}for(const a of actors){let i=0,text='待机 · 点击中央试试';if(a.press&&!a.press.cancelled){i=12;text='按下 · 即时反馈'}else if(a.press){text='已取消 · 松开回到待机'}else if(a.start!==null){const elapsed=t-a.start;if(elapsed<600){i=15+Math.min(17,Math.floor(elapsed*30/1000));text='回应中 · 再点可重新触发'}else a.start=null}if(i!==a.last){a.ctx.drawImage(a.images[i],0,0);a.last=i}a.label.textContent=text}requestAnimationFrame(tick)}
document.getElementById('demo').onclick=()=>{demo=true;nextDemo=0};document.getElementById('stop').onclick=()=>{demo=false;actors.forEach(a=>{a.press=null;a.start=null})};
</script></html>'''.replace('PAYLOAD',json.dumps(payload))
(OUT/'index.html').write_text(html)
print(json.dumps(report,indent=2))
print('Created GIF, contact sheet and standalone interactive preview.')
