# -*- coding: utf-8 -*-
# YETKI_FAZ3A (server) — Veri kapsamı zorlaması PİLOT: _sahaScopeSql yardımcısı + /api/saha/musteriler listesi.
#   OPT-IN: kapsam ayarlanmamış / level=tumu / admin → filtre YOK (bugünkü davranış, regresyon yok).
#   kendi→sorumlu_rep=ben · bolge→il=ANY(bölgelerim) [boşsa kendi'ye düşer] · bolum→bölüm-peer sorumlu_rep · tumu→yok.
#   Kaynak: permissions_json.scope (Bölümler "uygula" yazıyor). Bu PİLOT yalnız LİSTE ucu; tekil kart + diğer uçlar Faz 3b.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ3A" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# 1) _sahaScopeSql yardımcısı — _sahaCap'ten hemen sonra
CAP = '  function _sahaCap(sess, cap) { if (!sess) return false; if (sess.sahaRole === "admin") return true; const d = Array.isArray(sess.permissions && sess.permissions.departments) ? sess.permissions.departments : []; return (!d.length) ? true : d.includes(cap); }'
assert s.count(CAP) == 1, "sahaCap anchor=%d" % s.count(CAP)
HELP = CAP + '''
  /* YETKI_FAZ3A — veri kapsami WHERE parcasi (opt-in; permissions_json.scope). params dizisine positional push eder. */
  function _sahaScopeSql(sess, params, alias) {
    if (!sess || sess.sahaRole === "admin") return "";
    const sc = (sess.permissions && sess.permissions.scope) || {};
    const lvl = sc.level || "tumu";
    if (lvl === "tumu" || !lvl) return "";
    if (lvl === "kendi") { params.push(sess.userId); return " AND " + alias + ".sorumlu_rep = $" + params.length; }
    if (lvl === "bolge") {
      const regs = Array.isArray(sc.regions) ? sc.regions.filter(Boolean) : [];
      if (!regs.length) { params.push(sess.userId); return " AND " + alias + ".sorumlu_rep = $" + params.length; }
      params.push(regs); return " AND " + alias + ".il = ANY($" + params.length + "::text[])";
    }
    if (lvl === "bolum") {
      params.push(sess.tenantId); const ti = params.length;
      params.push(sess.userId);   const ui = params.length;
      return " AND " + alias + ".sorumlu_rep IN (SELECT dm2.user_id FROM tenant_department_membership dm1 JOIN tenant_department_membership dm2 ON dm2.tenant_id=dm1.tenant_id AND dm2.department_id=dm1.department_id WHERE dm1.tenant_id::text=$" + ti + "::text AND dm1.user_id=$" + ui + ")";
    }
    return "";
  }'''
s = s.replace(CAP, HELP, 1)

# 2) /api/saha/musteriler listesine enjekte (base WHERE'den sonra)
ANCH = "<> 'EXCEL_IMPORT_KONTROL'`; /* KONTROL_FIX_V1 */"
assert s.count(ANCH) == 1, "musteriler anchor=%d" % s.count(ANCH)
s = s.replace(ANCH, ANCH + '\n      sql += _sahaScopeSql(session, params, "m");  /* YETKI_FAZ3A — veri kapsami (liste) */', 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ3A (server) — _sahaScopeSql + /api/saha/musteriler kapsam (pilot)")
