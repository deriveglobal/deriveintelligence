#!/usr/bin/env bash
# DENETIM_113C — LLM guvenligi: (A) acil e-posta birikime bagli, (B) LLM rakip yazimi taslak.
set -uo pipefail
cd /opt/krb-assessment || exit 1
SRC="server_container.mjs"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
cp -a "$SRC" "$SRC.bak_llmguv"

echo "############ 0) run_ozet.sh gunluk ozeti CAGIRIYOR mu? (singles oraya akmali) ############"
grep -nE "gunluk-ozet|gunluk_ozet|ozet" /opt/price_monitor/run_ozet.sh 2>/dev/null | sed 's/^/  /' || echo "  ⚠ run_ozet.sh gunluk-ozet cagirmiyor gibi — kontrol et"

echo
echo "############ 1) DB — esik kolonu + dogrulanmis kolonu ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
ALTER TABLE bi_ayar           ADD COLUMN IF NOT EXISTS saha_acil_esik integer NOT NULL DEFAULT 3;
ALTER TABLE saha_rakip_teklif ADD COLUMN IF NOT EXISTS dogrulanmis    boolean NOT NULL DEFAULT true;
SQL
$PSQL -c "SELECT tenant_id, saha_acil_esik FROM bi_ayar;"
$PSQL -c "SELECT dogrulanmis, count(*) FROM saha_rakip_teklif GROUP BY 1;"
echo "  ✅ kolonlar hazir (mevcut rakip kayitlar dogrulanmis=true, cunku insan girdisi)"

echo
echo "############ 2) KOD YAMALARI (Python, tam eslesme) ############"
python3 - <<'PY'
import io, sys
p = "server_container.mjs"; s = io.open(p, encoding="utf-8").read()
edits = []

# A1 — _pushSevereSignals: esik kapisi
a1_bul = '''    if (!r.rows.length) return;
    const to = await _ownerAlarmEmail();
    const ad = { risk: "RISK", teklif_talep: "Teklif Talebi", rakip: "Rakip Fiyat", takip: "Takip", firsat: "Firsat" };'''
a1_koy = '''    if (!r.rows.length) return;
    // ⚠ BIRIKIME BAGLA (MUTAFLAR dersi): 1-2 acil sinyal gunluk ozete kalir; kritik-once listelenir.
    //   Sadece esik kadar (bi_ayar.saha_acil_esik, varsayilan 3) birikince ANLIK toplu e-posta.
    const _eq = await pool.query("SELECT COALESCE(saha_acil_esik,3) AS esik FROM bi_ayar WHERE tenant_id=$1", [tenantId]);
    const _esik = Number(_eq.rows[0] && _eq.rows[0].esik) || 3;
    if (r.rows.length < _esik) {
      console.log("[pushSevere] " + r.rows.length + " acil bekliyor (<" + _esik + ") — gunluk ozete birakildi, anlik e-posta YOK");
      return;
    }
    const to = await _ownerAlarmEmail();
    const ad = { risk: "RISK", teklif_talep: "Teklif Talebi", rakip: "Rakip Fiyat", takip: "Takip", firsat: "Firsat" };'''
edits.append(("A1 pushSevere esik kapisi", a1_bul, a1_koy))

# A2 — _sahaGunlukOzet: gosterilen acil sinyalleri bildirildi say
a2_bul = '''    await pool.query("UPDATE saha_sinyal SET ozet_dahil=TRUE WHERE tenant_id=$1 AND created_at>=" + S, [tenantId]);'''
a2_koy = '''    await pool.query("UPDATE saha_sinyal SET ozet_dahil=TRUE WHERE tenant_id=$1 AND created_at>=" + S, [tenantId]);
    // ⚠ Ozette gosterilen acil sinyaller "bildirildi" sayilir — sonra tekrar batch e-posta atilmasin.
    await pool.query("UPDATE saha_sinyal SET owner_bildirildi=TRUE WHERE tenant_id=$1 AND onem>=3 AND created_at>=" + S, [tenantId]);'''
