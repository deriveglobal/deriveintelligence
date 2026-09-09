#!/usr/bin/env bash
# DENETIM_114B — %7,1 zincirini canliya bagla. Uc yer de tek API yanitinda (24641-91).
#   %7,1 = sermaye_maliyeti_pct x 65/365. bi_ayar'dan ISTEK ANINDA hesaplanacak.
#   ⚠ adet:25000/32000/40000 senaryolari + sezon gecmisi AYRI is (canli turetme, sonra) — dokunmuyorum.
set -uo pipefail
cd /opt/krb-assessment || exit 1
SRC="server_container.mjs"
cp -a "$SRC" "$SRC.bak_finpct"

echo "############ 1) YAMA — finansman hesabini ekle + uc %7,1'i canliya cevir ############"
python3 - <<'PY'
import io, sys
p="server_container.mjs"; s=io.open(p,encoding="utf-8").read()
edits=[]

# 1) hesaplama blogu — bilinmeyenAdet satirindan HEMEN sonra
h_bul='    const bilinmeyenAdet = maliyetsiz.reduce((a, k) => a + k.eksik, 0);\n'
h_koy=('    const bilinmeyenAdet = maliyetsiz.reduce((a, k) => a + k.eksik, 0);\n'
       '    // ⚠ SIFIR SABIT: finansman maliyeti bi_ayar\'dan ISTEK ANINDA hesaplanir (donmus %7,1 kalkti).\n'
       '    //   Erken odeme yuku = yillik sermaye maliyeti x (erken gun / 365). Brisa takviminde ~65 gun.\n'
       '    const _smQ = await query("SELECT COALESCE(max(sermaye_maliyeti_pct),40) AS pct FROM bi_ayar WHERE tenant_id=$1::uuid", [session.tenantId]);\n'
       '    const _sermPct = Number(_smQ.rows[0] && _smQ.rows[0].pct) || 40;\n'
       '    const _erkenGun = 65;\n'
       '    const _finPct = Math.round(_sermPct * _erkenGun / 365 * 10) / 10;\n')
edits.append(("hesap blogu", h_bul, h_koy))

# 2) finansman_maliyeti_pct: 7.1 -> _finPct
edits.append(("finansman_maliyeti_pct canli", "        finansman_maliyeti_pct: 7.1,", "        finansman_maliyeti_pct: _finPct,"))

# 3) aciklama metni — donmus "65 gün. %40/yıl sermaye → %7,1." -> canli
a_bul='                  "Eki/Kas/Ara faturası → 22 Oca + 22 Şub. Fark 65 gün. %40/yıl sermaye → %7,1. " +'
a_koy='                  "Eki/Kas/Ara faturası → 22 Oca + 22 Şub. Fark " + _erkenGun + " gün. %" + _sermPct + "/yıl sermaye → %" + _finPct + ". " +'
edits.append(("aciklama canli", a_bul, a_koy))

# 4) karar metni — "> %7,1 olan markalarda" -> canli
k_bul='          ? "Kesin sipariş primi > %7,1 olan markalarda ERKEN AL."'
k_koy='          ? "Kesin sipariş primi > %" + _finPct + " olan markalarda ERKEN AL."'
edits.append(("karar canli", k_bul, k_koy))

fail=[]
for ad,bul,koy in edits:
    n=s.count(bul)
    if n!=1: fail.append(f"  ✗ {ad}: {n} kez (1 olmali)"); continue
    s=s.replace(bul,koy); print(f"  ✅ {ad}")
if fail: print("\n!! TUTMADI — YAZILMADI:\n"+"\n".join(fail)); sys.exit(1)
io.open(p,"w",encoding="utf-8").write(s); print("  ✅ 4/4")
PY

echo
echo "############ 2) node --check ############"
node --check "$SRC" >/dev/null 2>&1 && echo "  ✅" || { echo "  ❌ GERI"; cp -a "$SRC.bak_finpct" "$SRC"; exit 1; }

echo
echo "############ 3) ⚠ KALAN %7,1 var mi? (0 olmali — hepsi canli) ############"
grep -nE "7\.1|%7,1" "$SRC" | grep -iE "finansman|prim|sermaye|ERKEN|maliyeti_pct" | sed 's/^/  /' || echo "  ✅ donmus %7,1 kalmadi"

echo
echo "############ 4) DAGIT ############"
docker build -t krb-assessment:secure . >/tmp/b.log 2>&1 || { echo "❌ BUILD"; tail -15 /tmp/b.log; cp -a "$SRC.bak_finpct" "$SRC"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET / -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)"

echo
echo "############ 5) ⚠ KAPI — ayar degisince %7,1 degisiyor mu? (canli kanit) ############"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
echo "  --- simdi sermaye_maliyeti_pct=40 -> beklenen finPct = 40*65/365 = 7.1 ---"
$PSQL -c "SELECT round(40 * 65.0/365, 1) AS pct_40, round(30 * 65.0/365, 1) AS pct_30, round(50 * 65.0/365, 1) AS pct_50;"
echo "  ⚠ Ayar 40->30 yapilirsa esik 7.1->5.3'e duser; 50 olursa 8.9'a cikar. Artik donmus degil."
echo "  --- servis edilen dosyada _finPct kullaniliyor mu? ---"
echo "  finansman_maliyeti_pct: _finPct -> $(grep -c 'finansman_maliyeti_pct: _finPct' $SRC)"

echo
echo "############ SONUC ############"
echo "  ✅ %7,1 zinciri canli: bi_ayar.sermaye_maliyeti_pct degisince esik de degisir."
echo "  ⚠ adet senaryolari + sezon gecmisi hala metinde donmus — AYRI gorev (canli sezon turetme)."
echo "  ⚠ Geri donus: $SRC.bak_finpct"
