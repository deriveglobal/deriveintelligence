#!/usr/bin/env python3
# saha_fix_5 (omurga_78) — Teklif ekranina VADE (odeme kosulu). Rep raporu (Eftal): "SAP'de yer alan vadeler".
# Veri-gudumlu vade listesi (master_musteri.odeme_kosulu normalize; split 30-60-90 destekli) + form combobox + saha_teklif'e yaz.
# saha_teklif.vade_gun/vade_turu kolonlari ZATEN VAR (migration gerekmez). SADECE sunucu tarafi bu patch; saha.js ayrica.
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

E = []
# 1) _vadeParse helper (module-scope)
E.append(("async function _ownerAlarmEmail() {",
'''// VADE_V1 — odeme kosulu metnini {gun, turu}'ya cevirir. Split (30-60-90) = ortalama gun + tam etiket.
function _vadeParse(raw) {
  const s = String(raw == null ? "" : raw).trim();
  if (!s) return { gun: null, turu: null };
  if (/mal\\s*mukabil/i.test(s)) return { gun: 0, turu: "Mal Mukabili" };
  if (/vesaik/i.test(s)) return { gun: 0, turu: "Vesaik Mukabili" };
  if (/pe[şs]in|sanal\\s*pos|havale|kredi\\s*kart/i.test(s) && !/\\d+\\s*[Gg][üu]n/.test(s)) return { gun: 0, turu: "Peşin" };
  const nums = s.match(/\\d{1,3}/g);
  const pureNum = /^[\\d\\s\\-+/.]+$/.test(s);
  const hasKw = /[Gg][üu]n|[Vv]ade/.test(s);
  if (nums && nums.length > 1 && (hasKw || pureNum)) {
    const arr = nums.map(Number);
    return { gun: Math.round(arr.reduce((a, b) => a + b, 0) / arr.length), turu: arr.join("-") + " Gün Vade" };
  }
  if (nums && nums.length === 1 && (hasKw || pureNum)) { const g = Number(nums[0]); return { gun: g, turu: g + " Gün Vade" }; }
  return { gun: null, turu: s.slice(0, 40) };
}

async function _ownerAlarmEmail() {'''))
# 2) secenekler -> vadeler
E.append(('''      sendJson(response, 200, {
        markalar: markalar.rows.map(r => r.marka),
        kategoriler: [["BINEK", "Binek"], ["TICARI", "Ticari"]],
        sezonlar: [["YAZ", "Yaz"], ["KIS", "Kış"], ["4MEV", "4 Mevsim"]],
        jant_gruplari: [["13-16", '13"–16"'], ["17+", '17" ve üzeri']],
        alt_gruplar: [["UZUN_YOL", "Uzun Yol"], ["HAFRIYAT", "Hafriyat"], ["YOL_DISI", "Yol Dışı"]]
      });
      return;''',
'''      // VADE_V1 — SAP odeme kosullari -> teklif vade listesi (veri-gudumlu, split destekli)
      let vadeler = [];
      try {
        const _vr = await query("SELECT odeme_kosulu, count(*) n FROM master_musteri WHERE tenant_id::text=$1::text AND odeme_kosulu IS NOT NULL GROUP BY 1", [session.tenantId]);
        const _vm = new Map();
        for (const r of _vr.rows) {
          const v = _vadeParse(r.odeme_kosulu);
          if (!v.turu || v.gun == null) continue;
          if (!_vm.has(v.turu)) _vm.set(v.turu, { label: v.turu, gun: v.gun, n: 0 });
          _vm.get(v.turu).n += Number(r.n);
        }
        vadeler = [...(_vm.values())].sort((a, b) => a.gun - b.gun || b.n - a.n);
      } catch (e) { console.error("[vadeler]", e && e.message); }
      sendJson(response, 200, {
        markalar: markalar.rows.map(r => r.marka),
        kategoriler: [["BINEK", "Binek"], ["TICARI", "Ticari"]],
        sezonlar: [["YAZ", "Yaz"], ["KIS", "Kış"], ["4MEV", "4 Mevsim"]],
        jant_gruplari: [["13-16", '13"–16"'], ["17+", '17" ve üzeri']],
        alt_gruplar: [["UZUN_YOL", "Uzun Yol"], ["HAFRIYAT", "Hafriyat"], ["YOL_DISI", "Yol Dışı"]],
        vadeler
      });
      return;'''))
