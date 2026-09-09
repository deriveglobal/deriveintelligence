#!/usr/bin/env bash
# IL_ILCE_7_BAGLA — veri dosyasini saha.js'e BAGLA.
#
# ⚠ NEDEN 5. ADIM ATLADI:
#   saha.js bir <script> etiketiyle yuklenmiyor. app.js:12584'te DINAMIK IMPORT var:
#     const { initSahaSurface } = await import("/shells/saha.js?v=20260722-1505");
#   index.html'de aranacak bir saha.js etiketi HIC YOKTU.
#   Regex'im olmayan seyi aradi ve bulamadi. Kapi dogru raporladi, yanlis yere bakiyordu.
#
# ✅ DOGRU BAGLANTI: saha.js ES modul. tr_il_ilce.js sadece window.* atiyor
#   -> yan-etki importu olarak cekilir: import "/shells/tr_il_ilce.js";
#
# ⚠ VE BIR GUVENLIK KAPISI: veri yuklenmezse SESSIZCE bos liste gelmesin.
#   Bos acilir liste, hatali acilir listeden KOTUDUR — kimse fark etmez.
set -uo pipefail
cd /opt/krb-assessment || exit 1
SJ=shells/saha.js
cp -a "$SJ" "$SJ.bak_bagla"

echo "############ 0) ⚠ CANLI saha.js — YEDEK DEGIL ############"
echo "  dosya: $(pwd)/$SJ  ($(wc -l < $SJ) satir)"
echo
echo "  --- ilk 12 satir (import nereye girecek?) ---"
sed -n '1,12p' "$SJ" | nl -ba | sed 's/^/  /'
echo
echo "  --- ESKI TR_ILLER hala kullaniliyor mu? ---"
grep -n 'TR_ILLER\b' "$SJ" | sed 's/^/  /' || echo "  (yok)"
echo
echo "  --- YENI TR_ILLER_RESMI / TR_IL_ILCE nerede? ---"
grep -n 'TR_ILLER_RESMI\|TR_IL_ILCE' "$SJ" | sed 's/^/  /' || echo "  ❌ HIC YOK — 5. adim arayuzu yamalamadi!"

echo
echo "############ 1) IMPORT EKLE — dosyanin EN BASINA ############"
python3 - <<'PY'
import io, re, sys
p = "shells/saha.js"
s = io.open(p, encoding="utf-8").read()

if 'tr_il_ilce.js' in s:
    print("  ⏭ zaten bagli — atlandi")
    sys.exit(0)

# ⚠ ES modul: import ifadeleri ust seviyede olmali. Dosyanin EN BASINA koyuyorum.
#   tr_il_ilce.js hicbir sey export etmiyor; sadece window.TR_IL_ILCE ve
#   window.TR_ILLER_RESMI atiyor. Yan-etki importu tam da bunun icin var.
sat = (
    '// ⚠ IL_ILCE_BAGLA: resmi il/ilce verisi (81 il · 973 ilce).\n'
    '//   Yan-etki importu — window.TR_IL_ILCE ve window.TR_ILLER_RESMI\'yi doldurur.\n'
    '//   ⚠ Bu satir silinirse acilir listeler BOS gelir. Asagidaki kapi bagirir.\n'
    'import "/shells/tr_il_ilce.js?v=20260714-1";\n'
    '\n'
)
s = sat + s
io.open(p, "w", encoding="utf-8").write(s)
print("  ✅ import eklendi (1. satir)")
PY

echo
echo "############ 2) ⚠ SESSIZ BOSLUK KAPISI ############"
# ⚠ Veri yuklenmezse acilir liste BOS gelir ve KIMSE FARK ETMEZ.
#   Bos liste, yanlis listeden kotudur: yanlis liste sorulur, bos liste "bozuk" sanilir.
#   Bu kapi, veri yoksa KONSOLA BAGIRIR ve ekranda gorunur uyari basar.
python3 - <<'PY'
import io, sys
p = "shells/saha.js"
s = io.open(p, encoding="utf-8").read()

if 'IL_ILCE_KAPI' in s:
    print("  ⏭ kapi zaten var — atlandi")
    sys.exit(0)

# ⚠ ANKRAJ: import satirindan HEMEN sonra. Ezberden degil, dosyadan.
ank = 'import "/shells/tr_il_ilce.js?v=20260714-1";\n'
if ank not in s:
    print("  ❌ ANKRAJ BULUNAMADI — import satiri yok. DURDUM.")
    sys.exit(1)

