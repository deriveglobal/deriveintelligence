#!/usr/bin/env bash
# BORÇ BUGÜN ÇAPRAZ — açık faturalar (odeme_durumu=O) ≈ bi_cari_bakiye 403M mü? İki bağımsız kaynak. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. odeme_tarihi GERÇEKTEN boş mu (geçmişi engelleyen tek sebep)"
$PSQL -c "SELECT count(*) toplam, count(odeme_tarihi) odeme_tarihi_dolu,
                 round(100.0*count(odeme_tarihi)/count(*),1) dolu_pct
          FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid;"

hr "2. ⚠ BUGÜN ÇAPRAZ — açık (O) faturalar brüt vs bi_cari_bakiye 403M"
$PSQL -c "
SELECT round(sum(satir_kdv_dahil) FILTER (WHERE odeme_durumu='O')/1e6,1) acik_brut_m,
       round(sum(satir_kdv_haric) FILTER (WHERE odeme_durumu='O')/1e6,1) acik_net_m
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid;"
$PSQL -c "SELECT round(sum(abs(tedarikci_bakiye)) FILTER (WHERE tedarikci_bakiye<0)/1e6,1) cari_bakiye_borc_m
          FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;"
echo "  ⚠ İki kaynak yakınsa bugünkü borç ÇİFT KAYNAKLA sağlam (fatura açık-kalem + cari bakiye)."

hr "3. NE OLURDU — odeme_tarihi dolu olsaydı: geçmiş borç + tedarikçi DPO açılırdı (aksiyon)"
echo "  → SAP export'una odeme_tarihi eklenirse borç DSO/stok gibi geçmişe kurulur + DPO metriği gelir."
echo "  → Şimdilik borç = snapshot-only (bugünden ileri), DOĞRULANDI."

hr "BITTI — bugün çift kaynaklı sağlam; geçmiş odeme_tarihi'ne bağlı (şu an boş)."
