import { readFileSync, writeFileSync } from 'node:fs';
const D = 'server_container.mjs';
const YAZ = process.argv.includes('--yaz');

const EDITS = [

{ ad: 'A. GECMIS ZEHRI — karsilama kendi dunku ciktisini gercek saniyordu',
  bul: String.raw`        const messages = hist.length ? hist.map(r => ({ role: r.role, content: r.content })) : [{ role: 'user', content: userMsg }];`,
  koy: String.raw`        // ⚠ GECMIS_ZEHRI_V1 — 14 Tem. KOK NEDEN BURASIYDI.
        //   14 Tem sabahi karsilama, Fatih Bilen'e "3 acik gecikmis gorev" dedi.
        //   Ucu de 13 Tem'de 'done' idi. tasksCtx sorgusu DOGRUYDU.
        //   Model sorguyu degil, gecmisteki KENDI dunku cumlesini okudu ve tekrarladi.
        //   Ve o listeden hukum kurdu: "ciro/stok rakamlari guvenilmez" — oysa duzelmisti.
        //   Bir KARSILAMA, o anki durumun BEYANIDIR. Gecmis miras ALMAZ.
        const _isGreet = !!body.is_greeting;
        const messages = (!_isGreet && hist.length)
          ? hist.map(r => ({ role: r.role, content: r.content }))
          : [{ role: 'user', content: userMsg }];`
},

{ ad: 'B. tasksCtx — kapali dunya + sessiz catch kaldirildi',
  bul: String.raw`          if (r.rows.length) {
            tasksCtx = '\n\nAçık görevler (öncelik sırasıyla):\n' + r.rows.map(t =>
              '- [' + t.priority.toUpperCase() + '] ' + t.title +
              (t.assigned_to ? ' → ' + t.assigned_to : '') +
              (t.due_date ? ' (📅 ' + t.due_date + ')' : '')
            ).join('\n');
          }
        } catch {}`,
  koy: String.raw`          if (r.rows.length) {
            tasksCtx = '\n\nAçık görevler (öncelik sırasıyla):\n' + r.rows.map(t =>
              '- [' + t.priority.toUpperCase() + '] ' + t.title +
              (t.assigned_to ? ' → ' + t.assigned_to : '') +
              (t.due_date ? ' (📅 ' + t.due_date + ')' : '')
            ).join('\n');
          } else {
            tasksCtx = '\n\nAçık görev YOK. Tüm görevler kapalı.';
          }
          tasksCtx += '\n⚠ BU LİSTE TAMDIR — şu an veritabanından okundu. Burada olmayan bir görev' +
                      ' AÇIK DEĞİLDİR. Geçmiş konuşmalardan görev hatırlama; kapatılmış olabilir.' +
                      ' Bir görevi "gecikmiş" ya da "açık" diye ancak BU listede görüyorsan söyle.';
        } catch (_te) {
          console.error('[brain] gorev listesi OKUNAMADI:', _te.message);
          tasksCtx = '\n\n⚠ GÖREV LİSTESİ OKUNAMADI. Görevler hakkında HİÇBİR ŞEY söyleme —' +
                     ' "açık görev yok" da deme, "gecikmiş görev var" da deme. Bilmiyorsun.';
        }`
},

{ ad: 'C. BILINEN_SORUNLAR — sayilar gider, DERSLER kalir, kosulsuz guven beyani gider',
  bul: String.raw`                'ERP VERISI 13.07 GECESI TAMAMEN YENIDEN YUKLENDI (BAYAT_V2). ' +
                'Satis: 364.785 satir (2021-10 .. 2026-07). Alis: 146.680 satir. ' +
                'Haziran 2026 cirosu = 121,76 M TL — Fatih Bilen\'in 09.07\'de soyledigi 121,79M ile ORTUSUYOR. ' +
                'ESKI SORUN NEYDI: (a) SAP tarihleri GG/AA yazar, Excel AA/GG okuyordu; gunu <=12 olan ' +
                'faturalar Agustos-Aralik\'a savruluyordu — Haziran yarim gorunuyordu. (b) Export SADECE ' +
                'lastik kalem gruplarini iceriyordu; servis/jant/aku/yedek parca (cironun ~%26\'si) hic yoktu. ' +
                'IKISI DE DUZELTILDI. Artik ciro rakamlarina guvenilebilir.',
                'ALIS VADESI ARTIK HESAPLANIYOR: onceden 28.252 satirin TAMAMINDA vade_tarihi NULL\'du. ' +
                'Ortalama alis vadesi 2021\'de 66,7 gun iken 2025\'te 40,7 gune dusmus — tedarikciler ' +
                'KRB\'nin vadesini 4 yilda 26 gun kismis. Bu, sistemin ilk kez gorebildigi bir sey.',`,
  koy: String.raw`                'ERP VERISI 13.07 GECESI TAMAMEN YENIDEN YUKLENDI (BAYAT_V2). ' +
                'ESKI SORUN NEYDI: (a) SAP tarihleri GG/AA yazar, Excel AA/GG okuyordu; gunu <=12 olan ' +
                'faturalar Agustos-Aralik\'a savruluyordu — Haziran yarim gorunuyordu. (b) Export SADECE ' +
                'lastik kalem gruplarini iceriyordu; servis/jant/aku/yedek parca hic yoktu. IKISI DE DUZELTILDI. ' +
                '⚠ SATIR SAYISI, AY CIROSU, KALEM PAYI GIBI RAKAMLAR BURADA YAZILI DEGILDIR — sorgudan oku. ' +
                '⚠ "Artik rakamlara guvenilebilir" DEME. Bu kosulsuz bir guven beyanidir ve bir sonraki ' +
                'bozuk yuklemede de ayni seyi soyler. Verinin saglikli oldugunu iddia etmeden once ' +
                'bi_ingestion_log\'a bak: son yukleme ne zaman, kac satir reddedildi.',
                'ALIS VADESI ARTIK HESAPLANIYOR: onceden vade_tarihi TAMAMEN NULL\'du. Ortalama alis vadesi ' +
                'yillar icinde KISALDI — tedarikciler KRB\'nin vadesini daraltti. Bu, sistemin ilk kez ' +
                'gorebildigi bir sey. ⚠ Gun sayilari burada YAZILI DEGILDIR: bi_tedarikci_faturalari\'ndan hesapla.',`
},

{ ad: 'D1. Brisa brifingi — Promise.all\'a Haziran sorgusu',
  bul: String.raw`              const [_kam, _lassa, _ucuz] = await Promise.all([`,
  koy: String.raw`              const [_kam, _lassa, _ucuz, _haz] = await Promise.all([`
},

{ ad: 'D2. Brisa brifingi — Haziran CANLI + sayi yoksa brifing GOSTERILMIYOR',
  bul: String.raw`              ]);
              const k = _kam.rows[0] || {};
              const l = _lassa.rows[0] || {};
              const u = _ucuz.rows[0] || {};`,
  koy: [
'                ,',
'                // ⚠ HAZIRAN CIROSU — CANLI. Onceden 121,76 diye SABIT yaziliydi ve altinda',
'                //   "Rakamlari DEGISTIRME" yaziyordu. ERP yeniden yuklenip Haziran kayarsa,',
'                //   sabit sayi adama hala "senin rakamin" derdi. Simdi her acilista SAYILIYOR.',
'                query("SELECT round(sum(satir_tutar)/1000000.0, 2)::text AS m_tl, count(*)::int AS satir" +',
'                      "  FROM bi_satis_faturalari" +',
'                      " WHERE tenant_id=$1::text" +',
'                      "   AND fatura_tarihi >= DATE \'2026-06-01\'" +',
'                      "   AND fatura_tarihi <  DATE \'2026-07-01\'", [tenantId])',
'              ]);',
'              const k = _kam.rows[0] || {};',
'              const l = _lassa.rows[0] || {};',
'              const u = _ucuz.rows[0] || {};',
'              const h = _haz.rows[0] || {};',
'              // ⚠ KAPI: sayi yoksa BRIFING HIC GOSTERILMEZ. Sessizce "0 M TL" yazmaktansa',
'              //   ozru hic soylememek yeglenir. catch (_be) bunu loglar.',
"              if (!h.m_tl) throw new Error('brisa: Haziran cirosu okunamadi — brifing gosterilmiyor');"
].join('\n')
},

{ ad: 'D3. Brifing 2. bolum — sabit sayi -> canli',
  bul: String.raw`   Ikisi de duzeltildi. 6 yil yeniden yuklendi: 364.785 satis satiri.
   HAZIRAN 2026 = 121,76 M TL. Senin rakamin. Artik ayni seyi konusuyoruz.`,
  koy: [
'   Ikisi de duzeltildi. 6 yil yeniden yuklendi: ${h.satir || 0} satis satiri.',
'   HAZIRAN 2026 = ${h.m_tl} M TL. Senin rakamin. Artik ayni seyi konusuyoruz.',
'   (Bu sayi SU AN veritabanindan okundu — sabit yazilmadi. Veri degisirse yeniden sayilir.)'
].join('\n')
},

{ ad: 'D4. Brifing kapanis — "121,76 diyorsam dogrudur" -> canli',
  bul: String.raw`   "Haziran'i sor bana. 121,76 diyorsam dogrudur; degilse yuzume vur."`,
  koy: '   "Haziran\'i sor bana. ${h.m_tl} diyorsam dogrudur; degilse yuzume vur."'
},

];

let m = readFileSync(D, 'utf8');
const asil = m, hata = [];
for (const e of EDITS) {
  const n = m.split(e.bul).length - 1;
  if (n !== 1) { hata.push('✗ ' + e.ad + ' — capa ' + n + ' kez bulundu (1 olmali)'); continue; }
  m = m.replace(e.bul, e.koy);
  console.log('✓ ' + e.ad);
}
if (hata.length) { console.error('\n!! DOSYAYA DOKUNULMADI:\n' + hata.join('\n')); process.exit(1); }
if (!YAZ) { console.log('\n— DENEME. 7/7 tuttu. Yazmak icin: node ./yama2.mjs --yaz'); process.exit(0); }
const y = D + '.yedek2_' + Date.now();
writeFileSync(y, asil); writeFileSync(D, m);
console.log('\n✓ Yazildi. Yedek: ' + y);
