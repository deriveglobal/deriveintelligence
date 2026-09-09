#!/usr/bin/env python3
# FINANS_SIPARIS_REVERT_V2 — V1 revert'inin UI kalıntılarını temizle:
#  (1) Ekranda görünen kod yorumu "/* FINANS_SIPARIS_REVERT_V1 */" -> HTML yorumu (kullanıcıya sızmaz).
#  (2) Body: iç tablo.kolon jargonu (bi_stok_durumu.siparis_miktar) kaldırıldı.
#  (3) Meta: "Nasıl: siparis_miktar·bi_stok_durumu" -> "kaynak doğrulanıyor"; "Dönem: bağlanacak" -> "—" (vaat yok).
#  (4) Ölü client çağrısı _setSmall('gSiparis',...) kaldırıldı (id V1'de silinmişti).
# Idempotent (V2 marker varsa SKIP), .bak, count==1 assert.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/finans.html"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()

if "FINANS_SIPARIS_REVERT_V2" in src:
    print("SKIP (zaten V2)"); sys.exit(0)

reps = [
 # (1)+(2) body satırı: görünen marker + tablo.kolon jargonu temizlendi
 ('<div class="v num">— <small>/* FINANS_SIPARIS_REVERT_V1 */</small></div><div class="plain">Sipariş bekleyen — kaynak (bi_stok_durumu.siparis_miktar) ERP anlamı doğrulanana kadar bağlanmadı.</div>',
  '<div class="v num">—<!-- FINANS_SIPARIS_REVERT_V2 --></div><div class="plain">Sipariş bekleyen — kaynağın ERP anlamı doğrulanana kadar bağlanmadı.</div>'),
 # (3) meta Nasıl + Dönem satırları (Neden dokunulmadı)
 ('<div class="meta"><div class="r"><span class="t">Nasıl</span><span class="x num">siparis_miktar · bi_stok_durumu</span></div>\n             <div class="r"><span class="t">Dönem</span><span class="x">bağlanacak</span></div>',
  '<div class="meta"><div class="r"><span class="t">Nasıl</span><span class="x">kaynak doğrulanıyor</span></div>\n             <div class="r"><span class="t">Dönem</span><span class="x">—</span></div>'),
 # (4) ölü client çağrısı (id yok -> no-op) kaldır
 ("       _setSmall('gSiparis',(sp.deger==null?'—':fmtM(sp.deger)),'M ₺');\n",
  ""),
]
for old, new in reps:
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}) for: {old[:60]!r}"

bak = PATH + ".bak_siparisrevert2_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
for old, new in reps:
    src = src.replace(old, new)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: 4 temizlik uygulandi")
print("V2 marker:", src.count("FINANS_SIPARIS_REVERT_V2"),
      "| gorunur V1 comment kalan(0):", src.count("/* FINANS_SIPARIS_REVERT_V1 */"),
      "| gSiparis kalan(0):", src.count("gSiparis"),
      "| baglanacak kalan(0):", src.count(">bağlanacak<"))
