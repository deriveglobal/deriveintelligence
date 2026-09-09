# -*- coding: utf-8 -*-
# RAPOR_COVERAGE_V1 (mobil) — Özet'e Portföy Kapsamı barı (ulaşılan / portföy %).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_COVERAGE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '          ${bBaslik("Teklif Özeti","#8b5cf6","Dönem içinde oluşturulan tekliflerin durumu — açık, kazanılan ve kaybedilen adet ile toplam ciro.")}'
NEW = '''          ${(() => { const pf = Number(o.portfoy||0), ul = Number(o.benzersiz_nokta||0); const pct = pf ? Math.min(100, Math.round(100*ul/pf)) : 0; return `<!--RAPOR_COVERAGE_V1--><div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:12px;margin-top:10px">
            <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px"><span style="font-size:12px;font-weight:700;color:#374151">📍 Portföy Kapsamı</span><span style="font-size:12px;color:#64748b">${ul} / ${pf} müşteri</span></div>
            <div style="height:10px;background:#f1f5f9;border-radius:5px;overflow:hidden"><div style="height:100%;width:${pct}%;background:${pct>=60?"#10b981":pct>=30?"#0ea5e9":"#f59e0b"};border-radius:5px"></div></div>
            <div style="font-size:11px;color:#64748b;margin-top:5px">Dönemde portföyün <b style="color:#0284c7">%${pct}</b>'ine ulaşıldı${pf&&ul<pf?` · <b>${pf-ul}</b> müşteri hiç ziyaret edilmedi`:""}.</div>
          </div>`; })()}
          ${bBaslik("Teklif Özeti","#8b5cf6","Dönem içinde oluşturulan tekliflerin durumu — açık, kazanılan ve kaybedilen adet ile toplam ciro.")}'''
assert s.count(OLD) == 1, "anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_COVERAGE_V1 (mobil)")
