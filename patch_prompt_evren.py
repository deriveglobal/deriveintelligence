#!/usr/bin/env python3
# ============================================================
# Derive · AGNOSTİK FAZ C — AI prompt is-tanimi: "lastik toptancısı" -> evren_tanim
#   + 30447 hardcoded "(KRB)" KIMLIK SIZINTISI kaldirilir.
# 552/686: mevcut _tnAgn LOOKUP'una _tnEvren eklenir. 25152/27798: _evTanim(T) helper.
# Idempotent (marker). Her replace count-guard'li (uyusmazsa HICBIR SEY yazilmaz).
# ============================================================
import sys, shutil
PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/server_container.mjs'
MARK = 'PROMPT_EVREN_V1'
s = open(PATH, encoding='utf-8').read()
if MARK in s:
    print('[=] zaten uygulanmis (idempotent).'); sys.exit(0)

# (old, new, beklenen_adet)
R = []

# 1) LOOKUP (2x) -> _tnEvren ekle
R.append((
 '  let _tnAgn=null; try { const _rAgn=(await q("SELECT name FROM platform_tenants WHERE id=$1",[T])).rows[0]; if(_rAgn&&_rAgn.name) _tnAgn=String(_rAgn.name); } catch(_e){} /* TENANT_KIMLIK_AGNOSTIK_V1 */',
 '  let _tnAgn=null,_tnEvren=null; try { const _rAgn=(await q("SELECT name, evren_tanim(id) AS tanim FROM platform_tenants WHERE id=$1",[T])).rows[0]; if(_rAgn){ if(_rAgn.name) _tnAgn=String(_rAgn.name); if(_rAgn.tanim) _tnEvren=String(_rAgn.tanim); } } catch(_e){} /* TENANT_KIMLIK_AGNOSTIK_V1 ' + MARK + ' */',
 2))

# 2) modul helper _evTanim — _bolumIcgoruUret'ten once ekle
R.append((
 'async function _bolumIcgoruUret(T, q){',
 'async function _evTanim(t){ /* ' + MARK + ' */ try{ const _r=(await query("SELECT evren_tanim($1::uuid) t",[t])).rows[0]; return (_r&&_r.t)?String(_r.t):"lastik toptancısı"; }catch(_e){ return "lastik toptancısı"; } }\nasync function _bolumIcgoruUret(T, q){',
 1))

# 3) 552 descriptor
R.append((
 ' adlı lastik toptancısının analistisin.',
 ' adlı " + (_tnEvren||"lastik toptancısı") + "nın analistisin.',
 1))

# 4) 686 descriptor
R.append((
 ' lastik toptancisinin rakip-izleme analistisin.',
 ' " + (_tnEvren||"lastik toptancisi") + "nin rakip-izleme analistisin.',
 1))

# 5) 25152 template — _ev25 lookup + interpolate
R.append((
 'const SYS = `Sen bu lastik toptancısı firmanın finans analistisin.',
 'const _ev25 = await _evTanim(T); const SYS = `Sen bu ${_ev25} firmanın finans analistisin.',
 1))

# 6) 27798 concat — _ev27 lookup + descriptor
R.append((
 'const SYS = "Sen " + ((session&&session.tenantName)||"KRB") + " adli lastik toptancisinin finans analistisin.',
 'const _ev27 = await _evTanim(T); const SYS = "Sen " + ((session&&session.tenantName)||"KRB") + " adli " + _ev27 + "nin finans analistisin.',
 1))

# 7) 30447 KIMLIK SIZINTISI: " (KRB)" kaldir
R.append((
 'Sen bir lastik toptancisinin (KRB) saha zekasi asistanisin.',
 'Sen bir lastik toptancisinin saha zekasi asistanisin.',
 1))

# once hepsini dogrula
for i,(old,new,cnt) in enumerate(R,1):
    c = s.count(old)
    if c != cnt:
        print(f'[!] R{i} anchor {c} bulundu (beklenen {cnt}). IPTAL — dosya DEGISMEDI.')
        print(f'    bas: {old[:70]!r}')
        sys.exit(1)

bak = PATH + '.bak_promptevren'; shutil.copy2(PATH, bak)
for i,(old,new,cnt) in enumerate(R,1):
    s = s.replace(old, new)
    print(f'[+] R{i} uygulandi ({cnt} yer).')
open(PATH,'w',encoding='utf-8').write(s)
print(f'[OK] {MARK}. Yedek: {bak}. node --check calistir.')
