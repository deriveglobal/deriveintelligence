# -*- coding: utf-8 -*-
# RAPOR_DEFS_DK_V1 (masaustu) — Rapor Özet: net metrik isimleri + Planlanan + Tanımlar paneli.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_DEFS_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# D1) KPI blogu — yeniden isimlendir + Planlanan
OLD1 = '''      <div class="dk-kpis">
        ${kpi("rp-oz-ziyaret", o.toplam_ziyaret, "Ziyaret", "var(--mavi)", "Ziyaretleri listele", _delta(o.toplam_ziyaret, po.toplam_ziyaret))}
        ${kpi("rp-oz-benzersiz", o.benzersiz_nokta, "Benzersiz Nokta", "#6d4bd6", "Benzersiz noktaları listele", _delta(o.benzersiz_nokta, po.benzersiz_nokta))}
        ${kpi("rp-oz-yeni", o.yeni_nokta, "Yeni Nokta", "var(--yesil-p)", "Yeni noktaları listele", _delta(o.yeni_nokta, po.yeni_nokta))}
        ${kpi("rp-oz-pasif", o.pasif_riskli, "Pasif / Riskli", "var(--kirmizi-p)", "Pasif/riskli listele", _delta(o.pasif_riskli, po.pasif_riskli), true)}
      </div>'''
NEW1 = '''      <div class="dk-kpis">
        ${kpi("rp-oz-ziyaret", o.toplam_ziyaret, "Tamamlanan Ziyaret", "var(--mavi)", "Ziyaretleri listele", _delta(o.toplam_ziyaret, po.toplam_ziyaret))}
        ${kpi(null, o.planlanan, "Planlanan", "#0ea5e9")}
        ${kpi("rp-oz-benzersiz", o.benzersiz_nokta, "Ulaşılan Müşteri", "#6d4bd6", "Ulaşılan müşterileri listele", _delta(o.benzersiz_nokta, po.benzersiz_nokta))}
        ${kpi("rp-oz-yeni", o.yeni_nokta, "Yeni Müşteri Ziyareti", "var(--yesil-p)", "Yeni müşteri ziyaretlerini listele", _delta(o.yeni_nokta, po.yeni_nokta))}
        ${kpi("rp-oz-pasif", o.pasif_riskli, "Yeniden Kazanım", "var(--kirmizi-p)", "Yeniden kazanım ziyaretlerini listele", _delta(o.pasif_riskli, po.pasif_riskli), true)}
      </div>'''
assert s.count(OLD1) == 1, "kpi anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# D2) Genel Bakış baslik tooltip
OLD2 = '''${sech("Genel Bakış", "var(--mavi)", "Seçili dönemin temel saha KPI'ları: tamamlanan ziyaret, benzersiz nokta, yeni nokta ve pasif/riskli nokta. Oklar önceki eşit döneme göre değişimi gösterir.")}'''
NEW2 = '''${sech("Genel Bakış", "var(--mavi)", "Dönemin saha faaliyeti. Her metriğin tam açıklaması altta ⓘ Tanımlar panelinde. Oklar önceki eşit döneme göre değişim.")}'''
assert s.count(OLD2) == 1, "sech anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# D3) drill basliklari
for a, b in [
    ('bindZ("rp-oz-benzersiz", "Benzersiz Nokta", zs =>', 'bindZ("rp-oz-benzersiz", "Ulaşılan Müşteri", zs =>'),
    ('bindZ("rp-oz-yeni", "Yeni Nokta", zs =>', 'bindZ("rp-oz-yeni", "Yeni Müşteri Ziyareti", zs =>'),
    ('bindZ("rp-oz-pasif", "Pasif / Riskli", zs =>', 'bindZ("rp-oz-pasif", "Yeniden Kazanım", zs =>'),
]:
    assert s.count(a) == 1, "drill anchor bulunamadi: %s" % a[:40]
    s = s.replace(a, b, 1)

# D4) Tanımlar paneli (Özet innerHTML sonuna)
OLD4 = '''      </div>`;
    })() : ""}`;'''
NEW4 = '''      </div>`;
    })() : ""}
    <div class="dk-card" style="margin-top:14px">
      <details><summary style="cursor:pointer;font-size:13px;font-weight:700">ⓘ Tanımlar (metrik açıklamaları)</summary>
      <div class="sub2" style="margin-top:8px;line-height:1.8;text-transform:none;letter-spacing:0">
        <div><b>Tamamlanan Ziyaret:</b> Dönemde tamamlanan ziyaret sayısı (aynı müşteriye 2 ziyaret = 2).</div>
        <div><b>Planlanan:</b> Planlanmış ama henüz tamamlanmamış ziyaret.</div>
        <div><b>Ulaşılan Müşteri:</b> Dönemde en az 1 ziyaret yapılan <b>farklı</b> müşteri sayısı.</div>
        <div><b>Yeni Müşteri Ziyareti:</b> Durumu "Yeni Nokta" olan müşterilere yapılan ziyaret.</div>
        <div><b>Yeniden Kazanım:</b> Durumu Pasif/Eski/Riskli müşterilere yapılan ziyaret (uykuda/riskli müşteriyi geri kazanma).</div>
        <div><b>Yeni Kayıt:</b> Dönemde sisteme ilk kez eklenen <b>farklı</b> müşteri (gerçek yeni edinim).</div>
        <div><b>Win Rate:</b> Kazanılan ÷ (Kazanılan + Kaybedilen) teklif oranı.</div>
        <div style="margin-top:7px;padding-top:7px;border-top:1px dashed var(--cizgi)"><b>Durum</b> (Yeni/Aktif/Pasif/Eski/Riskli) ERP satış geçmişinden <b>otomatik</b> türetilir, elle değişmez. Kartın <b>arşiv</b> (silinmiş/birleştirilmiş) durumundan farklıdır.</div>
      </div></details>
    </div>`;'''
assert s.count(OLD4) == 1, "tanimlar anchor=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_DEFS_DK_V1 (masaustu)")
