// push_test.mjs — server'in GERCEK APNS/FCM imzalama mantigini birebir kullanarak
//   verilen token'lara bildirim gonderir. Container icinde calisir (creds /app'te).
//   Kullanim: node /tmp/push_test.mjs /tmp/_toks.json "Baslik" "Govde"
import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";

const TOKS  = JSON.parse(readFileSync(process.argv[2], "utf8")) || [];
const TITLE = process.argv[3] || "💬 Yeni mesaj";
const BODY  = process.argv[4] || "Uğur Yıldız: Test bildirimi";
const DATA  = { room: "saha", type: "mesaj" };

const _APNS = {
  keyId:  process.env.APNS_KEY_ID || "H2XRJM325L",
  teamId: process.env.APNS_TEAM_ID || "48SQSDC47D",
  topic:  process.env.APNS_TOPIC || "com.deriveglobal.intelligence",
  keyPath: process.env.APNS_KEY || "/app/apns-key.p8",
};
const _FCM_SA_PATH = process.env.FCM_SA || "/app/fcm-sa.json";

function _strData(data) { const o = {}; const s = data || {}; for (const k in s) o[k] = String(s[k]); return o; }

function _httpsPost(urlStr, headers, body) {
  return new Promise((resolve, reject) => {
    import("node:https").then(({ default: https }) => {
      const u = new URL(urlStr);
      const req = https.request({ hostname: u.hostname, path: u.pathname + u.search, method: "POST", headers, port: 443 },
        res => { let d = ""; res.setEncoding("utf8"); res.on("data", x => d += x); res.on("end", () => resolve({ status: res.statusCode, text: d })); });
      req.on("error", reject); req.end(body);
    });
  });
}

let _fcmTok = null, _fcmExp = 0, _fcmProj = null;
async function _fcmAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  if (_fcmTok && now < _fcmExp - 60) return _fcmTok;
  const sa = JSON.parse(readFileSync(_FCM_SA_PATH, "utf8"));
  _fcmProj = sa.project_id;
  const b64 = o => Buffer.from(JSON.stringify(o)).toString("base64url");
  const unsigned = b64({ alg: "RS256", typ: "JWT" }) + "." + b64({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: sa.token_uri, iat: now, exp: now + 3600 });
  const jwt = unsigned + "." + createSign("RSA-SHA256").update(unsigned).sign(sa.private_key).toString("base64url");
  const r = await _httpsPost(sa.token_uri, { "Content-Type": "application/x-www-form-urlencoded" }, new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }).toString());
  const j = JSON.parse(r.text);
  if (!j.access_token) throw new Error("fcm-auth " + r.status + " " + r.text);
  _fcmTok = j.access_token; _fcmExp = now + (j.expires_in || 3600);
  return _fcmTok;
}
async function _sendFCM(token) {
  const at = await _fcmAccessToken();
  const msg = { message: { token, notification: { title: TITLE, body: BODY }, android: { priority: "high" }, data: _strData(DATA) } };
  const r = await _httpsPost("https://fcm.googleapis.com/v1/projects/" + _fcmProj + "/messages:send", { Authorization: "Bearer " + at, "Content-Type": "application/json" }, JSON.stringify(msg));
  return { ok: r.status === 200, status: r.status, text: r.text };
}

let _apnsJwt = null, _apnsJwtAt = 0;
async function _apnsAuth() {
  const now = Math.floor(Date.now() / 1000);
  if (_apnsJwt && now - _apnsJwtAt < 2400) return _apnsJwt;
  const crypto = await import("node:crypto");
  const b64 = o => Buffer.from(JSON.stringify(o)).toString("base64url");
  const si = b64({ alg: "ES256", kid: _APNS.keyId }) + "." + b64({ iss: _APNS.teamId, iat: now });
  const key = crypto.createPrivateKey(readFileSync(_APNS.keyPath));
  _apnsJwt = si + "." + crypto.sign("sha256", Buffer.from(si), { key, dsaEncoding: "ieee-p1363" }).toString("base64url");
  _apnsJwtAt = now;
  return _apnsJwt;
}
async function _apnsPost(host, token, payloadStr, jwt) {
  const http2 = (await import("node:http2")).default;
  return new Promise((resolve) => {
    let done = false; const fin = (v) => { if (!done) { done = true; resolve(v); } };
    let c; try { c = http2.connect(host); } catch (e) { return fin({ status: 0, text: String(e) }); }
    c.on("error", (e) => fin({ status: 0, text: String(e) }));
    const req = c.request({ ":method": "POST", ":path": "/3/device/" + token, authorization: "bearer " + jwt, "apns-topic": _APNS.topic, "apns-push-type": "alert", "apns-priority": "10", "content-type": "application/json" });
    let st = 0, d = ""; req.on("response", (h) => (st = h[":status"])); req.setEncoding("utf8"); req.on("data", (x) => (d += x));
    req.on("end", () => { try { c.close(); } catch (e) {} fin({ status: st, text: d }); });
    req.on("error", (e) => { try { c.close(); } catch (er) {} fin({ status: 0, text: String(e) }); });
    req.end(payloadStr);
  });
}
async function _sendAPNS(token) {
  const jwt = await _apnsAuth();
  const payload = JSON.stringify({ aps: { alert: { title: TITLE, body: BODY }, sound: "default" }, ..._strData(DATA) });
  let r = await _apnsPost("https://api.push.apple.com", token, payload, jwt);
  if (r.status === 400 && /BadDeviceToken/i.test(r.text || "")) r = await _apnsPost("https://api.sandbox.push.apple.com", token, payload, jwt);
  return { ok: r.status === 200, status: r.status, text: r.text };
}

(async () => {
  console.log("Toplam token: " + TOKS.length);
  let ok = 0, fail = 0;
  for (const row of TOKS) {
    try {
      const res = row.platform === "ios" ? await _sendAPNS(row.token) : await _sendFCM(row.token);
      console.log((res.ok ? "OK  " : "FAIL") + " " + row.platform + " " + String(row.token).slice(0, 14) + "… status=" + res.status + (res.ok ? "" : " :: " + String(res.text).slice(0, 140)));
      if (res.ok) ok++; else fail++;
    } catch (e) { fail++; console.log("ERR " + row.platform + " " + String(e.message).slice(0, 140)); }
  }
  console.log("--- OZET: ok=" + ok + " fail=" + fail + " / " + TOKS.length);
})();
