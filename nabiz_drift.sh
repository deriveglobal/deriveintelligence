#!/usr/bin/env bash
# NABIZ-DRIFT — fingerprint drift alarmi (news-only). nabiz.sh'tan BAGIMSIZ; ayni Graph mailer.
# Kural: bir sey deftere KOR girmisse (durum=tanimsiz / ne_ise_yarar bos) veya KAYIP olmussa,
#        ertesi sabah e-posta. Yalniz SAYI ARTINCA (yeni drift) veya Pazartesi hatirlatma gonderir.
set -uo pipefail
docker exec -i -w /app \
  -e ALICI="${NABIZ_ALICI:-fatih@deriveglobal.com,fbilen@krb.com.tr}" \
  krb-assessment node --input-type=module <<'NODE' 2>&1 | sed 's/^/  /'
import pg from 'pg';
const c=new pg.Client({connectionString:process.env.DATABASE_URL}); await c.connect();

// state tablosu
await c.query(`CREATE TABLE IF NOT EXISTS bi_fingerprint_durum(
  tekil boolean PRIMARY KEY DEFAULT true, son_tanimsiz int DEFAULT 0, son_kontrol date)`);

// KOR yetenekler + KAYIP + AUTO_DDL stub (zenginlestirilmemis)
const kor=(await c.query(`SELECT ad, tur FROM bi_yetenek
  WHERE aktif AND (ne_ise_yarar IS NULL OR ne_ise_yarar='' OR durum='tanimsiz')
  ORDER BY eklendi_at DESC`)).rows;
const kayip=(await c.query(`SELECT ad, tur FROM bi_yetenek WHERE aktif AND durum='kayip'`)).rows;
const autostub=(await c.query(`SELECT adim FROM bi_insa_gunlugu
  WHERE adim LIKE 'AUTO_DDL:%' AND ts > now()-interval '3 days' ORDER BY ts DESC`)).rows;

const cur=kor.length;
const prevRow=(await c.query(`SELECT son_tanimsiz, son_kontrol FROM bi_fingerprint_durum WHERE tekil`)).rows[0];
const prevN=prevRow?Number(prevRow.son_tanimsiz):-1;
const isMon=(new Date().getDay()===1);
const gonder = cur>prevN || (isMon && cur>0) || kayip.length>0 || autostub.length>0;

await c.query(`INSERT INTO bi_fingerprint_durum(tekil,son_tanimsiz,son_kontrol)
  VALUES(true,$1,CURRENT_DATE) ON CONFLICT (tekil) DO UPDATE SET son_tanimsiz=$1, son_kontrol=CURRENT_DATE`,[cur]);

if(!gonder){ console.log('○ drift yok/artmadi (kor='+cur+'). E-POSTA YOK.'); await c.end(); }
else{
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
  const tarihTR=new Date().toLocaleDateString('tr-TR');
  const esc=s=>String(s||'').replace(/</g,'&lt;');
  const grup={};
  kor.forEach(x=>{ (grup[x.tur]=grup[x.tur]||[]).push(x.ad); });
  let html=`<div style="font-family:system-ui,Arial,sans-serif;font-size:14px;color:#111;line-height:1.55;max-width:640px">`;
  html+=`<h2 style="margin:0 0 2px">🧬 Fingerprint Drift — ${tarihTR}</h2>`;
  html+=`<div style="color:#777;font-size:12px;margin-bottom:16px">Bir sey insa edildi ama ANLAMLANDIRILMADI. CEO asistani bunlari bilmez/kullanamaz. Doldur: derive-ogrenme-fingerprint-protokol.md</div>`;
  html+=`<div style="font-size:15px;font-weight:600;color:#b45309">Tarifsiz yetenek: ${cur}${prevN>=0&&cur>prevN?(' (↑ '+(cur-prevN)+' yeni)'):''}</div>`;
  for(const t in grup){ html+=`<div style="margin:8px 0 2px;font-weight:600;color:#555">${esc(t)}</div><div style="color:#333">${grup[t].map(esc).join(' · ')}</div>`; }
  if(kayip.length){ html+=`<div style="margin-top:14px;font-weight:600;color:#b91c1c">⚠ KAYIP (silinmis/yeniden adlanmis): ${kayip.length}</div><div style="color:#333">${kayip.map(x=>esc(x.ad)).join(' · ')}</div>`; }
  if(autostub.length){ html+=`<div style="margin-top:14px;font-weight:600;color:#7c3aed">🆕 Son 3 gun otomatik DDL izi (aciklama bekliyor): ${autostub.length}</div><div style="color:#333;font-size:12px">${autostub.map(x=>esc(x.adim.replace('AUTO_DDL:',''))).join(' · ')}</div>`; }
  html+=`<div style="color:#aaa;font-size:11px;margin-top:18px;border-top:1px solid #eee;padding-top:8px">Derive Intelligence · yalniz drift artinca / Pazartesi yazar</div></div>`;
  try{ await sendMail(process.env.ALICI,'🧬 Fingerprint Drift — '+cur+' tarifsiz'+(kayip.length?(' · '+kayip.length+' kayip'):''),html);
    console.log('✉ drift alarmi gonderildi → '+process.env.ALICI+' (kor='+cur+' kayip='+kayip.length+')');
  }catch(e){ console.error('[drift-mail] ⚠', e&&e.message); }
  await c.end();
}
NODE
echo "[nabiz-drift] bitti"

# --- agnostik nobetci: yeni drift varsa deploy dur ---
bash /opt/krb-assessment/agnostik_nobetci.sh || exit 1
