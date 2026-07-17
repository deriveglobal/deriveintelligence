#!/usr/bin/env node
// stamp_versions.mjs — build-time cache-bust stamper.
// ⚠ NEDEN: shell dosyalari ?v= ile yuklenir. ?v='yi ELLE guncellemek UNUTULUR.
//   14 Tem 2026: saha.js 6 gun eski ?v= ile yuklendi -> tum saha degisiklikleri
//   tarayicida KARANLIKTA kaldi ("sunucu yesil, ekran eski").
//   Bu script her build'de dosyanin ICERIK HASH'ini ?v='e yazar. Elle adim YOK.
//   Dosya degisti mi hash degisir; degismedi mi ayni kalir. Unutmak IMKANSIZ.
//
// ⚠ Kapsam: index.html -> app.js -> /shells/*.js  ve  shell'ler birbirini
//   (saha.js -> tr_il_ilce.js) import edebilir. Leaf'ler once stabillessin diye
//   shell->shell adimi SABIT NOKTAYA kadar donuyor.
import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { createHash } from "node:crypto";

const root = process.argv[2] || "/app";
const h10 = (buf) => createHash("sha256").update(buf).digest("hex").slice(0, 10);
const esc = (s) => s.replace(/[.]/g, "\\.");
const shellDir = root + "/shells";
const shells = readdirSync(shellDir).filter(f => f.endsWith(".js") && !f.includes(".bak"));

// Bir metindeki /shells/*.js referanslarina GUNCEL hash'i yaz.
function stampShellRefs(text) {
  let changed = false;
  for (const f of shells) {
    const hv = h10(readFileSync(shellDir + "/" + f));
    // /shells/NAME.js  ya da  /shells/NAME.js?v=ESKI  -> /shells/NAME.js?v=<hv>
    // Sadece tirnak/parantez ONUNDE (gercek referans), .bak vb. yakalanmasin.
    const re = new RegExp("/shells/" + esc(f) + "(?:\\?v=[0-9a-zA-Z._-]+)?(?=[\"'`)])", "g");
    text = text.replace(re, () => { changed = true; return "/shells/" + f + "?v=" + hv; });
  }
  return { text, changed };
}

// PASS A — shell -> shell (sabit nokta)
for (let iter = 0; iter < 10; iter++) {
  let any = false;
  for (const f of shells) {
    const p = shellDir + "/" + f;
    const before = readFileSync(p, "utf8");
    const { text } = stampShellRefs(before);
    if (text !== before) { writeFileSync(p, text); any = true; }
  }
  if (!any) break;
}

// PASS B — app.js -> /shells/*.js
{
  const p = root + "/app.js";
  const before = readFileSync(p, "utf8");
  const { text } = stampShellRefs(before);
  if (text !== before) writeFileSync(p, text);
}
for (const f of shells) console.log(`[stamp] shells/${f} -> ${h10(readFileSync(shellDir + "/" + f))}`);

// PASS C — index.html -> app.js (app.js DEGISTIKTEN sonra)
{
  const appHash = h10(readFileSync(root + "/app.js"));
  const p = root + "/index.html";
  const before = readFileSync(p, "utf8");
  const after = before.replace(/\/app\.js(?:\?v=[0-9a-zA-Z._-]+)?(?=[\"'`)])/g, "/app.js?v=" + appHash);
  if (after !== before) writeFileSync(p, after);
  console.log(`[stamp] app.js -> ${appHash}`);
}
console.log("[stamp] OK — tum surumler ICERIK HASH'inden turetildi (elle adim yok).");
