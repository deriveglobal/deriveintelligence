import sys
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "KONTROL_ARA_V1" in s: print("[skip] zaten var"); sys.exit(0)
def rep(old,new,tag):
    global s
    assert s.count(old)==1, "anchor %s count=%d"%(tag,s.count(old))
    s=s.replace(old,new,1); print("[ok]",tag)

# 1) fetch sonrası: filtre değişkenleri + list'i #mus-filtre değerine göre süz
rep(
'''  if (!list.length) { box.innerHTML = ""; return; }
  box.innerHTML = `''',
'''  if (!list.length) { box.innerHTML = ""; return; }
  const _kNorm = x => (x || "").toString().toLocaleUpperCase("tr").replace(/İ/g, "I"); /* KONTROL_ARA_V1 */
  const _kFlt = ((document.getElementById("mus-filtre") || {}).value || "").trim();
  const _kFull = list.length;
  if (_kFlt) { const _kq = _kNorm(_kFlt); list = list.filter(m => _kNorm([m.firma, m.il, m.ilce, m.oneri_firma].join(" ")).indexOf(_kq) >= 0); }
  const _kCap = 60; const _kShown = list.slice(0, _kCap);
  box.innerHTML = `''',
"filter-vars")

# 2) başlık: filtrelenmiş / toplam sayaç
rep(
'''🔎 Kontrol Bekleyen Müşteri (${list.length})</div>''',
'''🔎 Kontrol Bekleyen Müşteri (${list.length}${_kFlt ? ` / ${_kFull}` : ``})</div>''',
"header-count")

# 3) açıklama + boş-durum + map'i _kShown'a çevir
rep(
'''bir müşteriyle aynı olabilir. Karar ver:</div>
      ${list.map(m => `''',
'''bir müşteriyle aynı olabilir. Karar ver:${_kFlt ? ` · “${esc(_kFlt)}” araması` : ``}</div>
      ${!list.length ? `<div style="font-size:12px;color:#b45309;padding:2px 0">Aramaya uyan kontrol kaydı yok.</div>` : ``}
      ${_kShown.map(m => `''',
"map-shown")

# 4) map kapanışına taşma notu
rep(
'''        </div>`).join("")}
    </div>`;''',
'''        </div>`).join("")}
      ${list.length > _kCap ? `<div style="font-size:11px;color:#b45309;text-align:center;padding:4px">…${list.length - _kCap} tane daha — yukarıdaki aramayla daralt</div>` : ``}
    </div>`;''',
"overflow-note")

# 5) arama kutusu -> paneli de süz
rep(
'''    clearTimeout(t); t = setTimeout(() => { yukle(ev.target.value.trim(), 0, false).catch(e => uyari(e.message)); }, 300);''',
'''    clearTimeout(t); t = setTimeout(() => { yukle(ev.target.value.trim(), 0, false).catch(e => uyari(e.message)); try { kontrolPaneliYukle(); } catch (e) {} }, 300); /* KONTROL_ARA_V1 */''',
"input-wire")

open(F,"w",encoding="utf-8").write(s)
print("[done] KONTROL_ARA_V1")
