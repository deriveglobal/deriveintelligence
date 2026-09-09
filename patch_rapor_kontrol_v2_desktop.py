# -*- coding: utf-8 -*-
# RAPOR_KONTROL_DK_V2 (masaüstü) — CANLI dosyaya karşı hedefli yükseltme (RAPOR_KONTROL_DK_V1 zaten uygulanmış):
#   - Segment seçici (#dk-seg) YALNIZ manager/admin'e görünsün (rep + viewer = Saha kullanıcısı → gizli).
#   - Rotam sekme etiketi: rep DIŞI herkes (viewer dahil) "🌅 Bugün Sahada".
#   Anchors CANLI saha_desktop.js'ten alındı.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_KONTROL_DK_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "RAPOR_KONTROL_DK_V1" in s, "HATA: once RAPOR_KONTROL_DK_V1 olmali"

# 1) etiket: isMgr -> S.role !== "rep" (viewer da pano görsün)
o1 = '    ["rotam", isMgr ? "🌅 Bugün Sahada" : "🌅 Rotam"],  /* SABAH_ROTAM_DK_V1 DK_V3 RAPOR_KONTROL_DK_V1 */'
n1 = '    ["rotam", (S.role !== "rep") ? "🌅 Bugün Sahada" : "🌅 Rotam"],  /* SABAH_ROTAM_DK_V1 DK_V3 RAPOR_KONTROL_DK_V1 RAPOR_KONTROL_DK_V2 */'
assert s.count(o1) == 1, "label anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) go(): segment seçici yalnız yönetici/admin
o2 = '{ const _sg = S.container.querySelector("#dk-seg"); if (_sg) _sg.style.display = ""; }  /* RAPOR_KONTROL_DK_V1 */'
n2 = '{ const _sg = S.container.querySelector("#dk-seg"); if (_sg) _sg.style.display = ["manager","admin"].includes(S.role) ? "" : "none"; }  /* RAPOR_KONTROL_DK_V2 */'
assert s.count(o2) == 1, "go anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) rpKontrol: segment seçici yalnız yönetici/admin (ve Rotam'da hiç)
o3 = 'const seg = S.container.querySelector("#dk-seg"); if (seg) seg.style.display = (aktif === "rotam") ? "none" : ""; };  /* RAPOR_KONTROL_DK_V1 */'
n3 = 'const seg = S.container.querySelector("#dk-seg"); if (seg) seg.style.display = (["manager","admin"].includes(S.role) && aktif !== "rotam") ? "" : "none"; };  /* RAPOR_KONTROL_DK_V2 */'
assert s.count(o3) == 1, "rpKontrol anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) wire(): açılışta Saha kullanıcısında segment seçiciyi gizle
o4 = '  renderNav();\n}'
n4 = '  if (!["manager","admin"].includes(S.role)) { const _sg0 = S.container.querySelector("#dk-seg"); if (_sg0) _sg0.style.display = "none"; }  /* RAPOR_KONTROL_DK_V2 */\n  renderNav();\n}'
assert s.count(o4) == 1, "wire anchor=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_KONTROL_DK_V2 (masaüstü)")
