# -*- coding: utf-8 -*-
# TEKLIF_ONERI_V2 — ucu owner-cockpit icin hazirla:
#   (a) yetki ["rep",...] -> ["manager","admin"] (rep kor; uc owner-only).
#   (b) kalem_kodu yoksa marka+ebat'tan coz (teklif satirlarinda kalem_kodu YOK, marka/ebat VAR).
#   (c) fiyat param verilirse rep fiyatinin SAGLIGI (maliyet bazli) + rep_marj don.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "TEKLIF_ONERI_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)
if "TEKLIF_ONERI_V1" not in s:
    print("HATA: TEKLIF_ONERI_V1 yok — once faz1'i deploy et."); sys.exit(1)

# (A) param parse + gate + marka/ebat -> kalem cozumu
OLD_A = '''      const session = await requireSahaAccess(request, ["rep", "manager", "admin"]);
      const T = session.tenantId;
      const kalem = (url.searchParams.get("kalem") || "").trim();
      const musteriId = (url.searchParams.get("musteri_id") || "").trim();
      if (!kalem) { sendJson(response, 400, { error: "kalem zorunlu" }); return; }'''
NEW_A = '''      const session = await requireSahaAccess(request, ["manager", "admin"]);  /* TEKLIF_ONERI_V2 */
      const T = session.tenantId;
      let kalem = (url.searchParams.get("kalem") || "").trim();
      const markaQ = (url.searchParams.get("marka") || "").trim();
      const ebatQ = (url.searchParams.get("ebat") || "").trim();
      const fiyatQ = Number(url.searchParams.get("fiyat"));
      const musteriId = (url.searchParams.get("musteri_id") || "").trim();
      if (!kalem && markaQ && ebatQ) {  /* TEKLIF_ONERI_V2 — teklif satiri marka+ebat verir, kalem_kodu'na coz */
        try {
          const kr = await query("SELECT kalem_kodu FROM bi_marj_atom WHERE tenant_id::text=$1 AND upper(marka)=upper($2) AND ebat=$3 AND ay>=(CURRENT_DATE-INTERVAL '18 months') GROUP BY kalem_kodu ORDER BY SUM(adet) DESC LIMIT 1", [T, markaQ, ebatQ]);
          if (kr.rows[0]) kalem = kr.rows[0].kalem_kodu;
        } catch (e) {}
      }
      if (!kalem) { sendJson(response, 200, { veri: false, mesaj: "Bu kalem icin eslesen SKU bulunamadi.", marka: markaQ || null, ebat: ebatQ || null }); return; }'''
assert s.count(OLD_A) == 1, "A anchor count=%d" % s.count(OLD_A)
s = s.replace(OLD_A, NEW_A, 1)

# (B) rep fiyatinin sagligi + rep_marj -> payload'a ekle
OLD_B = '''      const base = { veri: true, ad: r.ad, marka: r.marka, ebat: r.ebat, oneri: r.oneri, durum: r.durum, vade_menu: r.vade_menu, hedef_taban: r.hedef_taban, piyasa: { lo: r.lo, med: r.med, hi: r.hi }, rakip: r.rakip || null, erp_bagli: !!musteriKodu };'''
NEW_B = '''      let saglik = null, rep_marj = null;  /* TEKLIF_ONERI_V2 — rep fiyatinin maliyet-bazli sagligi */
      if (isFinite(fiyatQ) && fiyatQ > 0 && r.floorCost > 0) {
        rep_marj = Math.round((fiyatQ - r.floorCost) / fiyatQ * 1000) / 10;
        saglik = fiyatQ < r.floorCost ? "kirmizi" : (fiyatQ < r.floorCost / 0.88 ? "amber" : "yesil");
      }
      const base = { veri: true, ad: r.ad, marka: r.marka, ebat: r.ebat, oneri: r.oneri, durum: r.durum, vade_menu: r.vade_menu, hedef_taban: r.hedef_taban, piyasa: { lo: r.lo, med: r.med, hi: r.hi }, rakip: r.rakip || null, saglik: saglik, rep_marj: rep_marj, erp_bagli: !!musteriKodu };'''
assert s.count(OLD_B) == 1, "B anchor count=%d" % s.count(OLD_B)
s = s.replace(OLD_B, NEW_B, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] TEKLIF_ONERI_V2")
