#!/usr/bin/env bash
# DSO KREDİ DESENİ — 'çek' (kredi) vs 'çekim' (kart=peşin) kirliliğini ölç + düzelt. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TAM odeme_kosulu LİSTESİ — hepsini gör (kredi/peşin sınıfını gözle doğrula)"
$PSQL -c "SELECT odeme_kosulu, count(*),
                 round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365)/1e6,1) son365_m
          FROM bi_satis_faturalari WHERE tenant_id='$T'
          GROUP BY 1 ORDER BY 2 DESC;"

hr "2. 'çek' İÇERENLER — gerçek Çek-Senet (kredi) mi, Kart Çekim (peşin) mi?"
$PSQL -c "SELECT odeme_kosulu, count(*),
                 CASE WHEN odeme_kosulu ~* 'çekim' THEN 'KART=PEŞİN (yanlış eşleşen)'
                      ELSE 'gerçek çek/senet=KREDİ' END tani
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND odeme_kosulu ~* 'çek'
          GROUP BY 1 ORDER BY 2 DESC;"

hr "3. DSO — KİRLİ desen vs DÜZELTİLMİŞ desen (etki ne kadar?)"
$PSQL -c "
WITH alacak AS (SELECT sum(hesap_bakiyesi) a FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true)),
kirli AS (SELECT sum(satir_tutar)/365 g FROM bi_satis_faturalari
           WHERE tenant_id='$T' AND fatura_tarihi>=CURRENT_DATE-365
             AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben'),
temiz AS (SELECT sum(satir_tutar)/365 g FROM bi_satis_faturalari
           WHERE tenant_id='$T' AND fatura_tarihi>=CURRENT_DATE-365
             AND odeme_kosulu ~* 'vade|mukabili|mahsuben'
             AND NOT (odeme_kosulu ~* 'peşin')     -- kart çekim/taksit peşin dışla
          )
SELECT round((SELECT a FROM alacak)/1e6,1) alacak_m,
       round((SELECT g FROM kirli)/1e6,2) kirli_gunluk_m,
       round((SELECT a FROM alacak)/(SELECT g FROM kirli)) dso_kirli,
       round((SELECT g FROM temiz)/1e6,2) temiz_gunluk_m,
       round((SELECT a FROM alacak)/(SELECT g FROM temiz)) dso_temiz;"
echo "  ⚠ dso_temiz > dso_kirli beklenir (peşin kart satışları paydadan çıkınca payda küçülür → DSO yükselir)."

hr "4. TEMİZ DESEN KONTROL — düzeltilmiş filtre neyi KREDİ sayıyor (peşin sızıntısı kaldı mı?)"
$PSQL -c "SELECT odeme_kosulu, count(*) FROM bi_satis_faturalari
          WHERE tenant_id='$T'
            AND odeme_kosulu ~* 'vade|mukabili|mahsuben'
            AND NOT (odeme_kosulu ~* 'peşin')
          GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Bu listede HİÇ 'Peşin' / 'Çekim' olmamalı — sadece Vade/Mukabili/Mahsuben/Çek-Senet."

hr "5. SUNUCU KODU da aynı hatayı yapıyor mu? ('çek' deseni serverda var mı)"
grep -rn "mukabili\|mahsuben\|Gün Vade\|odeme_kosulu.*çek" /opt/krb-assessment/server_container.mjs 2>/dev/null | head -8 | sed 's/^/  /'
echo "  ⚠ Serverda 'çek' deseni varsa CANLI DSO da kirli — #115 ile birlikte düzeltilmeli."

hr "BITTI — kirlilik ölçüldü. Temiz desen onaylanınca DSO fonksiyonu onunla yazılır."
