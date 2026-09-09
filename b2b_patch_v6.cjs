#!/usr/bin/env node
// bi.js B2B loader blogunu V6 (desen imzali akilli eslesme) ile degistirir.
// Kullanim (sunucuda):
//   scp ile /opt/krb-assessment/ altina: b2b_loader.js + b2b_patch_v6.js
//   node /opt/krb-assessment/b2b_patch_v6.js
const fs=require('fs'), cp=require('child_process');
const BI='/opt/krb-assessment/shells/bi.js';
const LOADER='/opt/krb-assessment/b2b_loader.js';
const START='// B2B_TAB_V1 · B2B_LOADER';                 // baslangic marker (prefix)
const END ='// ═══ URUN MASTER (URUN_MASTER_V1)';         // bitis marker
if(!fs.existsSync(LOADER)){console.error('HATA: '+LOADER+' yok — once scp et');process.exit(1);}
let src=fs.readFileSync(BI,'utf8');
if(src.indexOf('AKILLI EŞLEŞTİRME v6')>=0){console.log('⏭  Zaten V6 kurulu — atlandi');process.exit(0);}
const lines=src.split('\n');
const sc=lines.filter(function(l){return l.indexOf(START)>=0;}).length;
const ec=lines.filter(function(l){return l.indexOf(END)>=0;}).length;
if(sc!==1||ec!==1){console.error('HATA: marker tekil degil (start='+sc+' end='+ec+')');process.exit(1);}
const si=lines.findIndex(function(l){return l.indexOf(START)>=0;});
const ei=lines.findIndex(function(l){return l.indexOf(END)>=0;});
if(si<0||ei<0||ei<=si){console.error('HATA: marker sirasi bozuk si='+si+' ei='+ei);process.exit(1);}
// orijinal node --check'ten geciyor mu? (browser dosyasi olabilir)
let origOk=true; try{cp.execSync('node --check '+BI,{stdio:'pipe'});}catch(e){origOk=false;}
const loader=fs.readFileSync(LOADER,'utf8').replace(/\n+$/,'');
const marker='    // B2B_TAB_V1 · B2B_LOADER_V6 — desen imzali akilli eslesme (AKILLI EŞLEŞTİRME v6)';
const out=lines.slice(0,si).concat([marker], loader.split('\n'), [''], lines.slice(ei)).join('\n');
const bak=BI+'.bak_v6_'+Date.now();
fs.writeFileSync(bak,src);
fs.writeFileSync(BI,out);
if(origOk){
  try{cp.execSync('node --check '+BI,{stdio:'pipe'});}
  catch(e){fs.writeFileSync(BI,src);console.error('✗ SYNTAX FAIL — geri alindi.\n'+(e.stderr?e.stderr.toString():e.message));process.exit(1);}
  console.log('✓ node --check (tam dosya) OK');
}else{
  try{cp.execSync('node --check '+LOADER,{stdio:'pipe'});console.log('✓ loader fragmani OK (tam dosya browser-only, atlandi)');}
  catch(e){fs.writeFileSync(BI,src);console.error('✗ loader SYNTAX FAIL — geri alindi.\n'+(e.stderr?e.stderr.toString():e.message));process.exit(1);}
}
console.log('✓ V6 yazildi · yedek: '+bak+' · '+lines.length+'→'+out.split('\n').length+' satir');
console.log('Simdi: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment');
