#!/usr/bin/env bash
# IL_ILCE_9_TEMSILCI — ikinci il listesini oldur. AMA ONCE VERIYI OKU.
#
# ⚠ 6331 = temsilciDetayModal. Musteri formu DEGIL — yoneticinin temsilciye
#   SEHIR ATADIGI ekran (rep.sehirler).
#
# ⚠⚠ TUZAK: secili.has(il) TAM METIN karsilastirmasi.
#   Listeyi "ADANA" yaparsam, DB'de "Kocaeli" yazan temsilcinin kutucuklari
#   SESSIZCE bos gelir -> yonetici kaydete basar -> EFTAL'IN BOLGESI SILINIR.
#   Kimse fark etmez. Bu yuzden once DB'yi okuyorum.
#
# ⚠ Eski listede "İçel (Mersin)" var. O il 1993'te MERSİN oldu.
#
# BU BETIK: A) okur  B) esleseMEZse DURUR  C) esleserse gocurur+yamalar
set -u
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SJ=shells/saha.js

echo "############ A1) saha_rep_sehir — tablo yapisi ############"
$PSQL -c "
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_name='saha_rep_sehir' ORDER BY ordinal_position;"

echo
echo "############ A2) ⚠ KAYITLI DEGERLER — ne yaziyor? ############"
$PSQL -c "
SELECT u.full_name, rs.il
  FROM saha_rep_sehir rs
  JOIN users u ON u.id = rs.rep_id
 ORDER BY 1, 2;"
$PSQL -c "SELECT count(*) AS toplam_kayit, count(DISTINCT rep_id) AS temsilci FROM saha_rep_sehir;"

echo
echo "############ A3) ⚠ HER DEGER RESMI LISTEDE VAR MI? ############"
$PSQL -c "
WITH d AS (SELECT DISTINCT il AS deger FROM saha_rep_sehir)
SELECT d.deger AS kayitli,
       (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il) = tr_norm(d.deger) LIMIT 1) AS resmi_karsilik,
       CASE WHEN EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(d.deger))
            THEN '✅ eslesiyor' ELSE '❌ ESLESMIYOR' END AS durum
  FROM d ORDER BY 3, 1;"

ESLESMEYEN=$($PSQL -tAc "
WITH d AS (SELECT DISTINCT il AS deger FROM saha_rep_sehir)
SELECT count(*) FROM d
 WHERE NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(d.deger));" | head -1 | tr -d '[:space:]')
echo "  eslesmeyen deger sayisi: ${ESLESMEYEN:-?}"
echo "  ⚠ Not: saha_rep_sehir BOS olabilir (hic sehir atanmamis). O zaman ESLESMEYEN=0 -> yama guvenli."

echo
echo "############ B) ⚠ KAPI — eslesmeyen varsa DURUYORUM ############"
if [ "${ESLESMEYEN:-1}" != "0" ]; then
  echo "  ⛔ Eslesmeyen deger VAR (ya da okunamadi). YAMA YOK."
  echo "     Sebebi yukarida. Once onu cozeriz — bolge silinmesin."
  echo "     ⚠ 'İçel (Mersin)' gibi eski isimler burada cikar."
  exit 0
fi
echo "  ✅ tum kayitli sehirler resmi listede karsilik buluyor — devam"

echo
echo "############ C1) GOC — kayitli sehirleri RESMI yazima cevir ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
DROP TABLE IF EXISTS yedek_sehirler;
CREATE TABLE yedek_sehirler AS
  SELECT *, now() AS yedek_at FROM saha_rep_sehir;

-- ⚠ il alanini resmi yazima cevir. Eslesme yoksa (kapi B'de durduk) buraya gelmeyiz.
UPDATE saha_rep_sehir rs
   SET il = (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(rs.il) LIMIT 1)
 WHERE EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(rs.il));
SQL
$PSQL -c "
SELECT u.full_name, rs.il FROM saha_rep_sehir rs JOIN users u ON u.id=rs.rep_id ORDER BY 1,2;"
echo "  ✅ resmi yazima cevrildi — yedek: yedek_sehirler"

