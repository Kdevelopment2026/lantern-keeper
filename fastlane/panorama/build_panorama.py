#!/usr/bin/env python3
"""Builds the six-panel App Store panorama for Lantern Keeper.

Reads the raw 1320x2868 simulator captures in fastlane/screenshots/raw and the
hero photo, writes panorama.html, renders it with headless Chrome at 7920x2868,
slices it into six 1320x2868 panels in fastlane/screenshots/en-GB, and prints a
geometry report (text boxes inside their panel, no overlaps).

    python3 fastlane/panorama/build_panorama.py
"""
import base64, json, os, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "fastlane/screenshots/raw"
OUT = ROOT / "fastlane/screenshots/en-GB"
HERE = pathlib.Path(__file__).resolve().parent
PANEL_W, H = 1320, 2868
N = 6
W = PANEL_W * N
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Palette and type from the app's design system.
NIGHT, DEEP, HORIZON, MOON, MIST, LANTERN, DAWN, INK = "#06141D", "#0A2630", "#244651", "#DCE7E9", "#91A8AD", "#F3C969", "#E79A72", "#10232A"

def data_uri(path, mime):
    return f"data:{mime};base64," + base64.b64encode(pathlib.Path(path).read_bytes()).decode()

hero_path = HERE / "hero.jpg"
hero = data_uri(hero_path, "image/png" if hero_path.read_bytes()[:4] == b"\x89PNG" else "image/jpeg") if hero_path.exists() else None
newyork = (HERE / ".newyork.b64").read_text().strip()

# Panels 2..6: screen, headline (3-5 words, {chip} marks the chip word), pop-out html.
PANELS = [
    dict(shot="harbour", headline="Begin your {watch} tonight.",
         pop=("card", """<div class="k">Keep watch until</div><div class="big mono">7:42</div><div class="s">8 hrs from now · one tap</div>""")),
    dict(shot="prompt", headline="Face {down}. Light on.",
         pop=("glass", """<div class="ico">⟲</div><div><div class="k2">Turn it over for a second</div><div class="s">or tap the visible Start button</div></div>""")),
    dict(shot="active", headline="Lock it. {Leave} it.",
         pop=("card", """<div class="k">The light is on</div><div class="big mono">5 hrs left</div><div class="s">Runs on the clock while locked</div>""")),
    dict(shot="morning", headline="Morning, not {metrics}.",
         pop=("card", """<div class="k">Watch kept for</div><div class="big mono">8 hrs</div><div class="chips"><span>Clear</span><span class="on">Steady</span><span>Tired</span></div>""")),
    dict(shot="logbook", headline="A quiet {logbook}.",
         pop=("card", """<div class="k">Last seven nights</div><div class="ships"><svg class="boat" viewBox="0 0 24 24"><path d="M3 15h18l-2.2 4H5.2z"/><path d="M12 3v11H5z"/><path d="M12.5 5l6 9h-6z" opacity=".7"/></svg><svg class="boat" viewBox="0 0 24 24"><path d="M3 15h18l-2.2 4H5.2z"/><path d="M12 3v11H5z"/><path d="M12.5 5l6 9h-6z" opacity=".7"/></svg><svg class="boat" viewBox="0 0 24 24"><path d="M3 15h18l-2.2 4H5.2z"/><path d="M12 3v11H5z"/><path d="M12.5 5l6 9h-6z" opacity=".7"/></svg><span class="ring"></span><svg class="boat" viewBox="0 0 24 24"><path d="M3 15h18l-2.2 4H5.2z"/><path d="M12 3v11H5z"/><path d="M12.5 5l6 9h-6z" opacity=".7"/></svg><span class="dot"></span><span class="dot"></span></div><div class="s">34 hrs 15 min kept · no streaks</div>""")),
]

# Phone placement: each phone sits in the right half of its panel and crosses the
# seam into the next panel. Scale 0.70 of 1320x2868; rotation alternates.
SCALE = 0.70
PH_W, PH_H = PANEL_W * SCALE, H * SCALE
BEZEL = 26

