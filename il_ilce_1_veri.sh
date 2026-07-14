#!/usr/bin/env bash
# IL_ILCE_1_VERI — resmi il/ilce verisini indir, JS dosyasi uret, GECMISI onar.
#
# ⚠ 973 ILCEYI ELLE YAZMIYORUM. Kopyalarken tek harf yanlis yazarsam,
#   bugun duzelttigimiz her seyden sinsi bir hata uretirim: kimse fark etmez,
#   sadece bir ilce kaybolur. Veri INDIRILIYOR, uretiliyor. Transkripsiyon riski SIFIR.
#
# ⚠ OLCULEN HASAR:
#   il  : 100 farkli yazim -> 91 normalize (9 buyuk/kucuk harf cifti)
#   ilce: 206 -> 193 (13 cift; MERKEZ|Merkez|merkez = 147 musteri)
#   ⚠ ASIL SORUN: IL ALANINA ILCE YAZILMIS.
#     Izmit (20) · Korfez (9) · Adapazari-Sakarya (24) · Yesilova (14)
#     = 67 musteri, il bazli hicbir raporda dogru yerde GORUNMUYOR.
#     Kocaeli 102 gosteriyor; gercekte 131.
#   ⚠ 185 musterinin ilcesi BOS.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) RESMI VERIYI INDIR ############"
curl -sS -o /tmp/il.json   https://raw.githubusercontent.com/volkansenturk/turkiye-iller-ilceler/master/il.json   || { echo "❌ il.json"; exit 1; }
curl -sS -o /tmp/ilce.json https://raw.githubusercontent.com/volkansenturk/turkiye-iller-ilceler/master/ilce.json || { echo "❌ ilce.json"; exit 1; }
echo "  il.json   : $(wc -c < /tmp/il.json) B"
echo "  ilce.json : $(wc -c < /tmp/ilce.json) B"

echo
echo "############ 2) JS VERI DOSYASI URET ############"
python3 - <<'PY' || exit 1
import json, pathlib

def cek(yol):
    d = json.load(open(yol, encoding="utf-8"))
    for blok in d:
        if blok.get("type") == "table":
            return blok["data"]
    raise SystemExit("❌ veri blogu yok")

iller = cek("/tmp/il.json")
ilceler = cek("/tmp/ilce.json")

# ⚠ KIBRIS (501-503) HARIC — Turkiye il listesi degil.
il_ad = {i["id"]: i["name"] for i in iller if int(i["id"]) <= 81}
harita = {}
for x in ilceler:
    ad = il_ad.get(x["il_id"])
    if not ad: continue
    harita.setdefault(ad, []).append(x["name"])
for k in harita: harita[k] = sorted(set(harita[k]))

assert len(harita) == 81, f"❌ {len(harita)} il — 81 olmali"
toplam = sum(len(v) for v in harita.values())
print(f"  ✅ {len(harita)} il · {toplam} ilce")
# ⚠ SAGLAMA: bildigimiz birkac ilce yerinde mi?
for il, ilce in [("KOCAELİ","İZMİT"), ("KOCAELİ","GEBZE"), ("KOCAELİ","KÖRFEZ"),
                 ("SAKARYA","ADAPAZARI"), ("DÜZCE","KAYNAŞLI"), ("ANKARA","ÇANKAYA")]:
    assert ilce in harita.get(il, []), f"❌ {il}/{ilce} YOK — veri bozuk"
print("  ✅ saglama: KOCAELİ/İZMİT · KOCAELİ/GEBZE · SAKARYA/ADAPAZARI · DÜZCE/KAYNAŞLI")

js = "// ⚠ RESMI IL/ILCE VERISI — elle yazilmadi, kaynaktan uretildi.\n"
js += "//   Kaynak: github.com/volkansenturk/turkiye-iller-ilceler (NVI tabanli)\n"
js += f"//   {len(harita)} il · {toplam} ilce · uretim: 14 Tem 2026\n"
js += "//   ⚠ ELLE DUZENLEME. Guncelleme gerekirse kaynaktan YENIDEN URET.\n"
js += "window.TR_IL_ILCE = " + json.dumps(harita, ensure_ascii=False, sort_keys=True, indent=0).replace("\n", "") + ";\n"
js += "window.TR_ILLER_RESMI = " + json.dumps(sorted(harita.keys()), ensure_ascii=False) + ";\n"
pathlib.Path("shells/tr_il_ilce.js").write_text(js, encoding="utf-8")
print(f"  ✅ shells/tr_il_ilce.js ({len(js)} B)")
PY

