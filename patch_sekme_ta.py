# -*- coding: utf-8 -*-
# SEKME_CAP_V1 (tenant-admin.js) — Saha sekmeleri artik BIRINCIL capability.
#   Grid'e "Sekmeler" grubu (ozet/ciro/risk/etki/portfoy/rotam/kapsam/pipeline/pazar gercek adlariyla);
#   ciro/risk/rotam/kapsam "Yonetim & Analiz"den TASINDI (mukerrer olmasin); ozet lock'a; DEFAULTS rep+manager
#   etki/portfoy/pipeline/pazar/ozet. Grid MODULES.saha.groups'tan besleniyor -> Bolumler/Kisiler ekraninda gorunur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "SEKME_CAP_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) "Sekmeler" grubunu groups[] basina ekle (Saha grubundan once)
SAHA_GRP = '''      groups: [
        ["Saha", [["bugun", "Bugün"]'''
assert s.count(SAHA_GRP) == 1, "Saha grubu anchor=%d" % s.count(SAHA_GRP)
NEW_GRP = '''      groups: [
        ["Sekmeler", [["ozet", "📊 Özet"], ["ciro", "💰 Ciro"], ["risk", "🚨 Risk"], ["etki", "📈 Saha ROI"], ["portfoy", "🩺 Portföy"], ["rotam", "🌅 Rotam"], ["kapsam", "📍 Kapsam"], ["pipeline", "💼 Pipeline"], ["pazar", "🎯 Pazar"]]],  /* SEKME_CAP_V1 — saha sekmeleri = birincil yetki */
        ["Saha", [["bugun", "Bugün"]'''
s = s.replace(SAHA_GRP, NEW_GRP, 1)

# 2) "Yonetim & Analiz" grubundan ciro/risk/rotam/kapsam kaldir (Sekmeler'e tasindi; mukerrer id olmaz)
YA_OLD = '''["Yönetim & Analiz", [["rapor", "Rapor"], ["ciro", "Ciro"], ["risk", "Risk Radarı"], ["rotam", "Bugün Sahada"], ["kapsam", "Kapsam & Beyaz Alan"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"]]]'''
assert s.count(YA_OLD) == 1, "Yonetim&Analiz anchor=%d" % s.count(YA_OLD)
YA_NEW = '''["Yönetim & Analiz", [["rapor", "Rapor"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"]]]  /* SEKME_CAP_V1 relokasyon: ciro/risk/rotam/kapsam -> Sekmeler */'''
s = s.replace(YA_OLD, YA_NEW, 1)

# 3) ozet -> lock (kilitli: acilis sekmesi kapatilamaz)
LOCK_OLD = '      lock: ["temsilciler", "sistem"],'
assert s.count(LOCK_OLD) == 1, "saha lock anchor=%d" % s.count(LOCK_OLD)
s = s.replace(LOCK_OLD, '      lock: ["ozet", "temsilciler", "sistem"],  /* SEKME_CAP_V1 — ozet kilitli */', 1)

# 4) DEFAULTS rep + manager: yeni sekme anahtarlari (regresyon yok — bugun de goruyorlar)
REP_OLD = '"duyurular", "mesajlar", "oneriler", "rotam"],  /* YETKI_FAZ1 */  /* IZIN_YENIMODUL_V1 */'
assert s.count(REP_OLD) == 1, "DEFAULTS rep anchor=%d" % s.count(REP_OLD)
s = s.replace(REP_OLD, '"duyurular", "mesajlar", "oneriler", "rotam", "etki", "portfoy", "pipeline", "pazar", "ozet"],  /* SEKME_CAP_V1 */  /* YETKI_FAZ1 */  /* IZIN_YENIMODUL_V1 */', 1)

MGR_OLD = '"rotam", "kapsam"],  /* YETKI_FAZ1 */  /* KAPSAM_TAD_V1 */  /* IZIN_YENIMODUL_V1 */'
assert s.count(MGR_OLD) == 1, "DEFAULTS manager anchor=%d" % s.count(MGR_OLD)
s = s.replace(MGR_OLD, '"rotam", "kapsam", "etki", "portfoy", "pipeline", "pazar", "ozet"],  /* SEKME_CAP_V1 */  /* YETKI_FAZ1 */  /* KAPSAM_TAD_V1 */  /* IZIN_YENIMODUL_V1 */', 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SEKME_CAP_V1 (tenant-admin.js) — Sekmeler grubu + relokasyon + ozet lock + DEFAULTS")
