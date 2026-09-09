# -*- coding: utf-8 -*-
# RAPOR_COVERAGE_DK_V1 (masaustu) — Özet'e Portföy Kapsamı barı.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_COVERAGE_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '${sech("Teklif Özeti", "#6d4bd6", "Dönemde oluşturulan tekliflerin durumu — toplam, kazanılan, kaybedilen, açık adet ve kazanma oranı. Oklar önceki döneme göre.")}'
NEW = '''${(() => { const pf = Number(o.portfoy||0), ul = Number(o.benzersiz_nokta||0); const pct = pf ? Math.min(100, Math.round(100*ul/pf)) : 0; return `<!--RAPOR_COVERAGE_DK_V1--><div class="dk-card" style="margin-top:6px">
        <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:7px"><span style="font-size:13px;font-weight:700">📍 Portföy Kapsamı</span><span class="sub2">${ul} / ${pf} müşteri · dönemde portföyün <b style="color:var(--mavi)">%${pct}</b>'ine ulaşıldı${pf&&ul<pf?` · ${pf-ul} hiç ziyaret edilmedi`:""}</span></div>
        <div style="height:12px;background:var(--gri-z,#f1f5f9);border-radius:6px;overflow:hidden"><div style="height:100%;width:${pct}%;background:${pct>=60?"var(--yesil-p)":pct>=30?"var(--mavi)":"var(--sari-p)"};border-radius:6px"></div></div>
      </div>`; })()}
      ${sech("Teklif Özeti", "#6d4bd6", "Dönemde oluşturulan tekliflerin durumu — toplam, kazanılan, kaybedilen, açık adet ve kazanma oranı. Oklar önceki döneme göre.")}'''
assert s.count(OLD) == 1, "anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_COVERAGE_DK_V1 (masaustu)")
