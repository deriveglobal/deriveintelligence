#!/usr/bin/env bash
# NABIZ — organizmanın günlük kalp atışı. Compute HER GÜN; e-posta YALNIZCA değişiklikte (news-only).
# ÇOK-TENANT (NABIZ_MULTITENANT_V1): verisi olan HER tenant için ayrı çalışır.
#   - kimlik/is-tanimi: platform_tenants.config_json (kisa_ad, is_tanimi/evren_tanim)
#   - alıcılar: config_json->>'nabiz_alici' (yoksa: compute + kaydet, e-posta YOK)
#   - NABIZ_DRY=1: gerçek e-posta GÖNDERME (loop testi için güvenli)
#   - arg verilirse ($1=tenant_id): yalnız o tenant (geriye-uyum)
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
PSQLQ="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

# ── tenant listesi: arg varsa o; yoksa VERİSİ OLAN tüm tenantlar ──
if [ -n "${1:-}" ]; then
  TENANTS="$1"
else
  TENANTS=$($PSQLQ "SELECT DISTINCT tenant_id::text FROM bi_marj_atom ORDER BY 1")
fi

# ── ortak tablolar (bir kez) ──
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_nabiz (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY, tenant_id uuid, tarih date DEFAULT CURRENT_DATE,
  ozet text, detay jsonb, created_at timestamptz DEFAULT now(), UNIQUE(tenant_id, tarih));
CREATE TABLE IF NOT EXISTS bi_nabiz_durum (
  tenant_id uuid PRIMARY KEY, son_ogeler jsonb, son_gonderim date);
SQL

for T in $TENANTS; do
  NAME=$($PSQLQ "SELECT COALESCE(NULLIF(config_json->>'kisa_ad',''), name) FROM platform_tenants WHERE id='$T'")
  TANIM=$($PSQLQ "SELECT evren_tanim('$T'::uuid)")
  ALICI=$($PSQLQ "SELECT COALESCE(config_json->>'nabiz_alici','') FROM platform_tenants WHERE id='$T'")
  [ -z "$NAME" ] && NAME="firma"
  hr "TENANT $NAME ($T) — alici='${ALICI:-YOK}' dry='${NABIZ_DRY:-0}'"

  $PSQL -v ON_ERROR_STOP=1 -v t="$T" <<'SQL' || { echo "  ⚠ motor hatasi, tenant atlandi"; continue; }
SELECT icgoru_uret_finans(:'t'::uuid)  AS marka_icgoru;
SELECT icgoru_uret_musteri(:'t'::uuid) AS musteri_icgoru;
SELECT avci_sor(:'t'::uuid)            AS hunter_soru;
SQL
  echo "  ✅ motorlar + hunter çalıştı"

  docker exec -i -w /app -e T="$T" -e NAME="$NAME" -e TANIM="$TANIM" -e ALICI="$ALICI" -e NABIZ_DRY="${NABIZ_DRY:-}" \
    krb-assessment node --input-type=module <<'NODE' 2>&1 | sed 's/^/  /'
