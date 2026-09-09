# -*- coding: utf-8 -*-
# RAPOR_DEFS_V1 (mobil) — Rapor Özet: net metrik isimleri + Planlanan + Tanımlar paneli.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_DEFS_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# M1) Genel Bakış tile blogu — yeniden isimlendir + Planlanan
OLD1 = '''          ${bBaslik("Genel Bakış","#3b82f6","Seçili dönemin temel saha KPI'ları: ziyaret, müşteri, tamamlanan plan ve toplam teklif özeti.")}
          <div class="ozet-izgara">
            ${kut("rp-oz-ziyaret",   o.toplam_ziyaret, "#3b82f6", "Ziyaret")}
            ${kut("rp-oz-benzersiz", o.benzersiz_nokta, "#8b5cf6", "Benzersiz Nokta")}
            ${kut("rp-oz-yeni",      o.yeni_nokta,     "#10b981", "Yeni Nokta")}
            ${kut("rp-oz-pasif",     o.pasif_riskli,   "#ef4444", "Pasif/Riskli")}
          </div>'''
NEW1 = '''          ${bBaslik("Genel Bakış","#3b82f6","Dönemin saha faaliyeti — her metriğin tam açıklaması altta ⓘ Tanımlar'da.")}
          <div class="ozet-izgara">
            ${kut("rp-oz-ziyaret",   o.toplam_ziyaret, "#3b82f6", "Tamamlanan Ziyaret")}
            <div class="ozet-kut" title="Planlanmış ama henüz tamamlanmamış ziyaret"><b style="color:#0ea5e9">${o.planlanan||0}</b><span>Planlanan</span></div>
            ${kut("rp-oz-benzersiz", o.benzersiz_nokta, "#8b5cf6", "Ulaşılan Müşteri")}
            ${kut("rp-oz-yeni",      o.yeni_nokta,     "#10b981", "Yeni Müşteri Ziyareti")}
            ${kut("rp-oz-pasif",     o.pasif_riskli,   "#ef4444", "Yeniden Kazanım")}
          </div>'''
assert s.count(OLD1) == 1, "tiles anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# M2) drill modal basliklari
for a, b in [
    ('rpZiyaretListesiModal("Benzersiz Nokta", uniq);', 'rpZiyaretListesiModal("Ulaşılan Müşteri", uniq);'),
    ('rpZiyaretListesiModal("Yeni Nokta", ziyaretler.filter(z => z.musteri_durum === "YENI_NOKTA"));', 'rpZiyaretListesiModal("Yeni Müşteri Ziyareti", ziyaretler.filter(z => z.musteri_durum === "YENI_NOKTA"));'),
    ('rpZiyaretListesiModal("Pasif/Riskli", ziyaretler.filter(z => ["PASIF_NOKTA","RISKLI_NOKTA"].includes(z.musteri_durum)));', 'rpZiyaretListesiModal("Yeniden Kazanım", ziyaretler.filter(z => ["PASIF_NOKTA","RISKLI_NOKTA"].includes(z.musteri_durum)));'),
]:
    assert s.count(a) == 1, "drill anchor bulunamadi: %s" % a[:40]
    s = s.replace(a, b, 1)

# M3) Tanımlar paneli (Özet sonuna)
OLD3 = '''          })() : ""}
        </div>`;'''
NEW3 = '''          })() : ""}
          <details style="margin-top:14px;border:1px solid #e5e7eb;border-radius:10px;background:#fff">
            <summary style="cursor:pointer;padding:11px 12px;font-size:12px;font-weight:700;color:#374151">ⓘ Tanımlar (metrik açıklamaları)</summary>
            <div style="padding:0 12px 12px;font-size:12px;color:#475569;line-height:1.75">
              <div><b>Tamamlanan Ziyaret:</b> Dönemde tamamlanan ziyaret sayısı (aynı müşteriye 2 ziyaret = 2).</div>
              <div><b>Planlanan:</b> Planlanmış ama henüz tamamlanmamış ziyaret.</div>
              <div><b>Ulaşılan Müşteri:</b> Dönemde en az 1 ziyaret yapılan <b>farklı</b> müşteri sayısı.</div>
              <div><b>Yeni Müşteri Ziyareti:</b> Durumu "Yeni Nokta" olan müşterilere yapılan ziyaret.</div>
              <div><b>Yeniden Kazanım:</b> Durumu Pasif/Eski/Riskli müşterilere yapılan ziyaret (uykuda/riskli müşteriyi geri kazanma).</div>
              <div><b>Yeni Kayıt:</b> Dönemde sisteme ilk kez eklenen <b>farklı</b> müşteri (gerçek yeni edinim).</div>
              <div><b>Win Rate:</b> Kazanılan ÷ (Kazanılan + Kaybedilen) teklif oranı.</div>
              <div style="margin-top:7px;padding-top:7px;border-top:1px dashed #e5e7eb"><b>Durum</b> (Yeni/Aktif/Pasif/Eski/Riskli) ERP satış geçmişinden <b>otomatik</b> türetilir, elle değişmez. Kartın <b>arşiv</b> (silinmiş/birleştirilmiş) durumundan farklıdır.</div>
            </div>
          </details>
        </div>`;'''
assert s.count(OLD3) == 1, "tanimlar anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_DEFS_V1 (mobil)")
