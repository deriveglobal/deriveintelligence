#!/usr/bin/env python3
# BEYIN_IKI_IS — CEO Assistant sistem haritasina İki-İş katmani ekle (tenant-agnostik KURAL/YOL; sayi YOK).
#   Asistan artik marj/ciro/nakit/DSO sorularinda tüketici=PSR ayrimini, ciro=tüm-sirket vs marj=lastik-isi farkini,
#   aylik marj trendini ve is-bazinda DSO teshisini onden bilir. Tenant sayilari canli hesaplanir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BEYIN_IKI_IS" in s:
    print("[skip] BEYIN_IKI_IS zaten var"); sys.exit(0)

ANCHOR = r'\n- KENDINI-TANITAN HAFIZA: sistemin su an NE bildigini'
NEW = (
    r'\n- IKI-IS KOKPITI (yeni, /app Finans odasi canli /api/bi/kokpit-iki): is TEK degil IKI ayri. TUKETICI = kategori_segment(kategori)=\'PSR\' (bi_marj_atom); TICARI = geri kalan (TBR/OTR/YENILEME/LSR/IND/AG). Canli ay tuk/tic = bi_satis_faturalari.grup_adi (LASTIK TUKETICI / LASTIK TICARI). Marj/ciro/nakit sorularinda BU ayrimi kullan. CIRO = TUM SIRKET (tum grup_adi, bi_satis_faturalari); MARJ/KAR = YALNIZ lastik isi (bi_marj_atom) — karistirma. Bu ay = gercek takvim ayi (ciro/marj canli, muhasebe/donem maliyeti bazi, ay kapaninca kesinlesir). Ayrinti: bi_insa_gunlugu adim=IKI_IS_KOKPIT.'
    r'\n- MARJ TRENDI: "marj neden dustu/degisti" sorusunda 12-ay ORTALAMAYA degil bi_marj_atom AYLIK trende bak (tük/tic ayri, kategori_segment); hangi ay hangi is kolunun dondugunu goster. Tek ortalama iniş/çıkışı gizler. (IKI_IS_MARJ_TREND)'
    r'\n- DSO/TAHSILAT (is-bazinda): iki AYRI soru — OLCULEN odeme suresi (bi_tahsilat son12_suresi, tutar-agirlikli, gercek fatura->odeme) vs DSO (bakiye/gunluk-satis; gunluk=12ay ciro/365). Yuksek DSO tek basina kotu tahsilat DEGIL: olculen hizli ama DSO yuksekse fark birkac ESKI TAKILMIS HESAP (yogunlasma), sistemik degil -> o hesabi kapat. Fark kucuk/yayilmis -> genel vade disiplini. Bakiye/gecikmis bi_musteri_risk; sinif bi_satis_faturalari×bi_marj_atom. Sinifsiz = son12 lastik alisi olmayan (dormant/lastik-disi). Ayrinti: bi_insa_gunlugu adim=IKI_IS_DSO.'
    r'\n- KENDINI-TANITAN HAFIZA: sistemin su an NE bildigini'
)

assert ANCHOR in s, "HATA: sistem haritasi KENDINI-TANITAN anchor bulunamadi"
assert s.count(ANCHOR) == 1, "HATA: anchor tek degil (%d)" % s.count(ANCHOR)
s = s.replace(ANCHOR, NEW, 1) + "\n/* BEYIN_IKI_IS */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] BEYIN_IKI_IS — CEO Assistant sistem haritasina İki-İş/marj-trend/DSO katmani eklendi")
