# -*- coding: utf-8 -*-
# UX_YETKI_V1 (tenant-admin.js) — client-only cila (server/DB yok):
#  1a) Bolumler "Kaydet & uygula" acik uye panelini de otomatik kaydetsin (tek tik; "0 uyeye uygulandi" karisikligini bitirir).
#  1b) Kisiler'de "sablon/ozel" yerine "bolum/kisisel" rozeti (personal_grant'e gore — Faz4 modeliyle dogru).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "UX_YETKI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1a) apply handler: PATCH'ten ONCE acik uye panelini commit et
AP_ANCH = '''        try{
          await apiFetch(`/api/tenant/departments/${d.id}`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({ad,template_json:tj})});'''
assert s.count(AP_ANCH) == 1, "apply try anchor=%d" % s.count(AP_ANCH)
AP_NEW = '''        try{
          /* UX_YETKI_V1 — uye paneli aciksa bekleyen uyelik degisikligini de kaydet (tek tik) */
          const _mbox=document.getElementById("tb-memberbox");
          if(_mbox && _mbox.querySelector("input[data-uid]")){
            const _add=[..._mbox.querySelectorAll("input[data-uid]:checked")].map(c=>c.dataset.uid);
            const _rem=[..._mbox.querySelectorAll("input[data-uid]:not(:checked)")].map(c=>c.dataset.uid);
            await apiFetch(`/api/tenant/departments/${d.id}/members`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({add:_add,remove:_rem})});
            d.uye=_add.length;
          }
          await apiFetch(`/api/tenant/departments/${d.id}`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({ad,template_json:tj})});'''
s = s.replace(AP_ANCH, AP_NEW, 1)

# 1a-b) uye paneli etiketini netlestir
LBL_OLD = '<div class="tb-lbl">👥 Üyeler — işaretle, kaydet</div>'
assert s.count(LBL_OLD) == 1, "uye etiket anchor=%d" % s.count(LBL_OLD)
s = s.replace(LBL_OLD, '<div class="tb-lbl">👥 Üyeler — işaretle → aşağıda "Kaydet & uygula" da kaydeder</div>  <!-- UX_YETKI_V1 -->', 1)

# 1b) Kisiler rozeti: sablon/ozel -> bolum/kisisel (personal_grant)
TAG_OLD = '''const tag=(chk&&!guard)?(roleDef.has(t[0])?'<span class="tk-tag def">şablon</span>':'<span class="tk-tag ovr">özel</span>'):'';'''
assert s.count(TAG_OLD) == 1, "tag anchor=%d" % s.count(TAG_OLD)
TAG_NEW = '''const tag=(chk&&!guard)?((Array.isArray(perms.personal_grant)&&perms.personal_grant.includes(t[0]))?'<span class="tk-tag ovr">kişisel</span>':'<span class="tk-tag def">bölüm</span>'):'';  /* UX_YETKI_V1 */'''
s = s.replace(TAG_OLD, TAG_NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] UX_YETKI_V1 (tenant-admin.js) — Bolumler tek-tik uygula + Kisiler bolum/kisisel rozeti")
