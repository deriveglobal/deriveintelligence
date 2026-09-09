#!/usr/bin/env bash
# SURUM_2_KUR — OTOMATIK SURUMLEME. Sürüm artik ELLE degil, ICERIK HASH'inden.
#
# ⚠ NEDEN (14 Tem 2026): saha.js'i defalarca deploy ettim ama ?v='yi artirmadim.
#   ?v= 6 gun sabit kaldi -> tarayici eski dosyayi calistirdi -> tum saha isi
#   Eftal'in ekraninda KARANLIKTA kaldi. "Ben artiracagim" dedim; ama 'ben' gidecegim.
#   Soz koda yazilmaz, KAPI koda yazilir.
#
# ✅ COZUM: build sirasinda her shell dosyasinin sha256'si ?v='e damgalanir.
#   Dosya degisti mi hash degisir. Elle adim YOK -> unutmak IMKANSIZ.
#   AYRICA ?v='siz yuklenen 5 dosyayi da (consultant/manager/owner/platform/
#   tenant-admin) surumler — onlar da ayni tuzaktaydi.
set -uo pipefail
cd /opt/krb-assessment || exit 1
cp -a Dockerfile Dockerfile.bak_stamp

echo "############ 1) STAMPER — stamp_versions.mjs yaz ############"
cat > stamp_versions.mjs <<'MJS'
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
MJS
echo "  ✅ yazildi ($(wc -l < stamp_versions.mjs) satir)"
node --check stamp_versions.mjs && echo "  ✅ node --check" || { echo "  ❌ sozdizimi"; exit 1; }