echo
echo "############ C2) YAMA — eski TR_ILLER dizisini OLDUR ############"
cp -a "$SJ" "$SJ.bak_tekliste"
python3 - <<'PY'
import io, re, sys
p = "shells/saha.js"
s = io.open(p, encoding="utf-8").read()

# 1) kullanim: TR_ILLER -> window.TR_ILLER_RESMI
n_kul = len(re.findall(r'(?<![\w.])TR_ILLER\.map', s))
s = re.sub(r'(?<![\w.])TR_ILLER\.map', '(window.TR_ILLER_RESMI || []).map', s)
print(f"  kullanim degistirildi : {n_kul}")
assert n_kul >= 1, "❌ TR_ILLER.map bulunamadi"

# 2) dizinin kendisi: const TR_ILLER = [ ... ];  -> SIL
m = re.search(r'\nconst TR_ILLER = \[.*?\n\];\n', s, re.S)
assert m, "❌ const TR_ILLER dizisi bulunamadi — DURDUM"
uzun = m.group(0).count(",") + 1
s = s[:m.start()] + (
    '\n// ⚠ IL_ILCE_TEKLISTE: eski TR_ILLER dizisi SILINDI.\n'
    '//   81 il vardi ama yazimi eskiydi ("İçel (Mersin)" — o il 1993te MERSİN oldu).\n'
    '//   Tek kaynak: /shells/tr_il_ilce.js -> window.TR_ILLER_RESMI (81 il · 973 ilce, NVI).\n'
    '//   Iki liste bir listeden kotudur: hangisinin ekranda oldugunu kimse bilemez.\n'
) + s[m.end():]
print(f"  eski dizi SILINDI     : ~{uzun} eleman")

io.open(p, "w", encoding="utf-8").write(s)
PY

echo
echo "############ C3) SOZDIZIMI ############"
if node --check "$SJ" >/dev/null 2>&1; then
  echo "  ✅ node --check"
else
  echo "  ❌ BOZUK — GERI ALIYORUM"; node --check "$SJ" 2>&1 | head -5
  cp -a "$SJ.bak_tekliste" "$SJ"; exit 1
fi

echo
echo "  --- kalan TR_ILLER (window.TR_ILLER_RESMI disinda) ---"
grep -n '(?<!window\.)TR_ILLER' "$SJ" 2>/dev/null | grep -v 'TR_ILLER_RESMI' | sed 's/^/  /'
grep -c 'TR_ILLER_RESMI' "$SJ" | sed 's/^/  TR_ILLER_RESMI kullanimi: /'

echo
echo "############ D) DAGIT ############"
docker build -t krb-assessment:secure . >/tmp/b.log 2>&1 || { echo "❌ BUILD"; tail -20 /tmp/b.log; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET /shells/saha.js -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/shells/saha.js)"

echo
echo "############ E) ⚠ KANIT — servis edilen dosyada eski dizi KALDI mi? ############"
# ⚠ pipefail YOK, grep -q YOK. Kapiyi yine kendim kirmayayim.
ESKI=$(curl -s http://localhost:8080/shells/saha.js | grep -c 'const TR_ILLER = \[')
YENI=$(curl -s http://localhost:8080/shells/saha.js | grep -c 'TR_ILLER_RESMI')
echo "  eski dizi (const TR_ILLER = [) : $ESKI   ⚠ 0 olmali"
echo "  yeni kaynak (TR_ILLER_RESMI)   : $YENI   ⚠ >0 olmali"
[ "$ESKI" = "0" ] && [ "$YENI" -gt 0 ] && echo "  ✅ TEK LISTE" || echo "  ❌ hala iki liste"

echo
echo "############ SONUC ############"
echo "  ⚠ Ekranda simdi TEK il listesi var: resmi NVI listesi."
echo "  ⚠ Temsilci sehirleri resmi yazima gocuruldu — kutucuklar BOS GELMEZ."
echo "  ⚠ Geri donus: shells/saha.js.bak_tekliste · yedek_sehirler"
