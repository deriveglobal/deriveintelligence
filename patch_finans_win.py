#!/usr/bin/env python3
# FINANS_WIN_V1 — /api/bi/finans/oda: akis kartlari ?win zaman seciciye yanit verir (net satis/smm/brut kar/marj/marka/catal/kar/sizinti),
# bilanco+dongu (v_finans: dso/dio/dpo/ccc/twc/alacak/borc) + stok + net gecikmis DAIMA anlik (donemden bagimsiz), trend daima 12 ay.
# + 4 eksik metrik: olu stok, siparis bekleyen, olculen tahsilat, fiyat sizintisi. Geriye-uyumlu (eski client ?win'siz = 12 ay).
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
orig = src; changes = []
def apply(name, new, old):
    global src
    if new in src: changes.append(f"SKIP: {name}"); return
    c = src.count(old); assert c == 1, f"ANCHOR COUNT != 1 ({c}): {name}"
    src = src.replace(old, new); changes.append(f"OK: {name}")

# A) W dinamik (win) + W12 sabit
apply("A W dinamik",
  """      const _win = (url.searchParams.get('win') || '12'); const _wn = { '3':3,'6':6,'12':12 }[_win] || 12;  /* FINANS_WIN_V1 */
      const W = (_win==='buay') ? "ay >= date_trunc('month',CURRENT_DATE)" : (_win==='yb') ? "ay >= date_trunc('year',CURRENT_DATE)" : "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - "+_wn+"*INTERVAL '1 month') AND ay <= (SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1)";
      const W12 = "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - 12*INTERVAL '1 month') AND ay <= (SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1)";""",
  """      const W = "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - 12*INTERVAL '1 month') AND ay <= (SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1)";""")

# B) trend -> W12 (daima 12 ay)
apply("B trend W12",
  '::float8 bk FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W12 + " GROUP BY ay ORDER BY ay"',
  '::float8 bk FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W + " GROUP BY ay ORDER BY ay"')

# C) core akis pencerelenir (net satis/smm/brut kar/marj) + win
apply("C core akis",
  """      const dio = N(v.dio);
      const _fl = (await query("SELECT sum(ciro) ns, sum(ciro-brut_kar) smm, sum(brut_kar) bk, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W, [String(T)])).rows[0] || {};  /* FINANS_WIN_V1 akis */
      const core = {
        net_satis_lastik: M1(_fl.ns), ciro_sirket: M1(v.ciro_tum_sirket), smm: M1(_fl.smm),
        brut_kar: M1(_fl.bk), marj_pct: N(_fl.mj), win: _win, ticari_alacaklar: M1(v.ar_net),""",
  """      const dio = N(v.dio);
      const core = {
        net_satis_lastik: M1(v.net_satis_lastik), ciro_sirket: M1(v.ciro_tum_sirket), smm: M1(v.smm),
        brut_kar: M1(v.brut_kar), marj_pct: N(v.marj_pct), ticari_alacaklar: M1(v.ar_net),""")

# D) stok: olu + siparis
apply("D stok olu+siparis",
  """      const _olu = (await query("SELECT round(sum(bsd.toplam_deger)/1e5)/10 deger, count(*)::int sku FROM bi_stok_durumu bsd WHERE bsd.tenant_id::text=$1 AND bsd.export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=$1) AND bsd.grup_adi ILIKE 'LASTIK%' AND bsd.eldeki_miktar>0 AND NOT EXISTS (SELECT 1 FROM bi_stok_hareket h WHERE h.tenant_id::text=$1 AND h.kalem_kodu=bsd.kalem_kodu AND h.cikis>0 AND h.belge_tarihi>=now()-INTERVAL '90 days')", [String(T)])).rows[0] || {};  /* FINANS_WIN_V1 olu */
      const _sip = (await query("SELECT round(sum(siparis_miktar * CASE WHEN eldeki_miktar>0 THEN toplam_deger/eldeki_miktar ELSE 0 END)/1e5)/10 deger, round(sum(siparis_miktar))::int adet FROM bi_stok_durumu WHERE tenant_id::text=$1 AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=$1) AND grup_adi ILIKE 'LASTIK%' AND siparis_miktar>0", [String(T)])).rows[0] || {};  /* FINANS_WIN_V1 siparis */
      const stok = { toplam: Math.round(_sk.reduce((a, r) => a + Number(r.d || 0), 0) / 1e5) / 10, kirilim: _sk.map(r => ({ grup: r.grup_adi, deger: M1(r.d) })), olu: { deger: N(_olu.deger), sku: N(_olu.sku) }, siparis: { deger: N(_sip.deger), adet: N(_sip.adet) } };""",
  """      const stok = { toplam: Math.round(_sk.reduce((a, r) => a + Number(r.d || 0), 0) / 1e5) / 10, kirilim: _sk.map(r => ({ grup: r.grup_adi, deger: M1(r.d) })) };""")

# E) gecikmis: olculen tahsilat
apply("E gecikmis olculen",
  """      const _ot = (await query("SELECT round(sum(son12_suresi*son12_tutar)/nullif(sum(son12_tutar),0)) gun, round(sum(son12_gec_orani*son12_tutar)/nullif(sum(son12_tutar),0)) gec FROM bi_tahsilat WHERE tenant_id::text=$1 AND musteri_mi AND son12_tutar>0", [String(T)])).rows[0] || {};  /* FINANS_WIN_V1 olculen */
      const gecikmis = { brut: Math.round(gBrut / 1e5) / 10, net: Math.round(gNet / 1e5) / 10, top: top, olculen: { gun: N(_ot.gun), gec_orani: N(_ot.gec) } };""",
  """      const gecikmis = { brut: Math.round(gBrut / 1e5) / 10, net: Math.round(gNet / 1e5) / 10, top: top };""")

# F) sizinti + data.win
apply("F sizinti + data",
  """      const _sz = (await query("SELECT round(sum(-brut_kar) FILTER (WHERE brut_kar<0)/1e5)/10 tutar, count(*) FILTER (WHERE brut_kar<0)::int kalem, round(100.0*count(*) FILTER (WHERE brut_kar<0)/nullif(count(*),0),1)::float8 pct FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W, [String(T)])).rows[0] || {};  /* FINANS_WIN_V1 sizinti */
      const sizinti = { tutar: N(_sz.tutar), kalem: N(_sz.kalem), pct: N(_sz.pct) };
      const data = { as_of: _a ? _a.a : null, win: _win, core, stok, gecikmis, marka, catal, kar, trend, pencere, sizinti, aging: null, motor_trend: null };""",
  """      const data = { as_of: _a ? _a.a : null, core, stok, gecikmis, marka, catal, kar, trend, pencere, aging: null, sizinti: null, motor_trend: null };""")

if src == orig: print("DEGISIKLIK YOK")
else:
    bak = PATH + ".bak_finanswin_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f: f.write(src)
for c in changes: print(" ", c)
print("FINANS_WIN_V1 marker:", src.count("FINANS_WIN_V1"))