edits.append(("A2 gunluk ozet acil sinyalleri bildirildi say", a2_bul, a2_koy))

# B1 — _applyIntents rakip INSERT: dogrulanmis=false (LLM yazimi taslak)
b1_bul = '''"INSERT INTO saha_rakip_teklif (tenant_id,kaynak,rakip_marka,rakip_model,ebat,rakip_fiyat,musteri_id,rep_id,notlar,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$8)"'''
b1_koy = '''"INSERT INTO saha_rakip_teklif (tenant_id,kaynak,rakip_marka,rakip_model,ebat,rakip_fiyat,musteri_id,rep_id,notlar,created_by,dogrulanmis) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$8,false)"'''
edits.append(("B1 LLM rakip yazimi dogrulanmis=false", b1_bul, b1_koy))

# B2 — GM karar araligi: dogrulanmamisi disla (29291)
b2_bul = "FROM saha_rakip_teklif WHERE tenant_id=$1 AND ebat=$2"
b2_koy = "FROM saha_rakip_teklif WHERE tenant_id=$1 AND ebat=$2 AND COALESCE(dogrulanmis,true)"
edits.append(("B2 karar araligi (ebat) dogrulanmis filtresi", b2_bul, b2_koy))

# B3 — rep asistan piyasa araligi: dogrulanmamisi disla (32014)
b3_bul = "FROM saha_rakip_teklif WHERE tenant_id=$1 AND rakip_fiyat>0 AND regexp_replace(lower(coalesce(ebat,'')),'[^0-9a-z]','','g') LIKE $2"
b3_koy = "FROM saha_rakip_teklif WHERE tenant_id=$1 AND rakip_fiyat>0 AND COALESCE(dogrulanmis,true) AND regexp_replace(lower(coalesce(ebat,'')),'[^0-9a-z]','','g') LIKE $2"
edits.append(("B3 rep asistan araligi dogrulanmis filtresi", b3_bul, b3_koy))

fail = []
for ad, bul, koy in edits:
    n = s.count(bul)
    if n != 1:
        fail.append(f"  ✗ {ad}: capa {n} kez (1 olmali)")
        continue
    s = s.replace(bul, koy); print(f"  ✅ {ad}")
if fail:
    print("\n!! BAZI CAPALAR TUTMADI — DOSYAYA YAZILMADI:"); print("\n".join(fail)); sys.exit(1)
io.open(p, "w", encoding="utf-8").write(s)
print("  ✅ 5/5 yama uygulandi")
PY

echo
echo "############ 3) node --check ############"
if node --check "$SRC" >/dev/null 2>&1; then echo "  ✅ node --check"; else
  echo "  ❌ BOZUK — GERI"; node --check "$SRC" 2>&1 | head; cp -a "$SRC.bak_llmguv" "$SRC"; exit 1; fi

echo
echo "############ 4) DAGIT ############"
docker build -t krb-assessment:secure . >/tmp/b.log 2>&1 || { echo "❌ BUILD"; tail -20 /tmp/b.log; cp -a "$SRC.bak_llmguv" "$SRC"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET / -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)"

echo
echo "############ 5) KANIT — yamalar servis edilen dosyada mi? ############"
echo "  A1 esik kapisi   : $(grep -c 'BIRIKIME BAGLA' $SRC)"
echo "  A2 ozet bildirim : $(grep -c 'Ozette gosterilen acil' $SRC)"
echo "  B1 taslak yazim  : $(grep -c 'dogrulanmis) VALUES.*false' $SRC)"
echo "  B2+B3 filtre     : $(grep -c 'COALESCE(dogrulanmis,true)' $SRC)  (2 bekleniyor)"

echo
echo "############ SONUC ############"
echo "  ✅ Acil e-posta artik 3+ yiginda anlik; tek/cift gunluk ozete kalir (bi_ayar.saha_acil_esik ile ayarlanir)."
echo "  ✅ LLM'in yazdigi rakip fiyati 'dogrulanmamis' — GM karar araligina GIRMEZ; insan onaylayinca girer."
echo "  ⚠ Geri donus: $SRC.bak_llmguv"
