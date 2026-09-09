import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";
import https from "node:https";
function post(urlStr, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const req = https.request({ hostname: u.hostname, path: u.pathname + u.search, method: "POST",
      headers: { ...headers, "Content-Length": Buffer.byteLength(body) } },
      res => { let d = ""; res.on("data", c => d += c); res.on("end", () => resolve({ status: res.statusCode, text: d })); });
    req.on("error", reject); req.write(body); req.end();
  });
}
const sa = JSON.parse(readFileSync("./fcm-sa.json", "utf8"));
const DEVICE = process.argv[2];
if (!DEVICE) { console.error("usage: node fcm-send.mjs <token>"); process.exit(1); }
const b64 = o => Buffer.from(JSON.stringify(o)).toString("base64url");
const now = Math.floor(Date.now() / 1000);
const unsigned = b64({ alg: "RS256", typ: "JWT" }) + "." + b64({ iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging", aud: sa.token_uri, iat: now, exp: now + 3600 });
const signer = createSign("RSA-SHA256"); signer.update(unsigned);
const jwt = unsigned + "." + signer.sign(sa.private_key).toString("base64url");
const auth = await post(sa.token_uri, { "Content-Type": "application/x-www-form-urlencoded" },
  new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }).toString());
const tk = JSON.parse(auth.text);
if (!tk.access_token) { console.error("AUTH ERROR", auth.status, auth.text); process.exit(1); }
const msg = { message: { token: DEVICE, notification: { title: "Derive Intelligence", body: "Bildirimler calisiyor — ilk test push 🎉" }, android: { priority: "high" } } };
const res = await post(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
  { "Authorization": "Bearer " + tk.access_token, "Content-Type": "application/json" }, JSON.stringify(msg));
console.log("FCM HTTP", res.status);
console.log(res.text);
