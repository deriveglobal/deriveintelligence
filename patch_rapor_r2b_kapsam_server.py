# -*- coding: utf-8 -*-
# RAPOR_R2B_KAPSAM (server) — Kural 6 (dedup): Kapsam ciro TOPLAMLARI (beyaz_ciro manşet + şehir + segment + temsilci)
#   ayni musteri_kodu birden fazla aktif musteride ciro'yu MUKERRER sayiyordu (~%8,6 sisme, view'de kanitlandi).
#   Cozum: satir bazinda _ciroD (ilk kodu'da gercek ciro, tekrarda 0); TOPLAMLAR _ciroD kullanir. SAYIMLAR (portfoy/beyaz_sayi)
#   + liste + sort + isBeyaz uyelik DEGISMEZ (gercek ciro'ya bakar). Yalniz toplamlar duzelir (dogru yonde, hafif duser).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAPOR_R2B_KAPSAM" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) rows sonrasi dedup pass (Kapsam'a ozel anchor)
A = '''      const rows = r.rows;
      const portfoy = rows.length;'''
assert s.count(A) == 1, "kapsam rows anchor=%d" % s.count(A)
s = s.replace(A, '''      const rows = r.rows;
      /* RAPOR_R2B_KAPSAM — Kural 6 dedup: ayni musteri_kodu ciro'yu toplamlarda MUKERRER saymasin. _ciroD yalniz TOPLAMLARDA kullanilir. */
      { const _seenK = new Set(); for (const x of rows) { const _k = x.musteri_kodu; x._ciroD = (_k && _seenK.has(_k)) ? 0 : (Number(x.ciro) || 0); if (_k) _seenK.add(_k); } }
      const portfoy = rows.length;''', 1)

# 2) 4 ciro toplam sitesi -> _ciroD
B = 'const beyazCiro = beyaz.reduce((a, x) => a + Number(x.ciro), 0);'
assert s.count(B) == 1, "beyazCiro anchor=%d" % s.count(B)
s = s.replace(B, 'const beyazCiro = beyaz.reduce((a, x) => a + (x._ciroD || 0), 0);  /* RAPOR_R2B_KAPSAM dedup */', 1)

C = 'g.beyaz_ciro += Number(x.ciro)'
nC = s.count(C)
assert nC == 3, "beyaz_ciro += anchor=%d (sehir+segment+temsilci=3 bekle)" % nC
s = s.replace(C, 'g.beyaz_ciro += (x._ciroD || 0)')  # 3 site (sehir/segment/temsilci)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_R2B_KAPSAM (server) — ciro toplamlarina Kural 6 dedup (_ciroD; 4 site)")