def headline_html(text):
    import re
    # Keep the chip and any punctuation that follows it on one line.
    return re.sub(r"\{([^}]+)\}([.,!?]*)", r'<span class="nowrap"><span class="chip">\1</span>\2</span>', text)

phones, texts = [], []
for i, p in enumerate(PANELS):
    panel = i + 1                      # 0 is the hero
    x0 = panel * PANEL_W
    cx = x0 + PANEL_W - 300            # crosses the seam on the right
    if panel == N - 1:
        cx = x0 + PANEL_W - 560        # last panel: stay inside the canvas
    rot = -6 if panel % 2 else 6
    top = 1010
    left = cx - PH_W / 2
    shot = data_uri(RAW / f"{p['shot']}.png", "image/png")
    phones.append(f"""
    <div class="phone" style="left:{left:.0f}px;top:{top}px;transform:rotate({rot}deg)">
      <div class="screen"><img src="{shot}"></div>
    </div>""")
    kind, inner = p["pop"]
    pop_top = 2050 if panel == N - 1 else 1500
    texts.append(f"""
    <div class="headline" data-panel="{panel}" style="left:{x0 + 96}px;top:170px">{headline_html(p['headline'])}</div>
    <div class="pop {kind}" data-panel="{panel}" style="left:{x0 + 96}px;top:{pop_top}px">{inner}</div>""")

hero_block = f'<img class="hero" src="{hero}">' if hero else '<div class="hero placeholder"></div>'

