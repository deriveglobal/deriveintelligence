#!/usr/bin/env bash
# VARDIYA_V1 — sahte defteri GERCEK kaynaga bagla.
# ⚠ SQL ONCE Postgres'te kosar, SONRA restart.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ SQL'I ONCE POSTGRES'TE KOS ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
SET app.current_tenant_id='$TEN';
WITH kontrol AS (
  SELECT checked_at AS zaman,
         CASE WHEN status='ok' THEN 'normal' ELSE 'dikkat' END AS durum,
         title || ' — ' || COALESCE(value,'') AS metin, 1 AS oncelik
    FROM ops_health
   WHERE checked_at >= now() - interval '72 hours'
     AND (status <> 'ok' OR check_key IN ('dq.ebat_parse','app.errors'))),
yukleme AS (
  SELECT processed_at AS zaman,
         CASE WHEN status='ok' THEN 'normal' ELSE 'dikkat' END AS durum,
         query_type || ' — ' || row_count_kept || '/' || row_count_raw || ' satır' ||
         CASE WHEN row_count_raw > row_count_kept
              THEN ' (' || (row_count_raw - row_count_kept) || ' reddedildi)' ELSE '' END AS metin,
         2 AS oncelik
    FROM bi_ingestion_log
   WHERE tenant_id='$TEN'::uuid AND processed_at >= now() - interval '72 hours'),
tarama AS (
  SELECT max(scraped_at) AS zaman, 'normal' AS durum,
         'E-ticaret taraması — ' || count(*) || ' fiyat · ' || count(DISTINCT marka) || ' marka' AS metin,
         3 AS oncelik
    FROM bi_rakip_fiyat
   WHERE scraped_at >= now() - interval '72 hours'
   HAVING count(*) > 0)
SELECT to_char(zaman,'DD/MM HH24:MI') AS zaman, durum, metin FROM (
  SELECT * FROM kontrol UNION ALL SELECT * FROM yukleme UNION ALL SELECT * FROM tarama
) x WHERE zaman IS NOT NULL ORDER BY zaman DESC LIMIT 8;
SQL
[ $? -ne 0 ] && { echo "❌ SQL PATLADI — yama YOK, restart YOK."; exit 1; }
echo "  ^ ⚠ ZAMAN DAMGALARI FARKLI. Eskisi 6 satir, 6'si da ayni damgaydi."

echo
echo "############ 2) YAMA ############"
cp server_container.mjs server_container.mjs.bak_vardiya
ONCE=$(wc -c < server_container.mjs)
python3 patch_vardiya.py || { cp server_container.mjs.bak_vardiya server_container.mjs; echo "❌ geri alindi"; exit 1; }
SONRA=$(wc -c < server_container.mjs)
echo "  boyut: $ONCE -> $SONRA"
[ "$SONRA" -gt "$ONCE" ] || { cp server_container.mjs.bak_vardiya server_container.mjs; echo "❌ buyumedi"; exit 1; }

node --check server_container.mjs || { cp server_container.mjs.bak_vardiya server_container.mjs; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ON YUZ: durum rengi + sinyal yasi ############"
cp shells/bi.js shells/bi.js.bak_vardiya
python3 - <<'PY'
import pathlib
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")

# vardiya render: durum rengi + gercek metin
eski = """      (d.vardiya||[]).forEach(function(v){
        const t = new Date(v.olusma);
        h += '<div><span style="color:var(--tx-3)">' + t.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'})
           + ' ' + t.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}) + '</span>  ' + esc(v.baslik) + '</div>';
      });"""
assert eski in s, "vardiya render anchor yok"
yeni = """      (d.vardiya||[]).forEach(function(v){
        const t = new Date(v.zaman);
        const c = v.durum === 'dikkat' ? 'var(--sari)' : 'var(--tx-2)';
        h += '<div><span style="color:var(--tx-3)">' + t.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'})
           + ' ' + t.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'})
           + '</span>  <span style="color:' + c + '">' + esc(v.metin) + '</span></div>';
      });"""
s = s.replace(eski, yeni, 1)

# ⚠ SINYAL YASI — bayatligi GIZLEME, YAZ.
eski2 = """       + '<div style="font-size:12px;color:var(--tx-3)">' + (d.kararlar||[]).length + ' açık</div></div>';"""
assert eski2 in s, "karar basligi anchor yok"
yeni2 = """       + '<div style="font-size:12px;color:var(--tx-3)">' + (d.kararlar||[]).length + ' açık'
       + (d.sinyal_yasi != null ? ' · ' + d.sinyal_yasi + ' saat önce hesaplandı' : '') + '</div></div>';"""
s = s.replace(eski2, yeni2, 1)

p.write_text(s, encoding="utf-8")
print("  ✅ vardiya render + sinyal yasi etiketi")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_vardiya shells/bi.js; echo "❌ NODE FAIL"; exit 1; }

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 8
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 20s krb-assessment 2>&1 | grep -i "error\|api/bi/ana" | head -3 || echo "  log temiz"

git add -A && git commit -q -m "fix(ana): VARDIYA_V1 — sahte vardiya defteri gercek kaynaga baglandi. ESKISI SAHTEYDI: 6 satirin 6'si da ayni zaman damgasi (13/07 17:32) — bir kesif akisi degil, bi_sinyal tablosunun tek seferlik uretim damgasi. 'AI is basinda' susu; tam da bastan reddettigimiz sey. YENI KAYNAKLAR (zaman damgalari GERCEKTEN farkli): ops_health (gunluk kontroller — bu sabah 00:00'da kostu, saha_5xx 24 saatte 5 hata buldu, ebat_parse 361/98.966 okunamadi) · bi_ingestion_log (hangi dosya, kac satir, kac REDDEDILDI) · bi_rakip_fiyat (tarama ne zaman, kac fiyat). Dikkat gerektiren satirlar SARI. ⚠ Ayrica sinyal yasi ekrana yazildi: sinyaller BAYAT DEGIL (canli veriyle birebir uyusuyor — MUTAFLAR risk 47.556.434,18 birebir) ama 2,5 saatlik ANLIK GORUNTU ve bunu soylemiyorlardi. Bayatligi gizlemek yerine ILAN ediyoruz: 'X saat once hesaplandi'." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_vardiya server_container.mjs && cp shells/bi.js.bak_vardiya shells/bi.js && docker cp server_container.mjs krb-assessment:/app/server.mjs && docker cp shells/bi.js krb-assessment:/app/shells/bi.js && docker restart krb-assessment"
