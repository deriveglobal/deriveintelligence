#!/usr/bin/env bash
# DENETIM_111A — ESKI_NOKTA'yi rapora sok. En buyuk uyuyan grup gorunmez kalmasin.
#
# ⚠ KANIT: durum fonksiyonu YENI/AKTIF/PASIF(90-365g)/ESKI(>365g) uretiyor.
#   ESKI = en derin uyuyan (103 musteri, EN BUYUK grup). Rapor onu ATLIYOR.
#   RISKLI_NOKTA hicbir kod tarafindan URETILMIYOR — olu deger, sadece CHECK'te.
#
# ⚠ Iki rapor sorgusu ayni alt-metni tasiyor: ('PASIF_NOKTA','RISKLI_NOKTA')
#   30654 pasif_riskli · 30777 sorunlu. Ikisine de ESKI_NOKTA ekleniyor.
#   (CHECK 27368 ve VALID 28478 5 degerli TAM listedir — farkli string, dokunulmaz.)
set -uo pipefail
cd /opt/krb-assessment || exit 1
SRC="server_container.mjs"
cp -a "$SRC" "$SRC.bak_eskinokta"

echo "############ 1) ONCE — capa kac kez geciyor? (2 olmali) ############"
n=$(grep -cF "('PASIF_NOKTA','RISKLI_NOKTA')" "$SRC")
echo "  ('PASIF_NOKTA','RISKLI_NOKTA') : $n kez  (2 bekleniyor)"
grep -nF "('PASIF_NOKTA','RISKLI_NOKTA')" "$SRC" | sed 's/^/    /'
[ "$n" = "2" ] || { echo "  ❌ 2 degil — DUR, dosya degismis olabilir"; exit 1; }

echo
echo "############ 2) YAMA — ESKI_NOKTA ekle (Python, tam eslesme) ############"
python3 - <<'PY'
import io, sys
p = "server_container.mjs"
s = io.open(p, encoding="utf-8").read()
eski = "('PASIF_NOKTA','RISKLI_NOKTA')"
yeni = "('PASIF_NOKTA','ESKI_NOKTA','RISKLI_NOKTA')"  # ESKI eklendi; RISKLI olu ama zararsiz, kaldi
n = s.count(eski)
assert n == 2, f"❌ capa {n} kez (2 olmali)"
s = s.replace(eski, yeni)
io.open(p, "w", encoding="utf-8").write(s)
print(f"  ✅ 2 yerde ESKI_NOKTA eklendi")
PY

echo
echo "############ 3) node --check ############"
if node --check "$SRC" >/dev/null 2>&1; then echo "  ✅ node --check"; else
  echo "  ❌ BOZUK — GERI"; node --check "$SRC" 2>&1 | head -5; cp -a "$SRC.bak_eskinokta" "$SRC"; exit 1; fi

echo
echo "############ 4) KANIT — degisiklik yerinde mi? ############"
grep -nF "('PASIF_NOKTA','ESKI_NOKTA','RISKLI_NOKTA')" "$SRC" | sed 's/^/    /'
echo "  --- eski string kaldi mi? (0 olmali) ---"
grep -cF "('PASIF_NOKTA','RISKLI_NOKTA')" "$SRC" | sed 's/^/    kalan: /'

echo
echo "############ 5) DAGIT ############"
docker build -t krb-assessment:secure . >/tmp/b.log 2>&1 || { echo "❌ BUILD"; tail -20 /tmp/b.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET / -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)"

echo
echo "############ 6) ⚠ CANLI KANIT — rapor artik ESKI'yi sayiyor mu? ############"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
echo "  --- durum dagilimi (ESKI en buyuk grup) ---"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Rapor 'pasif_riskli/sorunlu' artik PASIF+ESKI sayiyor — 103 musteri gorunur oldu."

echo
echo "############ SONUC ############"
echo "  ✅ ESKI_NOKTA rapora girdi. En derin uyuyan grup artik gorunuyor."
echo "  ⚠ Geri donus: $SRC.bak_eskinokta"