html = f"""<!doctype html>
<meta charset="utf-8">
<style>
@font-face {{ font-family: "NY"; src: url(data:font/ttf;base64,{newyork}); }}
* {{ box-sizing: border-box; margin: 0; }}
html, body {{ width: {W}px; height: {H}px; overflow: hidden; background: {NIGHT}; }}
body {{ position: relative; font-family: -apple-system, "SF Pro Text", system-ui, sans-serif; color: {MOON}; }}
.sky {{ position: absolute; inset: 0; background: linear-gradient(180deg, {NIGHT} 0%, {DEEP} 68%, {HORIZON} 100%); }}
.glow {{ position: absolute; left: 0; right: 0; top: 1750px; height: 1300px;
         background: radial-gradient(ellipse 60% 50% at 50% 50%, rgba(243,201,105,0.22), rgba(243,201,105,0) 70%); }}
.stars {{ position: absolute; inset: 0; }}
.star {{ position: absolute; border-radius: 50%; background: {MOON}; }}
.hero {{ position: absolute; left: 0; top: 0; width: {PANEL_W + 120}px; height: {H}px; object-fit: cover;
         -webkit-mask-image: linear-gradient(90deg, #000 78%, transparent 100%); mask-image: linear-gradient(90deg, #000 78%, transparent 100%); }}
.hero.placeholder {{ background: radial-gradient(circle at 60% 55%, {LANTERN} 0, {HORIZON} 14%, {NIGHT} 60%); }}
.hero-shade {{ position: absolute; left: 0; top: 0; width: {PANEL_W}px; height: {H}px;
               background: linear-gradient(180deg, rgba(6,20,29,0.55) 0%, rgba(6,20,29,0) 28%, rgba(6,20,29,0) 55%, rgba(6,20,29,0.9) 100%); }}
.wordmark {{ position: absolute; left: 96px; top: 150px; font-family: "NY", "New York", Georgia, serif; font-size: 72px; color: {MOON}; letter-spacing: 0.5px; }}
.wordmark small {{ display: block; font-family: -apple-system, system-ui, sans-serif; font-size: 36px; color: {MIST}; margin-top: 12px; letter-spacing: 0; }}
.headline {{ position: absolute; width: {PANEL_W - 192}px; font-family: "NY", "New York", Georgia, serif; font-weight: 700;
             font-size: 148px; line-height: 1.06; color: {MOON}; letter-spacing: -1px; text-wrap: balance; }}
.hero-head {{ top: 2010px; }}
.nowrap {{ white-space: nowrap; }}
.chip {{ display: inline-block; background: {LANTERN}; color: {INK}; padding: 0 34px 10px; border-radius: 30px;
         transform: rotate(-3deg); line-height: 1.02; }}
.sub {{ position: absolute; left: 96px; width: {PANEL_W - 192}px; top: 2440px; font-size: 52px; line-height: 1.3; color: {MIST}; }}
.phone {{ position: absolute; width: {PH_W + BEZEL*2:.0f}px; height: {PH_H + BEZEL*2:.0f}px; border-radius: {200*SCALE + BEZEL:.0f}px;
          background: linear-gradient(160deg, #7f8790 0%, #3b434a 35%, #202830 60%, #6a737c 100%);
          padding: {BEZEL}px; box-shadow: 0 60px 140px rgba(0,0,0,0.65), inset 0 0 0 3px rgba(255,255,255,0.18); transform-origin: 50% 40%; }}
.phone::after {{ content: ""; position: absolute; inset: {BEZEL - 6}px; border-radius: {200*SCALE + 6:.0f}px; border: 6px solid #0a0d10; pointer-events: none; }}
.screen {{ width: 100%; height: 100%; border-radius: {200*SCALE:.0f}px; overflow: hidden; background: #000; }}
.screen img {{ width: 100%; height: 100%; display: block; }}
.pop {{ position: absolute; width: 700px; padding: 40px 46px; border-radius: 40px; color: {MOON};
        transform: rotate(-2deg); box-shadow: 0 40px 90px rgba(0,0,0,0.55); }}
.pop.card {{ background: {DEEP}; border: 2px solid rgba(145,168,173,0.35); }}
.pop.glass {{ background: rgba(10,38,48,0.62); border: 2px solid rgba(220,231,233,0.35); backdrop-filter: blur(30px);
              -webkit-backdrop-filter: blur(30px); display: flex; gap: 28px; align-items: center; }}
.pop .k {{ font-size: 38px; color: {MIST}; }}
.pop .k2 {{ font-size: 44px; color: {MOON}; font-weight: 600; }}
.pop .big {{ font-size: 112px; line-height: 1.1; color: {MOON}; font-weight: 300; margin: 6px 0; }}
.pop .mono {{ font-family: "SF Mono", ui-monospace, Menlo, monospace; font-variant-numeric: tabular-nums; }}
.pop .s {{ font-size: 36px; color: {MIST}; }}
.pop .ico {{ width: 110px; height: 110px; border-radius: 50%; background: {LANTERN}; color: {INK}; font-size: 64px;
             display: flex; align-items: center; justify-content: center; flex: none; }}
.pop .chips {{ display: flex; gap: 16px; margin-top: 18px; }}
.pop .chips span {{ padding: 16px 40px; border-radius: 999px; border: 2px solid rgba(145,168,173,0.6); font-size: 38px; }}
.pop .chips span.on {{ background: {LANTERN}; color: {INK}; border-color: {LANTERN}; }}
.pop .ships {{ display: flex; gap: 22px; align-items: center; margin: 14px 0 10px; height: 60px; }}
.pop .boat {{ width: 54px; height: 54px; fill: {LANTERN}; }}
.pop .ring {{ width: 26px; height: 26px; border-radius: 50%; border: 4px solid {MIST}; }}
.pop .dot {{ width: 12px; height: 12px; border-radius: 50%; background: {HORIZON}; }}
#report {{ display: none; }}
</style>
<div class="sky"></div>
<div class="stars" id="stars"></div>
<div class="glow"></div>
{hero_block}
<div class="hero-shade"></div>
<div class="wordmark">Lantern Keeper<small>Put your phone down. Keep the light on.</small></div>
<div class="headline hero-head" data-panel="0" style="left:96px">{headline_html("Keep the {light} on.")}</div>
<div class="sub" data-panel="0">A calm ritual for the night the scroll won't end.</div>
{''.join(phones)}
{''.join(texts)}
<pre id="report"></pre>
<script>
// ?panel=N renders one 1320-wide panel by shifting the whole canvas left.
const panelParam = new URLSearchParams(location.search).get('panel');
if (panelParam !== null) document.body.style.transform = `translateX(${{-panelParam * {PANEL_W}}}px)`;
// Seeded stars shared by every panel.
let s = 0x1A7E44n;
const unit = () => {{ s = (s * 6364136223846793005n + 1442695040888963407n) % (1n << 64n); return Number(s >> 11n) / 2 ** 53; }};
const stars = document.getElementById('stars');
for (let i = 0; i < 520; i++) {{
  const e = document.createElement('div'); e.className = 'star';
  const r = 1.5 + unit() * 3.5;
  e.style.cssText = `left:${{unit() * {W}}}px;top:${{unit() * {H} * 0.62}}px;width:${{r}}px;height:${{r}}px;opacity:${{0.25 + unit() * 0.6}}`;
  stars.appendChild(e);
}}
// Geometry report: every text element's box and its panel.
document.fonts.ready.then(() => {{
  const items = [];
  for (const el of document.querySelectorAll('.headline, .pop, .sub, .wordmark')) {{
    const b = el.getBoundingClientRect();
    items.push({{ cls: el.className, panel: +(el.dataset.panel ?? 0), x: b.left, y: b.top, w: b.width, h: b.height,
                  text: el.textContent.trim().slice(0, 40) }});
  }}
  for (const el of document.querySelectorAll('.phone')) {{
    const b = el.getBoundingClientRect();
    items.push({{ cls: 'phone', panel: -1, x: b.left, y: b.top, w: b.width, h: b.height, text: '' }});
  }}
  document.getElementById('report').textContent = JSON.stringify(items);
}});
</script>
"""
html_path = HERE / "panorama.html"
html_path.write_text(html)

