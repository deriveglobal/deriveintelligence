#!/usr/bin/env node
// APNS_SEND — iOS push via Apple APNs (zero-dependency: node:crypto ES256 JWT + node:http2).
// Android tarafi fcm-send.mjs ile ayni kalir; bu SADECE iOS (APNs token) icindir.
// Kullanim: node apns-send.mjs <device-token> <mesaj...>
// Anahtar: /opt/krb-assessment/apns-key.p8 (SECRET, gitignore) — Apple "Sandbox & Production" APNs key.
// Once production (api.push.apple.com) denenir; BadDeviceToken donerse sandbox (dev build token'i)
// otomatik denenir. Boylece hem Xcode dev build hem TestFlight/App Store calisir.
import fs from "node:fs";
import crypto from "node:crypto";
import http2 from "node:http2";

const KEY_PATH = process.env.APNS_KEY || "/opt/krb-assessment/apns-key.p8";
const KEY_ID = process.env.APNS_KEY_ID || "H2XRJM325L";
const TEAM_ID = process.env.APNS_TEAM_ID || "48SQSDC47D";
const TOPIC = process.env.APNS_TOPIC || "com.deriveglobal.intelligence";

function b64url(o) { return Buffer.from(JSON.stringify(o)).toString("base64url"); }

function makeJWT() {
  const signingInput = b64url({ alg: "ES256", kid: KEY_ID }) + "." + b64url({ iss: TEAM_ID, iat: Math.floor(Date.now() / 1000) });
  const key = crypto.createPrivateKey(fs.readFileSync(KEY_PATH));
  const sig = crypto.sign("sha256", Buffer.from(signingInput), { key, dsaEncoding: "ieee-p1363" }).toString("base64url");
  return signingInput + "." + sig;
}

function send(host, token, title, body) {
  return new Promise((resolve) => {
    let done = false;
    const fin = (v) => { if (!done) { done = true; resolve(v); } };
    let client;
    try { client = http2.connect(host); } catch (e) { return fin({ ok: false, host, err: String(e) }); }
    client.on("error", (e) => fin({ ok: false, host, err: String(e) }));
    const payload = JSON.stringify({ aps: { alert: { title, body }, sound: "default" } });
    const req = client.request({
      ":method": "POST",
      ":path": "/3/device/" + token,
      "authorization": "bearer " + makeJWT(),
      "apns-topic": TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    });
    let status = 0, data = "";
    req.on("response", (h) => { status = h[":status"]; });
    req.setEncoding("utf8");
    req.on("data", (d) => { data += d; });
    req.on("end", () => { try { client.close(); } catch (e) {} fin({ ok: status === 200, status, host, apnsId: undefined, data }); });
    req.on("error", (e) => { try { client.close(); } catch (er) {} fin({ ok: false, host, err: String(e) }); });
    req.end(payload);
  });
}

const HOSTS = { prod: "https://api.push.apple.com", sandbox: "https://api.sandbox.push.apple.com" };

async function main() {
  const token = process.argv[2];
  const message = process.argv.slice(3).join(" ") || "Derive test bildirimi";
  if (!token) { console.error("kullanim: node apns-send.mjs <device-token> <mesaj>"); process.exit(1); }
  let r = await send(HOSTS.prod, token, "Derive Intelligence", message);
  if (!r.ok && r.status === 400 && /BadDeviceToken/i.test(r.data || "")) {
    console.log("prod BadDeviceToken -> sandbox deneniyor…");
    r = await send(HOSTS.sandbox, token, "Derive Intelligence", message);
  }
  console.log(JSON.stringify(r));
  process.exit(r.ok ? 0 : 2);
}
main();
