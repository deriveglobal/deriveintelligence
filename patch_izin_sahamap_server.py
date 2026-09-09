# -*- coding: utf-8 -*-
# IZIN_SAHAMAP_V1 (server) — BÜTÜNSEL Saha yetkilendirmesi:
#   Tek merkezi harita (route -> izin veren sekme kümesi) + requireSahaAccess içinde TEK
#   uygulama noktası. Eşleşen tüm rotalar aynı anda denetlenir; altyapı/webhook/paylaşımlı
#   yardımcı rotalar açık kalır (fail-open); departman boşsa role fallback (client ile birebir);
#   admin bypass. "requireBiDept" ile aynı felsefe, Saha'nın tamamına.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "IZIN_SAHAMAP_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "async function requireSahaAccess(req, allowedRoles = null) {" in s, "requireSahaAccess yok"

o = "    return { ...session, sahaRole };\n  }"
assert s.count(o) == 1, "requireSahaAccess return anchor=%d" % s.count(o)

MAP_AND_FN = r'''    const _sess = { ...session, sahaRole };
    _enforceSahaDept(req, _sess);  /* IZIN_SAHAMAP_V1 */
    return _sess;
  }

  /* IZIN_SAHAMAP_V1 — route -> izin veren sekme(ler). Boş departman = role fallback; admin bypass;
     haritada olmayan rota = açık (altyapı/webhook/paylaşımlı yardımcı). Paylaşımlı çekirdek uçlar
     (ziyaret/müşteri/teklif) permissif küme: ancak ilgili sekmelerin HİÇBİRİ yoksa 403. */
  const SAHA_DEPT_MAP = {
    "/api/saha/bugun": ["bugun"],
    "/api/saha/gunluk-baslangic": ["bugun"],
    "/api/saha/ziyaretler": ["ziyaretler", "bugun", "plan", "rapor"],
    "/api/saha/musteriler": ["musteriler", "plan", "teklif", "ziyaretler"],
    "/api/saha/kontrol-musteriler": ["musteriler"],
    "/api/saha/eslestirilmemis": ["musteriler"],
    "/api/saha/mukerrerler": ["musteriler"],
    "/api/saha/notlar": ["notlarim", "plan"],
    "/api/saha/teklifler": ["teklif", "rapor", "bugun"],
    "/api/saha/iskonto-secenekler": ["teklif"],
    "/api/saha/iskonto-kurallar": ["teklif"],
    "/api/saha/tesvik-bilgi": ["teklif"],
    "/api/saha/musteri-destek": ["teklif"],
    "/api/saha/kampanya-ara": ["teklif"],
    "/api/saha/stok-durumu": ["teklif"],
    "/api/saha/rep-brain": ["rep-brain"],
    "/api/saha/rep-profil": ["rep-brain"],
    "/api/saha/harita": ["harita"],
    "/api/saha/harita-il-metrikler": ["harita"],
    "/api/saha/harita-il-cariler": ["harita"],
    "/api/saha/harita-il-ozet": ["harita"],
    "/api/saha/harita-musteri-brief": ["harita"],
    "/api/saha/harita-musteri-ozet": ["harita"],
    "/api/saha/harita-musteriler": ["harita"],
    "/api/saha/piyasa-dosya": ["piyasa"],
    "/api/saha/rakip-teklif": ["piyasa", "rakip"],
    "/api/saha/rakip-teklif-ozet": ["piyasa", "rakip"],
    "/api/saha/oneriler": ["oneriler", "bugun", "sistem"],
    "/api/saha/duyurular": ["duyurular", "piyasa"],
    "/api/saha/konusmalar": ["mesajlar"],
    "/api/saha/konusmalar/coklu": ["mesajlar"],
    "/api/saha/konusmalar/yayim": ["mesajlar"],
    "/api/saha/yayim-okuyanlar": ["mesajlar"],
    "/api/saha/rapor/ozet": ["rapor"],
    "/api/saha/rapor/bolge-marka": ["rapor"],
    "/api/saha/rapor/rakip": ["rapor"],
    "/api/saha/rapor/rep-performans": ["rapor"],
    "/api/saha/rapor/teklif": ["rapor", "teklif"],
    "/api/saha/rapor/ziyaret-ciro": ["ciro"],
    "/api/saha/rapor/risk-saha": ["risk"],
    "/api/saha/rapor/sabah-rotam": ["rotam"]
  };
  const _SAHA_NEWK = ["ciro", "risk", "rotam"];
  function _enforceSahaDept(req, sess) {  /* IZIN_SAHAMAP_V1 */
    if (sess.sahaRole === "admin") return;                       // admin = tam erisim
    let pth;
    try { pth = new URL(req.url, "http://localhost").pathname; } catch (e) { return; }
    const need = SAHA_DEPT_MAP[pth];
    if (!need) return;                                           // haritada yok = acik
    const depts = Array.isArray(sess.permissions && sess.permissions.departments) ? sess.permissions.departments : [];
    if (!depts.length) return;                                   // bos = role fallback (client ile ayni)
    if (need.some(d => depts.includes(d))) return;               // ilgili sekmelerden biri var
    const needNew = need.filter(d => _SAHA_NEWK.includes(d));    // yeni anahtar gecis kurali (ciro/risk/rotam)
    if (needNew.length && !_SAHA_NEWK.some(k => depts.includes(k))) {
      if (sess.sahaRole === "manager") return;                  // manager varsayilani = hepsi
      if (sess.sahaRole === "rep" && needNew.includes("rotam")) return;  // rep varsayilani = rotam
    }
    throw Object.assign(new Error("Bu bölüm için yetkiniz yok."), { statusCode: 403 });
  }'''

s = s.replace(o, MAP_AND_FN, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_SAHAMAP_V1 (server) — merkezi SAHA_DEPT_MAP + requireSahaAccess uygulamasi")