png = HERE / "panorama.png"
subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1", "--allow-file-access-from-files",
                "--disable-gpu", f"--window-size={W},{H}", f"--screenshot={png}", "--virtual-time-budget=4000",
                f"file://{html_path}"], check=True, capture_output=True)
dom = subprocess.run([CHROME, "--headless=new", "--allow-file-access-from-files", "--disable-gpu", f"--window-size={W},{H}",
                      "--virtual-time-budget=4000", "--dump-dom", f"file://{html_path}"], check=True, capture_output=True, text=True).stdout
start = dom.index('<pre id="report">') + len('<pre id="report">')
report = json.loads(dom[start:dom.index("</pre>", start)].replace("&quot;", '"'))

# Checks: text boxes stay inside their panel with a 60px margin; text boxes never overlap each other.
problems = []
texts_only = [r for r in report if r["cls"] != "phone"]
for r in texts_only:
    px0 = r["panel"] * PANEL_W
    if r["x"] < px0 + 60 or r["x"] + r["w"] > px0 + PANEL_W - 60 or r["y"] < 60 or r["y"] + r["h"] > H - 60:
        problems.append(f"panel {r['panel']+1}: '{r['text']}' leaves its panel ({r['x']:.0f},{r['y']:.0f} {r['w']:.0f}x{r['h']:.0f})")
for a in texts_only:
    for b in texts_only:
        if a is b or a["panel"] != b["panel"]: continue
        if a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]:
            problems.append(f"panel {a['panel']+1}: '{a['text']}' overlaps '{b['text']}'")
            break

names = ["hero", "harbour", "prompt", "active", "morning", "logbook"]
for i, name in enumerate(names):
    out = OUT / f"iphone69_{i+1:02d}_{name}.png"
    # Exact 1320x2868 render per panel; sips' cropOffset ignores 0,0 and crops from the centre.
    subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1", "--allow-file-access-from-files",
                    "--disable-gpu", f"--window-size={PANEL_W},{H}", f"--screenshot={out}", "--virtual-time-budget=4000",
                    f"file://{html_path}?panel={i}"], check=True, capture_output=True)
for p in sorted(OUT.glob("iphone69_*.png")):
    if p.name not in {f"iphone69_{i+1:02d}_{n}.png" for i, n in enumerate(names)}:
        p.unlink()
print(f"rendered {png} ({W}x{H}), sliced {N} panels into {OUT}")
print("geometry:", "OK" if not problems else "\n  " + "\n  ".join(problems))
sys.exit(1 if problems else 0)