import pg from 'pg';
import Anthropic from '@anthropic-ai/sdk';
const T=process.env.T, NAME=process.env.NAME||'firma', TANIM=process.env.TANIM||'lastik toptancısı';
const ALICI=(process.env.ALICI||'').trim(), DRY=!!process.env.NABIZ_DRY;
const c=new pg.Client({connectionString:process.env.DATABASE_URL}); await c.connect();
const an=new Anthropic({apiKey:process.env.ANTHROPIC_API_KEY});
async function graphToken(){
  const r=await fetch(`https://login.microsoftonline.com/${process.env.MICROSOFT_TENANT_ID}/oauth2/v2.0/token`,{
    method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
    body:new URLSearchParams({client_id:process.env.MICROSOFT_CLIENT_ID,client_secret:process.env.MICROSOFT_CLIENT_SECRET,scope:'https://graph.microsoft.com/.default',grant_type:'client_credentials'})});
  return (await r.json()).access_token;
}
async function sendMail(to,subject,html){
  const tok=await graphToken(); const sender=process.env.MICROSOFT_SENDER||'consult@deriveglobal.com';
  const recips=String(to).split(',').map(s=>s.trim()).filter(Boolean).map(a=>({emailAddress:{address:a}}));
  const r=await fetch(`https://graph.microsoft.com/v1.0/users/${encodeURIComponent(sender)}/sendMail`,{
    method:'POST',headers:{Authorization:`Bearer ${tok}`,'Content-Type':'application/json'},
    body:JSON.stringify({message:{subject,body:{contentType:'HTML',content:html},toRecipients:recips},saveToSentItems:true})});
  if(!r.ok) throw new Error('graph '+r.status+' '+(await r.text()).slice(0,200));
}
const SAYIKURAL=`Sayıları MUTLAKA RAKAMLA yaz: %15,1 · 13,2 milyon TL · 205/55R16. Kelimeyle YAZMAK YASAK ("yüzde on beş", "on üç milyon" YAZMA — %15, 13 milyon TL yaz).`;
const BRAND=`Sen ${NAME} ${TANIM}nın finans analistisin. Bir MARKANIN kâr marjı analizini işletme sahibine anlat.
JSON'daki "bulgular" doğru tespitlerdir. 3-5 cümle, akıcı Türkçe, analist ağzıyla YENİDEN anlat.
KURALLAR: SADECE bulgulardaki sayı/bilgi; yeni sayı/faktör UYDURMA. ${SAYIKURAL} Muhataba İSİMLE HİTAP ETME, isim uydurma. Her markayı farklı kur. "guven" kismi ise temkinli. "saha_ipuclari" varsa "doğrulanmalı" de, yoksa değinme. "tesvik_notu"/"cozulemeyen" varsa ekle. Madde/etiket/başlık YOK; düz paragraf.`;
const CUST=`Sen ${NAME} ${TANIM}nın finans analistisin. Bir MÜŞTERİNİN durumunu işletme sahibine anlat.
JSON'daki "bulgular" doğru tespitlerdir. 3-4 cümle, akıcı Türkçe, analist ağzıyla.
KURALLAR: SADECE bulgulardaki sayı/bilgi; UYDURMA yok. ${SAYIKURAL} Muhataba İSİMLE HİTAP ETME, isim uydurma. Net pozisyon/çelişki bulgusu varsa "tek taraflı okuma yanıltıcı" mesajını koru. Madde/etiket YOK; düz paragraf.`;
const rows=(await c.query(`SELECT id, bolum, kanit FROM bi_icgoru WHERE tenant_id=$1::uuid AND durum='yeni' AND anlati IS NULL AND bolum IN ('marka-marj','musteri') ORDER BY surpriz_skoru DESC`,[T])).rows;
let yaz=0;
for(const r of rows){
  let facts={},oneri=null,guven='yaklasik',sys=BRAND;
  if(r.bolum==='marka-marj'){ const s=await c.query('SELECT sebep_arastir_marj($1::uuid,$2) j',[T,r.kanit.marka]); const j=s.rows[0].j||{}; facts=j.facts||{}; oneri=j.oneri; guven=j.guven||'yaklasik'; sys=BRAND; }
  else { const s=await c.query('SELECT sebep_arastir_musteri($1::uuid,$2) j',[T,r.kanit.kod]); const j=s.rows[0].j||{}; facts=j.facts||{}; oneri=j.oneri; guven=j.guven||'yaklasik'; sys=CUST; }
  try{ const m=await an.messages.create({model:'claude-sonnet-4-6',max_tokens:450,messages:[{role:'user',content:sys+"\n\nJSON:\n"+JSON.stringify(facts)+"\n\nSadece anlatı paragrafını yaz."}]});
    const anlati=(m.content?.[0]?.text||'').trim();
    if(anlati){ await c.query(`UPDATE bi_icgoru SET anlati=$2, oneri=$3, guven=$4, kaynak='ai-taslak', anlati_at=now() WHERE id=$1`,[r.id,anlati,oneri,guven]); yaz++; }
  }catch(e){ console.error('[nabiz-anlat]',r.bolum,e&&e.message); }
}
console.log('anlatılan: '+yaz+'/'+rows.length);
const ig=(await c.query(`SELECT bolum, COALESCE(kanit->>'marka',kanit->>'musteri') ad, anlati, surpriz_skoru
  FROM bi_icgoru WHERE tenant_id=$1::uuid AND durum='yeni' AND anlati IS NOT NULL ORDER BY surpriz_skoru DESC LIMIT 8`,[T])).rows;
const ay=(await c.query(`SELECT anahtar, soru FROM bi_sistem_sorusu WHERE tenant_id=$1::uuid AND durum='acik' AND anahtar LIKE 'aday-yasa:%' ORDER BY olusma DESC`,[T])).rows;
const cur={};
ig.forEach(x=>{ cur[(x.bolum==='marka-marj'?'MARKA':'MUSTERI')+':'+x.ad]=Number(x.surpriz_skoru)||0; });
ay.forEach(q=>{ cur['ADAY:'+q.anahtar]=1; });
const prevRow=(await c.query(`SELECT son_ogeler, son_gonderim FROM bi_nabiz_durum WHERE tenant_id=$1::uuid`,[T])).rows[0];
const prev=(prevRow&&prevRow.son_ogeler)||{};
const gunFark=(prevRow&&prevRow.son_gonderim)?Math.floor((Date.now()-new Date(prevRow.son_gonderim).getTime())/86400000):999;
const yeni=[],degisen=[];
for(const k in cur){ if(!(k in prev)) yeni.push(k); else if(Math.abs(cur[k]-prev[k])>2) degisen.push(k); }
const ilkKez=!prevRow;
const gonder = ilkKez || yeni.length>0 || degisen.length>0 || gunFark>=7;
await c.query(`INSERT INTO bi_nabiz(tenant_id,tarih,ozet,detay) VALUES ($1::uuid,CURRENT_DATE,$2,$3)
  ON CONFLICT (tenant_id,tarih) DO UPDATE SET ozet=EXCLUDED.ozet, detay=EXCLUDED.detay, created_at=now()`,
  [T, ig.map((x,i)=>(i+1)+'. '+x.ad).join('\n'), JSON.stringify({icgoru:ig.length,aday:ay.length,yeni:yeni.length,degisen:degisen.length})]);