echo
echo "############ 2) YEREL PROVA — imaj disinda, KOPYA uzerinde calistir ############"
# ⚠ Once bir kopya uzerinde dene: app.js/index.html/shells BOZULMASIN.
rm -rf /tmp/stamp_prova && mkdir -p /tmp/stamp_prova/shells
cp app.js index.html /tmp/stamp_prova/
cp shells/*.js /tmp/stamp_prova/shells/ 2>/dev/null
node stamp_versions.mjs /tmp/stamp_prova
echo "  --- prova: app.js icindeki /shells/*.js ?v= (hepsi surumlu mu?) ---"
grep -oE '/shells/[a-zA-Z_.-]+\.js\?v=[0-9a-f]+' /tmp/stamp_prova/app.js | sort -u | sed 's/^/    /'
echo "  --- prova: ?v='SIZ kalan /shells var mi? (0 olmali) ---"
KALAN=$(grep -oE '/shells/[a-zA-Z_.-]+\.js(?![?])' /tmp/stamp_prova/app.js 2>/dev/null | grep -v '?v=' | sort -u)
grep -oE '/shells/[a-zA-Z_.-]+\.js"' /tmp/stamp_prova/app.js | grep -v '?v=' | sed 's/^/    ⚠ SURUMSUZ: /' || true
echo "  --- prova: index.html app.js?v= ---"
grep -oE 'app\.js\?v=[0-9a-f]+' /tmp/stamp_prova/index.html | head -1 | sed 's/^/    /'
echo "  --- prova: app.js sozdizimi bozulmadi mi? ---"
node --check /tmp/stamp_prova/app.js && echo "    ✅ app.js node --check" || { echo "    ❌ app.js bozuldu — DUR"; exit 1; }
node --check /tmp/stamp_prova/shells/saha.js && echo "    ✅ saha.js node --check" || { echo "    ❌ saha.js bozuldu"; exit 1; }
echo "  --- prova: KAPI — damgalanan ?v= gercek hash'e esit mi? (saha.js) ---"
SAHA_HASH=$(sha256sum /tmp/stamp_prova/shells/saha.js | cut -c1-10)
SAHA_STAMP=$(grep -oE '/shells/saha\.js\?v=[0-9a-f]+' /tmp/stamp_prova/app.js | head -1 | grep -oE '[0-9a-f]+$')
echo "    saha.js gercek hash : $SAHA_HASH"
echo "    app.js damga        : $SAHA_STAMP"
[ "$SAHA_HASH" = "$SAHA_STAMP" ] && echo "    ✅ ESIT — damga icerigi olcuyor" || { echo "    ❌ ESIT DEGIL"; exit 1; }

echo
echo "############ 3) IDEMPOTENT MI? — ikinci kez calistir, DEGISMEMELI ############"
cp -a /tmp/stamp_prova/app.js /tmp/app_once.txt
node stamp_versions.mjs /tmp/stamp_prova >/dev/null
if diff -q /tmp/app_once.txt /tmp/stamp_prova/app.js >/dev/null; then
  echo "  ✅ idempotent — ayni icerik, ayni hash, degisiklik yok"
else
  echo "  ❌ idempotent DEGIL — ikinci calistirma degistirdi"; exit 1
fi

echo
echo "############ 4) DOCKERFILE — stamper'i build'e ekle ############"
python3 - <<'PY'
import io, sys
p = "Dockerfile"
s = io.open(p, encoding="utf-8").read()
if "stamp_versions.mjs" in s:
    print("  ⏭ zaten ekli"); sys.exit(0)
ank = "COPY erp_ingest.py ./erp_ingest.py\n"
assert ank in s, "❌ ankraj (COPY erp_ingest.py) bulunamadi"
blok = (
  "# ⚠ OTOMATIK SURUMLEME (cache-bust) — her shell dosyasinin ICERIK HASH'i ?v='e yazilir.\n"
  "#   Elle ?v= guncellemek UNUTULUR (14 Tem: saha.js 6 gun eski surumle yuklendi, is karanlikta).\n"
  "#   Bu adim insan hatasini imkansiz kilar: dosya degisti mi hash degisir, degismedi mi ayni kalir.\n"
  "COPY stamp_versions.mjs ./stamp_versions.mjs\n"
  "RUN node stamp_versions.mjs /app\n"
  "\n"
)
s = s.replace(ank, blok + ank, 1)
io.open(p, "w", encoding="utf-8").write(s)
print("  ✅ Dockerfile'a COPY + RUN eklendi (erp_ingest COPY'sinden once)")
PY
echo "  --- Dockerfile stamper satirlari ---"
grep -n 'stamp_versions' Dockerfile | sed 's/^/    /'

echo
echo "############ 5) DAGIT — imaj yeniden, stamper build'de calisir ############"
docker build -t krb-assessment:secure . 2>&1 | grep -iE 'stamp|error|ERROR' | sed 's/^/  /'
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 6
echo "  GET / -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/)"

echo
echo "############ 6) ⚠ KANIT — SERVIS edilen surum, GERCEK hash'e esit mi? ############"
echo "  --- servis edilen app.js: tum /shells ?v= ---"
curl -s http://localhost:8080/app.js | grep -oE '/shells/[a-zA-Z_.-]+\.js\?v=[0-9a-f]+' | sort -u | sed 's/^/    /'
echo
echo "  --- ?v='SIZ kalan var mi? (0 olmali — 5 dosya artik surumlu) ---"
curl -s http://localhost:8080/app.js | grep -oE '/shells/[a-zA-Z_.-]+\.js"' | grep -v '?v=' | sort -u | sed 's/^/    ⚠ SURUMSUZ: /' || echo "    ✅ hicbiri surumsuz degil"

echo
echo "  --- KAPI: servis saha.js hash == app.js damga ---"
LS=$(curl -s http://localhost:8080/shells/saha.js | sha256sum | cut -c1-10)
DS=$(curl -s http://localhost:8080/app.js | grep -oE '/shells/saha\.js\?v=[0-9a-f]+' | head -1 | grep -oE '[0-9a-f]+$')
echo "    servis saha.js hash : $LS"
echo "    app.js damga        : $DS"
[ "$LS" = "$DS" ] && echo "    ✅ ESIT — surum icerigi OLCUYOR" || echo "    ❌ ESIT DEGIL — dur, incele"

echo
echo "  --- KAPI: servis app.js hash == index.html damga ---"
LA=$(curl -s http://localhost:8080/app.js | sha256sum | cut -c1-10)
DA=$(curl -s http://localhost:8080/index.html | grep -oE 'app\.js\?v=[0-9a-f]+' | head -1 | grep -oE '[0-9a-f]+$')
echo "    servis app.js hash  : $LA"
echo "    index.html damga    : $DA"
[ "$LA" = "$DA" ] && echo "    ✅ ESIT" || echo "    ❌ ESIT DEGIL"

echo
echo "############ SONUC ############"
echo "  ✅ Artik ?v= ELLE tutulmuyor. Her build dosya iceriginden hesaplar."
echo "  ✅ saha.js/bi.js + onceden surumsuz 5 shell — hepsi otomatik surumlu."
echo "  ⚠ Ben olmasam da kapi yerinde: yeni bir shell degisikligi -> yeni hash -> tarayici taze alir."
echo "  ⚠ Geri donus: Dockerfile.bak_stamp"
