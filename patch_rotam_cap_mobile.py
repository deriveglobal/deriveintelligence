# -*- coding: utf-8 -*-
# ROTAM_CAP_V1 (saha.js) — Başlangıç noktası YOKKEN, tüm portföyü "bugünkü duraklar" diye
#   dökme sorunu. Güne makul bir varsayılan (CAP0=12 en öncelikli + bugün planlılar) öner;
#   kalanı "Bekleyen" olarak ayrı göster. Başlangıç belirlenince (path 2) gerçek mesafe-rota
#   zaten güne sığdırıyor. Yalnız mobil, rep dalı.
import sys
F = sys.argv[1]
s = open(F, encoding="utf-8").read()
if "ROTAM_CAP_V1" in s:
    print("[skip] zaten yamali:", F); sys.exit(0)

o = '''      const cards = [...commits, ...rest].map((c, i) => card(c, i + 1, c.plan_bugun ? "commit" : tier(c.skor), null));
      box.innerHTML = CSS + `<div class="rt">
        <div class="rt-hd"><div class="t">🌅 Sabah Rotam</div><div class="rt-live"><span class="dot"></span>CANLI</div></div>
        <div class="rt-sub">${bugunTarih} · ${durak.length} durak</div>
        <div class="rt-setp"><div class="t">🏁 Başlangıç noktanı belirle</div>
          <div class="p">Rotanı mesafeye göre sıralayıp güne kaç durak sığdığını hesaplayabilmem için nereden başladığını bilmem gerek.</div>
          ${ob ? `<div class="sug">📍 Öneri: son check-in konumun — burayı başlangıç yapayım mı?</div>` : `<div class="sug">📍 Şu an neredeysen oradan başla.</div>`}
          <div class="btns">${ob ? `<button class="btn pri" id="rt-kabul">✓ Evet, burayı kullan</button>` : ""}<button class="btn${ob ? "" : " pri"}" id="rt-checkin">📍 Buradan başla</button></div>
        </div>
        <div class="rt-sech">Bugünkü duraklar <span class="cnt">· öncelik</span></div>
        ${durak.length ? `<div class="rt-route">${cards.join("")}</div>` : `<div class="rt-empty">Portföyünde durak yok.</div>`}
      </div>`;'''

n = '''      const CAP0 = 12;  /* ROTAM_CAP_V1 — başlangıç yokken güne makul öneri; kalanı bekleyen */
      const sugg0 = rest.slice(0, Math.max(0, CAP0 - commits.length));
      const backlog0 = rest.slice(sugg0.length);
      const today0 = [...commits, ...sugg0];
      const cards = today0.map((c, i) => card(c, i + 1, c.plan_bugun ? "commit" : tier(c.skor), null));
      const backCards0 = backlog0.map((c, i) => card(c, today0.length + i + 1, tier(c.skor), null));
      box.innerHTML = CSS + `<div class="rt">
        <div class="rt-hd"><div class="t">🌅 Sabah Rotam</div><div class="rt-live"><span class="dot"></span>CANLI</div></div>
        <div class="rt-sub">${bugunTarih} · bugün ${today0.length}${backlog0.length ? ` · ${backlog0.length} bekliyor` : ""}</div>
        <div class="rt-setp"><div class="t">🏁 Başlangıç noktanı belirle</div>
          <div class="p">Rotanı mesafeye göre sıralayıp güne <b>tam</b> kaç durak sığdığını hesaplayabilmem için nereden başladığını bilmem gerek. O zamana kadar en öncelikli ${CAP0} durağı öneriyorum.</div>
          ${ob ? `<div class="sug">📍 Öneri: son check-in konumun — burayı başlangıç yapayım mı?</div>` : `<div class="sug">📍 Şu an neredeysen oradan başla.</div>`}
          <div class="btns">${ob ? `<button class="btn pri" id="rt-kabul">✓ Evet, burayı kullan</button>` : ""}<button class="btn${ob ? "" : " pri"}" id="rt-checkin">📍 Buradan başla</button></div>
        </div>
        <div class="rt-sech">Bugün önerilen <span class="cnt">· en öncelikli ${today0.length}</span></div>
        ${today0.length ? `<div class="rt-route">${cards.join("")}</div>` : `<div class="rt-empty">Portföyünde durak yok.</div>`}
        ${backlog0.length ? `<div class="rt-over">⏭ Bekleyen (${backlog0.length}) — başlangıç noktanı belirleyince güne dağıtırım</div><div class="rt-route">${backCards0.join("")}</div>` : ""}
      </div>`;'''

assert s.count(o) == 1, "anchor=%d" % s.count(o)
s = s.replace(o, n, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] ROTAM_CAP_V1 (saha.js) — başlangıçsız günde CAP0=12 öneri + bekleyen")