if(!gonder){ console.log('○ Değişiklik yok ('+ig.length+' içgörü aynı). E-POSTA YOK — news-only.'); await c.end(); }
else if(!ALICI){ console.log('○ Değişiklik VAR ('+ig.length+' içgörü) ama ALICI tanımsız → sadece kaydedildi, e-posta YOK.'); await c.end(); }
else{
  const tarihTR=new Date().toLocaleDateString('tr-TR');
  const esc=s=>String(s||'').replace(/</g,'&lt;').replace(/\n/g,'<br>');
  const rozet=k=> yeni.includes(k)?' <span style="background:#059669;color:#fff;font-size:10px;padding:1px 6px;border-radius:4px">YENİ</span>':(degisen.includes(k)?' <span style="background:#d97706;color:#fff;font-size:10px;padding:1px 6px;border-radius:4px">DEĞİŞTİ</span>':'');
  const baslik = ilkKez?'ilk özet':(yeni.length+degisen.length>0?(yeni.length+' yeni · '+degisen.length+' değişen'):'haftalık hatırlatma (değişiklik yok)');
  let html=`<div style="font-family:system-ui,Arial,sans-serif;font-size:14px;color:#111;line-height:1.55;max-width:640px">`;
  html+=`<h2 style="margin:0 0 2px">${esc(NAME)} Nabız — ${tarihTR}</h2>`;
  html+=`<div style="color:#777;font-size:12px;margin-bottom:16px">${baslik} · sayılar ERP'den, yorumlar AI-taslak (doğrulanmalı)</div>`;
  html+=`<div style="font-size:15px;font-weight:600;color:#b91c1c;margin:0 0 8px">🔴 Kayda değer (${ig.length})</div>`;
  ig.forEach(x=>{ const k=(x.bolum==='marka-marj'?'MARKA':'MUSTERI')+':'+x.ad;
    html+=`<div style="margin:0 0 12px;padding:10px 12px;border-left:3px solid ${x.bolum==='marka-marj'?'#7c3aed':'#0ea5e9'};background:#faf9fb;border-radius:0 6px 6px 0"><b>${esc(x.ad)}</b> <span style="color:#999;font-size:11px">[${x.bolum==='marka-marj'?'MARKA':'MÜŞTERİ'}]</span>${rozet(k)}<div style="margin-top:4px">${esc(x.anlati)}</div></div>`; });
  if(ay.length){ html+=`<div style="font-size:15px;font-weight:600;color:#059669;margin:18px 0 8px">🎓 Onayını bekleyen keşifler (${ay.length})</div>`;
    ay.forEach(q=>{ html+=`<div style="margin:0 0 8px;padding:8px 12px;background:#f0fdf4;border-radius:6px">• ${esc(q.soru)}${rozet('ADAY:'+q.anahtar)}</div>`; }); }
  html+=`<div style="color:#aaa;font-size:11px;margin-top:18px;border-top:1px solid #eee;padding-top:8px">Derive Intelligence · yalnızca değişiklikte yazar</div></div>`;
  const subject=NAME+' Nabız — '+tarihTR+(yeni.length?(' · '+yeni.length+' yeni'):'');
  if(DRY){ console.log('◆ DRY: e-posta GÖNDERİLMEDİ (gönderilecekti → '+ALICI+'; yeni:'+yeni.length+' değişen:'+degisen.length+'). son_gonderim GÜNCELLENMEDİ.'); await c.end(); }
  else{
    try{ await sendMail(ALICI,subject,html);
      console.log('✉ e-posta gönderildi → '+ALICI+'  (yeni:'+yeni.length+' değişen:'+degisen.length+')');
      await c.query(`INSERT INTO bi_nabiz_durum(tenant_id,son_ogeler,son_gonderim) VALUES ($1::uuid,$2,CURRENT_DATE)
        ON CONFLICT (tenant_id) DO UPDATE SET son_ogeler=EXCLUDED.son_ogeler, son_gonderim=CURRENT_DATE`,[T,JSON.stringify(cur)]);
    }catch(e){ console.error('[nabiz-mail] ⚠ gönderilemedi:', e && e.message); }
    await c.end();
  }
}
NODE
done

hr "BITTI — çok-tenant; compute her gün; e-posta yalnızca değişiklikte + alıcı tanımlıysa."
