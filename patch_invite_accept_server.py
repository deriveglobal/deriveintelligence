# -*- coding: utf-8 -*-
# INVITE_ACCEPT_V1 — davet kabul akisi:
#   GET  /invite/:token       -> kabul sayfasi (HTML; yeni kullanici sifre belirler)
#   POST /api/invite/accept   -> hesap olustur/bagla + tenant uyeligi + modul erisimi + oturum
#   Yeni kullanici: sifre alir + otomatik giris (createSession). Mevcut kullanici: uyelik eklenir,
#   token'dan oturum URETILMEZ (guvenlik) -> normal giris yapar. Davet 'accepted' isaretlenir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "INVITE_ACCEPT_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCHOR = r'''      inviteUrl: `${getRequestOrigin(request)}/invite/${token}`,
      expiresIn: "7 days"
    });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}'''

NEW = ANCHOR + r'''

// GET /invite/:token — davet kabul sayfasi  /* INVITE_ACCEPT_V1 */
if (request.method === "GET" && /^\/invite\/[^/]+$/.test(url.pathname)) {
  try {
    const _tok = decodeURIComponent(url.pathname.split("/")[2] || "");
    const _r = await query(
      `SELECT ui.invited_email, ui.module_id, pt.name AS tenant_name
         FROM user_invitations ui JOIN platform_tenants pt ON pt.id = ui.tenant_id
        WHERE ui.token_hash = $1 AND ui.status = 'pending' AND ui.expires_at > now()`, [hashToken(_tok)]);
    const _esc = (x) => String(x == null ? "" : x).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
    let _body;
    if (!_r.rowCount) {
      _body = `<div class="c"><div class="ic">⏳</div><h1>Davet geçersiz</h1><p>Bu davet bağlantısı geçersiz veya süresi dolmuş. Yöneticinizden yeni bir davet isteyin.</p></div>`;
    } else {
      const _iv = _r.rows[0];
      const _ex = await query("SELECT 1 FROM users WHERE lower(email) = lower($1) LIMIT 1", [_iv.invited_email]);
      const _has = _ex.rowCount > 0;
      _body = `<div class="c">
        <div class="logo"><svg width="34" height="34" viewBox="0 0 32 32" fill="none"><rect width="32" height="32" rx="8" fill="#e2b04a"/><path d="M8 16h4l3-8 4 16 3-8h4" stroke="#15151f" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
        <h1>${_esc(_iv.tenant_name)}</h1>
        <p class="sub">Ekibe davet edildiniz · <b>${_esc(_iv.invited_email)}</b></p>
        <form id="f">
          ${_has
            ? `<p class="note">Bu e-posta ile zaten bir hesabınız var. Kabul edince ekibe eklenirsiniz; sonra normal şifrenizle giriş yaparsınız.</p>`
            : `<label>Ad Soyad</label><input id="name" placeholder="Adınız" autocomplete="name">
               <label>Şifre belirleyin</label><input id="pw" type="password" placeholder="En az 8 karakter" autocomplete="new-password">`}
          <button type="submit" id="btn">${_has ? "Ekibe katıl" : "Hesabı oluştur ve katıl"}</button>
          <div id="msg" class="msg"></div>
        </form>
      </div>
      <script>
        var TOK = ${JSON.stringify(_tok)}, HAS = ${_has ? "true" : "false"};
        document.getElementById("f").addEventListener("submit", async function (e) {
          e.preventDefault();
          var btn = document.getElementById("btn"), msg = document.getElementById("msg");
          var body = { token: TOK };
          if (!HAS) {
            body.name = (document.getElementById("name").value || "").trim();
            body.password = document.getElementById("pw").value || "";
            if (body.password.length < 8) { msg.style.color = "#dc2626"; msg.textContent = "Şifre en az 8 karakter olmalı."; return; }
          }
          btn.disabled = true; btn.textContent = "…"; msg.textContent = "";
          try {
            var r = await fetch("/api/invite/accept", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
            var d = await r.json(); if (!r.ok) throw new Error(d.error || "Hata");
            if (d.sessionToken) {
              try { localStorage.setItem("platformSessionToken", d.sessionToken); } catch (_) {}
              msg.style.color = "#16a34a"; msg.textContent = "Tamamlandı, yönlendiriliyorsunuz…"; setTimeout(function () { location.href = "/"; }, 700);
            } else {
              msg.style.color = "#16a34a"; msg.innerHTML = "Ekibe eklendiniz. <a href='/'>Giriş yapın →</a>"; btn.style.display = "none";
            }
          } catch (err) { btn.disabled = false; btn.textContent = HAS ? "Ekibe katıl" : "Hesabı oluştur ve katıl"; msg.style.color = "#dc2626"; msg.textContent = err.message; }
        });
      </script>`;
    }
    const _html = `<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Davet</title>
      <style>*{box-sizing:border-box}body{margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#15151f;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px}
      .c{background:#fff;border-radius:18px;padding:36px 32px;max-width:400px;width:100%;box-shadow:0 30px 70px rgba(0,0,0,.45);text-align:center}
      .logo{margin-bottom:12px}.ic{font-size:40px;margin-bottom:8px}
      h1{margin:6px 0 4px;font-size:22px;color:#12182a;letter-spacing:-.02em}.sub{color:#6b7280;font-size:14px;margin:0 0 22px}
      .note{background:#f4f5f7;border-radius:10px;padding:12px;font-size:13px;color:#4b5462;text-align:left;margin:0 0 16px;line-height:1.5}
      label{display:block;text-align:left;font-size:12.5px;font-weight:650;color:#4b5462;margin:14px 0 6px}
      input{width:100%;padding:11px 13px;border:1px solid #d7dbe3;border-radius:10px;font-size:15px;outline:none}
      input:focus{border-color:#12182a;box-shadow:0 0 0 3px rgba(18,24,42,.08)}
      button{width:100%;margin-top:20px;padding:13px;border:0;border-radius:10px;background:#12182a;color:#fff;font-size:15px;font-weight:650;cursor:pointer}
      button:hover{background:#26263a}.msg{margin-top:14px;font-size:13px;min-height:18px}
      p{color:#4b5462;line-height:1.5}a{color:#2563eb;font-weight:600;text-decoration:none}</style></head>
      <body>${_body}</body></html>`;
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(_html);
  } catch (e) {
    response.writeHead(500, { "Content-Type": "text/html; charset=utf-8" });
    response.end("<!DOCTYPE html><meta charset=utf-8><h1>Hata</h1>");
  }
  return;
}

