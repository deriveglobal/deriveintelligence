#!/usr/bin/env bash
# OMURGA 52 — LLM ANLATI TESTİ (sunucuya dokunmadan, konteyner içinde node ile).
# sebep_arastir_marj GERÇEKLERİNİ alır → Claude'a "sadece bu sayılar, her sefer farklı anlat" → yazdırır.
set -uo pipefail
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "LLM anlatı — CONTINENTAL, LASSA, HERKUL (aynı facts tipi, farklı anlatım beklenir)"
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
- "saha_ipuclari" varsa "sahadan gelen, doğrulanması gereken sinyal" diye ver — kesin sebep gibi sunma. Yoksa sahadan hiç bahsetme.
- "tesvik_notu" varsa kısaca ekle. "cozulemeyen" doluysa "şu kısmı netleştiremedim, sana sormak isterim" de.
- Madde işareti/etiket/başlık YOK; düz paragraf. Sayıları Türkçe yaz (%13,9 gibi).`;
for(const m of ['CONTINENTAL','LASSA','HERKUL']){
  const r=await c.query('SELECT sebep_arastir_marj($1::uuid,$2) j',[T,m]);
  const f=r.rows[0].j||{};
  const facts=f.facts||{};
  const msg=await an.messages.create({model:'claude-sonnet-4-6',max_tokens:450,
    messages:[{role:'user',content:sys+"\n\nJSON:\n"+JSON.stringify(facts,null,1)+"\n\nSadece anlatı paragrafını yaz."}]});
  console.log("\n===== "+m+" (guven="+f.guven+") =====\n"+msg.content[0].text+"\n");
}
await c.end();
NODE
hr "BITTI — 3 anlatım farklı mı, sayılar facts'le uyumlu mu (uydurma var mı) bak."
