#!/usr/bin/env bash
# OMURGA 54 (Parça B) — seçilen içgörülere LLM anlatısı yaz → bi_icgoru (AI-taslak). Konteyner-içi.
set -uo pipefail
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "Motor + LLM anlatı → bi_icgoru (4 marka)"
docker exec -i -w /app -e T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' krb-assessment node --input-type=module <<'NODE' 2>&1 | sed 's/^/  /'
import pg from 'pg';
import Anthropic from '@anthropic-ai/sdk';
const T=process.env.T;
const c=new pg.Client({connectionString:process.env.DATABASE_URL}); await c.connect();
const an=new Anthropic({apiKey:process.env.ANTHROPIC_API_KEY});
const sys=`Sen KRB adlı lastik toptancısının finans analistisin. İşletme sahibine bir markanın kâr marjı analizini anlatıyorsun.
Sana JSON verilecek. İçindeki "bulgular" listesi, markaya ait DOĞRU ve KANITLI tespit cümleleridir.
Görevin: bu bulguları doğal, akıcı Türkçe ile KISA (3-5 cümle) tek paragraf olarak, analist ağzıyla YENİDEN anlatmak.
KATI KURALLAR:
- SADECE bulgulardaki bilgiyi ve sayıları kullan. ASLA yeni sayı/oran/tarih/faktör UYDURMA. Bulgularda olmayan hiçbir rakamı veya "döviz etkisi" gibi yeni bir kalem EKLEME.
- Her markayı FARKLI kur; sabit şablon/sıra kullanma. En ağır etkenle başla.
- "guven" kismi ise temkinli konuş. Bir bulgu "seri kısa/kesin değil" diyorsa bunu koru.
- "saha_ipuclari" varsa "sahadan gelen, doğrulanması gereken sinyal" diye ver; yoksa sahadan hiç bahsetme.
- "tesvik_notu" varsa kısaca ekle. "cozulemeyen" doluysa "şu kısmı netleştiremedim, sana sormak isterim" de.
- Madde işareti/etiket/başlık YOK; düz paragraf. Sayıları Türkçe yaz (%13,9 gibi).`;
// 1) motoru çalıştır
await c.query('SELECT icgoru_uret_finans($1::uuid)',[T]);
// 2) anlatısı olmayan seçilenleri getir
const rows=(await c.query(`SELECT id, kanit->>'marka' marka FROM bi_icgoru WHERE tenant_id=$1::uuid AND bolum='marka-marj' AND durum='yeni' AND anlati IS NULL ORDER BY surpriz_skoru DESC`,[T])).rows;
let yaz=0;
for(const r of rows){
  const s=await c.query('SELECT sebep_arastir_marj($1::uuid,$2) j',[T,r.marka]);
  const j=s.rows[0].j||{}; const facts=j.facts||{};
  const msg=await an.messages.create({model:'claude-sonnet-4-6',max_tokens:450,
    messages:[{role:'user',content:sys+"\n\nJSON:\n"+JSON.stringify(facts,null,1)+"\n\nSadece anlatı paragrafını yaz."}]});
  const anlati=(msg.content?.[0]?.text||'').trim();
  if(anlati){ await c.query(`UPDATE bi_icgoru SET anlati=$2, oneri=$3, guven=$4, kaynak='ai-taslak', anlati_at=now() WHERE id=$1`,[r.id,anlati,j.oneri||null,j.guven||'yaklasik']); yaz++; }
  console.log("\n===== "+r.marka+" (guven="+(j.guven)+") =====\n"+anlati+"\n");
}
console.log("\n>>> yazılan anlatı: "+yaz+"/"+rows.length);
await c.end();
NODE
hr "BITTI — bi_icgoru artık AI-taslak anlatılarla dolu. Parça C: GET /api/bi/icgoru + auto-refresh."