// POST /api/invite/accept — daveti kabul et  /* INVITE_ACCEPT_V1 */
if (request.method === "POST" && url.pathname === "/api/invite/accept") {
  try {
    const { token, password, name } = await readJson(request);
    if (!token) throw Object.assign(new Error("Geçersiz davet."), { statusCode: 400 });
    const inv = await query(`SELECT * FROM user_invitations WHERE token_hash = $1 AND status = 'pending' AND expires_at > now()`, [hashToken(token)]);
    if (!inv.rowCount) throw Object.assign(new Error("Davet geçersiz veya süresi dolmuş."), { statusCode: 404 });
    const iv = inv.rows[0];
    const email = String(iv.invited_email).toLowerCase().trim();
    const existing = await query("SELECT id FROM users WHERE lower(email) = lower($1) LIMIT 1", [email]);
    let userId, isNew = false;
    if (existing.rowCount) { userId = existing.rows[0].id; }
    else {
      if (!password || String(password).length < 8) throw Object.assign(new Error("Şifre en az 8 karakter olmalı."), { statusCode: 400 });
      const u = await query(
        `INSERT INTO users (email, full_name, name, role, auth_provider, password_hash, status)
         VALUES ($1, $2, $2, 'bi_user', 'local', $3, 'active') RETURNING id`,
        [email, (name && String(name).trim()) || email, hashPassword(String(password))]);
      userId = u.rows[0].id; isNew = true;
    }
    await query(`INSERT INTO tenant_users (tenant_id, user_id, tenant_role, invited_by) VALUES ($1, $2, 'member', $3)
                 ON CONFLICT (tenant_id, user_id) DO UPDATE SET active = true`, [iv.tenant_id, userId, iv.invited_by]);
    if (iv.module_id) {
      await query(`INSERT INTO tenant_user_modules (tenant_id, user_id, module_id, module_role, permissions_json, active, granted_by)
                   VALUES ($1, $2, $3, $4, $5, true, $6)
                   ON CONFLICT (tenant_id, user_id, module_id) DO UPDATE SET module_role = $4, permissions_json = $5, active = true, updated_at = now()`,
        [iv.tenant_id, userId, iv.module_id, iv.module_role || "viewer", iv.permissions_json || {}, iv.invited_by]);
    }
    await query("UPDATE user_invitations SET status = 'accepted', accepted_by_user_id = $1 WHERE id = $2", [userId, iv.id]);
    let sessionToken = null;
    if (isNew) { sessionToken = await createSession(userId, { userAgent: "invite-accept" }); await query("UPDATE users SET last_login_at = now() WHERE id = $1", [userId]); }
    sendJson(response, 200, { ok: true, sessionToken, alreadyHadAccount: !isNew }, sessionToken ? { "Set-Cookie": sessionCookie(sessionToken) } : {});
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}'''

assert s.count(ANCHOR) == 1, "anchor bulunamadi (%d)" % s.count(ANCHOR)
s = s.replace(ANCHOR, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] INVITE_ACCEPT_V1")