kapi = ank + '''
// ⚠ IL_ILCE_KAPI: veri gelmediyse SESSIZ KALMA.
//   Bos acilir liste "sistem bozuk" gibi gorunur; sebebi gorunmez.
//   Olcmesi gereken seyi olcmeyen kapi, kapi degil engeldir.
if (!window.TR_ILLER_RESMI || !Array.isArray(window.TR_ILLER_RESMI)
    || window.TR_ILLER_RESMI.length !== 81) {
  console.error("[saha] ❌ RESMI IL VERISI YUKLENMEDI — acilir listeler BOS gelecek.",
                "beklenen: 81 il, gelen:", window.TR_ILLER_RESMI && window.TR_ILLER_RESMI.length);
  window.TR_ILLER_RESMI = window.TR_ILLER_RESMI || [];
  window.TR_IL_ILCE    = window.TR_IL_ILCE    || {};
}
'''
s = s.replace(ank, kapi, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("  ✅ kapi eklendi — veri yoksa konsola BAGIRIR")
PY

echo
echo "############ 3) SOZDIZIMI ############"
node --check "$SJ" 2>&1 | head -5
if node --check "$SJ" >/dev/null 2>&1; then
  echo "  ✅ node --check"
else
  echo "  ❌ SOZDIZIMI BOZUK — GERI ALIYORUM"
  cp -a "$SJ.bak_bagla" "$SJ"; exit 1
fi

echo
echo "############ 4) ⚠ ESKI TR_ILLER — IKI LISTE VAR MI? ############"
echo "  --- kalan TR_ILLER kullanimlari ---"
grep -n 'TR_ILLER\b' "$SJ" | grep -v 'TR_ILLER_RESMI' | sed 's/^/  /' || echo "  ✅ yok — tek liste"
echo "  ⚠ Cikti varsa: iki il listesi var. Hangisi ekranda, kimse bilemez."
echo "     Once ekrani calistir, SONRA olduru. Simdi dokunmuyorum."

echo
echo "############ 5) DAGIT ############"
docker build -t krb-assessment:secure . >/tmp/b.log 2>&1 || { echo "❌ BUILD"; tail -20 /tmp/b.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET /                     -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)"
echo "  GET /shells/saha.js       -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/shells/saha.js)"
echo "  GET /shells/tr_il_ilce.js -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/shells/tr_il_ilce.js)"

echo
echo "############ 6) ⚠ KANIT — tarayiciya giden saha.js veriyi CEKIYOR mu? ############"
echo "  --- servis edilen saha.js'in ilk 8 satiri ---"
curl -s http://localhost:8080/shells/saha.js | head -8 | sed 's/^/  /'
echo
if curl -s http://localhost:8080/shells/saha.js | head -20 | grep -q 'tr_il_ilce.js'; then
  echo "  ✅ EVET — saha.js artik tr_il_ilce.js'i import ediyor"
else
  echo "  ❌ HAYIR — import servis edilen dosyada YOK. Acilir liste BOS."
fi

echo
echo "  --- servis edilen tr_il_ilce.js gercekten 81 il mi? ---"
curl -s http://localhost:8080/shells/tr_il_ilce.js \
  | grep -o '"[A-ZÇĞİÖŞÜ0-9 ]*":' | wc -l | sed 's/^/  il sayisi (TR_IL_ILCE anahtarlari): /'
echo "  ⚠ 81 olmali."

echo
echo "############ 7) ⚠ ILCE LISTESI — KOCAELİ dogru mu? ############"
curl -s http://localhost:8080/shells/tr_il_ilce.js \
  | python3 -c "
import sys, re, json
s = sys.stdin.read()
m = re.search(r'window\.TR_IL_ILCE\s*=\s*(\{.*?\});', s, re.S)
d = json.loads(m.group(1))
print('  il sayisi :', len(d))
print('  ilce top. :', sum(len(v) for v in d.values()))
print('  KOCAELİ   :', ', '.join(d.get('KOCAELİ', ['❌ YOK'])))
print('  SAKARYA   :', ', '.join(d.get('SAKARYA', ['❌ YOK'])[:6]), '...')
print('  DÜZCE     :', ', '.join(d.get('DÜZCE',   ['❌ YOK'])))
assert len(d) == 81, '❌ 81 il degil'
print('  ✅ 81 il dogrulandi')
"

echo
echo "############ SONUC ############"
echo "  ⚠ 6) ✅ ise: Eftal telefonda sayfayi YENILEYIP il acilir listesini gormeli."
echo "  ⚠ Sunucu kapisi zaten calisiyor (Yeşilova -> 400). Arayuz bozulsa bile veri KIRLENMEZ."
echo "  ⚠ Geri donus: shells/saha.js.bak_bagla"