# 3) teklif INSERT setup + columns + values
E.append(('''      const ilk = lines[0];

      // Insert header (first-line fields for legacy compat, aggregate totals)
      const hdr = await query(`
        INSERT INTO saha_teklif (tenant_id, musteri_id, ziyaret_id, iskonto_talep_id, rep_id,
                                 marka, model, ebat, kategori, sezon, jant_grubu, alt_grup,
                                 adet, birim_fiyat, toplam_tutar, iskonto_orani, notlar, created_by,
                                 kalem_kodu, liste_fiyati, tesvik_garantili_pct, tesvik_maksimum_pct,
                                 tedarikci_destek_pct, kampanya_id, kampanya_indirim_turu,
                                 kampanya_indirim_deger, musteri_ek_iskonto_pct, kaynak, durum)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$5,$18,
                $19,$20,$21,$22,$23,$24,$25,$26,$27,'TASLAK')''',
'''      const ilk = lines[0];
      const _vd = _vadeParse(p.vade_turu != null ? p.vade_turu : p.vade);  // VADE_V1

      // Insert header (first-line fields for legacy compat, aggregate totals)
      const hdr = await query(`
        INSERT INTO saha_teklif (tenant_id, musteri_id, ziyaret_id, iskonto_talep_id, rep_id,
                                 marka, model, ebat, kategori, sezon, jant_grubu, alt_grup,
                                 adet, birim_fiyat, toplam_tutar, iskonto_orani, notlar, created_by,
                                 kalem_kodu, liste_fiyati, tesvik_garantili_pct, tesvik_maksimum_pct,
                                 tedarikci_destek_pct, kampanya_id, kampanya_indirim_turu,
                                 kampanya_indirim_deger, musteri_ek_iskonto_pct, kaynak, vade_gun, vade_turu, durum)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$5,$18,
                $19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,'TASLAK')'''))
# 4) teklif INSERT params
E.append(('''          ilk.ekIsk > 0 ? ilk.ekIsk : null,
          (p.ziyaret_id ? 'ZIYARET' : (['TELEFON','WHATSAPP','EMAIL','DIGER'].includes(String(p.kaynak||'').toUpperCase()) ? String(p.kaynak).toUpperCase() : 'DIGER'))]);''',
'''          ilk.ekIsk > 0 ? ilk.ekIsk : null,
          (p.ziyaret_id ? 'ZIYARET' : (['TELEFON','WHATSAPP','EMAIL','DIGER'].includes(String(p.kaynak||'').toUpperCase()) ? String(p.kaynak).toUpperCase() : 'DIGER')),
          _vd.gun, _vd.turu]);'''))
# 5) musteri list -> erp_odeme_kosulu (varsayilan icin)
E.append(('''               mm2.son_bakiye    AS erp_bakiye,
               mm2.vadesi_gecmis AS erp_vadesi_gecmis,''',
'''               mm2.son_bakiye    AS erp_bakiye,
               mm2.vadesi_gecmis AS erp_vadesi_gecmis,
               mm2.odeme_kosulu  AS erp_odeme_kosulu,'''))

if "VADE_V1" in srv:
    sys.exit("ZATEN VAR: saha_fix_5 uygulanmis gibi.")
for i, (o, n) in enumerate(E, 1):
    if o not in srv:
        sys.exit("HATA: %d. blok bulunamadi (elle bak)." % i)
    if srv.count(o) != 1:
        sys.exit("UYARI: %d. blok %d kez — belirsiz." % (i, srv.count(o)))
    srv = srv.replace(o, n, 1)

shutil.copy2(S, S + ".vade.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".vade.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .vade.bak)")
print("OK: teklif VADE eklendi (veri-gudumlu liste + saha_teklif.vade_gun/vade_turu). saha.js -> shells/, sonra build.")