echo
echo "############ 3) ⚠ GECMIS — once ESLESTIR, sonra goster ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- ⚠ Resmi listeyi gecici tabloya al ki SQL ile eslestirebilelim.
DROP TABLE IF EXISTS tr_ilce_ref;
CREATE TABLE tr_ilce_ref (il text, ilce text);
SQL

python3 - <<'PY' || exit 1
import json, subprocess
d = json.load(open("/tmp/ilce.json", encoding="utf-8"))
il = json.load(open("/tmp/il.json", encoding="utf-8"))
ilad = {i["id"]: i["name"] for b in il if b.get("type")=="table" for i in b["data"] if int(i["id"])<=81}
rows = [(ilad[x["il_id"]], x["name"]) for b in d if b.get("type")=="table" for x in b["data"] if x["il_id"] in ilad]
sql = "COPY tr_ilce_ref (il, ilce) FROM STDIN WITH (FORMAT csv);\n"
sql += "\n".join(f'"{a}","{b}"' for a, b in rows) + "\n\\.\n"
p = subprocess.run(["docker","exec","-i","krb-assessment-postgres","psql","-U","assessment_app","-d","assessment_platform"],
                   input=sql, text=True, capture_output=True)
print("  ", p.stdout.strip().splitlines()[-1] if p.stdout.strip() else p.stderr.strip()[:80])
PY
$PSQL -c "SELECT count(*) AS ref_ilce, count(DISTINCT il) AS ref_il FROM tr_ilce_ref;"

echo
echo "############ 4) ⚠ TESHIS — mevcut kayitlar resmi listeyle TUTUYOR MU? ############"
echo "  --- IL alani: resmi listede OLMAYANLAR ---"
$PSQL -c "
SELECT m.il AS yazilan, count(*) AS musteri,
       (SELECT string_agg(DISTINCT r.il, ', ') FROM tr_ilce_ref r
         WHERE upper(r.ilce) = upper(trim(m.il))) AS ASLINDA_ILCE_OLDUGU_IL
  FROM saha_musteri m
 WHERE m.aktif AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE upper(r.il) = upper(trim(m.il)))
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ 'ASLINDA_ILCE_OLDUGU_IL' doluysa: il alanina ILCE yazilmis. Otomatik duzeltilebilir."
echo "     Bos ise: ne oldugu BILINMIYOR. Elle bakilacak — UYDURMAM."

echo
echo "  --- ILCE alani: o ilde OLMAYANLAR ---"
$PSQL -c "
SELECT m.il, m.ilce, count(*) AS musteri
  FROM saha_musteri m
 WHERE m.aktif AND m.ilce IS NOT NULL AND m.il IS NOT NULL
   AND NOT EXISTS (
     SELECT 1 FROM tr_ilce_ref r
      WHERE upper(r.il) = upper(trim(m.il)) AND upper(r.ilce) = upper(trim(m.ilce)))
 GROUP BY 1,2 ORDER BY 3 DESC LIMIT 20;"
echo "  ⚠ Bunlar ya yazim hatasi, ya mahalle adi, ya da il yanlis."

echo
echo "############ 5) OZET ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE upper(r.il)=upper(trim(m.il)))) AS il_gecerli,
       count(*) FILTER (WHERE m.il IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE upper(r.il)=upper(trim(m.il)))) AS il_GECERSIZ,
       count(*) FILTER (WHERE m.ilce IS NULL OR trim(m.ilce)='') AS ilce_bos
  FROM saha_musteri m WHERE m.aktif;"
echo
echo "  ⚠ SIRADAKI: (a) buyuk/kucuk harf normalize  (b) ilce-olarak-yazilmis-il duzelt"
echo "              (c) arayuz: il ve ilce ACILIR LISTE olsun"
echo "  ⚠ Once TESHISI gorelim. Bilmedigim veriyi duzeltmem."
