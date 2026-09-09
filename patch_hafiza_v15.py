#!/usr/bin/env python3
# HAFIZA_V15 — BEYAN vs GOZLEM + "unut/duzelt". HAFIZA_V1 uzerine biner.
#   1) Damitici her gercege kaynak=beyan|gozlem etiketi + guven verir (gozlem>beyan).
#   2) Hatirlama gozlem-once siralar, satirlari (gozlem)/(beyan) etiketler, celiskiyi fark ettirir.
#   3) unut_hafiza araci: owner "unut / yanlis tanidin / gecerli degil" derse gecerli=false (soft-forget).
#   Ilke (Fatih): insan yalan soyler, davranis soylemez — gozlem beyandan guvenilir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "HAFIZA_V15" in s:
    print("[skip] HAFIZA_V15 zaten var"); sys.exit(0)
if "HAFIZA_V1" not in s:
    print("HATA: once HAFIZA_V1 uygulanmali"); sys.exit(1)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor bulunamadi -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# ── 1) Damitici SYS: kaynak rehberi + sema alani ──
rep(
r'''"Cikti: SADECE JSON dizi (max 3 oge): [{\"kategori\":\"musteri|karar|oruntu|tercih|kisi_profili|oncelik|uslup\",\"konu\":\"kisa ozne anahtari\",\"icerik\":\"tek cumle kalici gercek\",\"kisi\":true veya false}]. Kalici hicbir sey yoksa []. Baska hicbir metin yazma.";''',
r'''"KAYNAK ETIKETI: her ogeye kaynak koy. 'gozlem' = veriden/olcumden/davranistan gozlenen kalici oruntu; 'beyan' = kisinin SOYLEDIGI iddia/tercih. Insanlar kandirir — soylenen 'beyan'dir ve guveni dusuktur; emin degilsen 'beyan'.\n" +
            "Cikti: SADECE JSON dizi (max 3 oge): [{\"kategori\":\"musteri|karar|oruntu|tercih|kisi_profili|oncelik|uslup\",\"konu\":\"kisa ozne anahtari\",\"icerik\":\"tek cumle kalici gercek\",\"kisi\":true veya false,\"kaynak\":\"beyan|gozlem\"}]. Kalici hicbir sey yoksa []. Baska hicbir metin yazma.";''',
"damitici-sys-kaynak")

# ── 2) Damitici INSERT: kaynak + guven ──
rep(
r'''else { await query("INSERT INTO bi_tenant_hafiza (tenant_id, user_id, kategori, konu, icerik, kisi, kaynak) VALUES ($1,$2,$3,$4,$5,$6,'damitma')", [tenantId, kisi ? (userId || null) : null, kat, konu, ic, kisi]); }''',
r'''else { const _kyn=(String(it.kaynak||'beyan').toLowerCase().indexOf('goz')>=0)?'gozlem':'beyan'; const _gvn=_kyn==='gozlem'?0.9:0.55; await query("INSERT INTO bi_tenant_hafiza (tenant_id, user_id, kategori, konu, icerik, kisi, kaynak, guven) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)", [tenantId, kisi ? (userId || null) : null, kat, konu, ic, kisi, _kyn, _gvn]); }''',
"damitici-insert")

# ── 3) Hatirlama sorgusu: kaynak sec + gozlem-once sirala ──
rep(
r'''SELECT konu, icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND (kisi IS NOT TRUE) AND gecerli ORDER BY son_gorulme DESC LIMIT 200''',
r'''SELECT konu, icerik, kaynak FROM bi_tenant_hafiza WHERE tenant_id=$1 AND (kisi IS NOT TRUE) AND gecerli ORDER BY (kaynak='gozlem') DESC, guven DESC, son_gorulme DESC LIMIT 200''',
"hatirlama-sorgu")

# ── 4) Hatirlama render: satir etiketi (gozlem)/(beyan) ──
rep(
r'''_facts.slice(0, 12).map(r => '\n- ' + r.icerik).join('')''',
r'''_facts.slice(0, 12).map(r => '\n- ' + r.icerik + (r.kaynak==='gozlem'?' (gözlem)':' (beyan)')).join('')''',
"hatirlama-render")

# ── 5) TENANT HAFIZASI etiket metni: beyan/gozlem + celiski ──
rep(
r'''TENANT HAFIZASI (1. gunden damitilmis KALICI gercekler — ipucu, SAYI/ANLIK DURUM DEGIL; guncel rakam/durum icin MUTLAKA canli araci cagir, hafizayi canli verinin YERINE koyma): ''',
r'''TENANT HAFIZASI (1. gunden damitilmis KALICI gercekler — ipucu, SAYI/ANLIK DURUM DEGIL; guncel rakam/durum icin MUTLAKA canli araci cagir; (gozlem)=veriden dogru, (beyan)=soylenen iddia — CELISIRSE gozleme guven ve soz-eylem farkini fark et): ''',
"hafiza-etiket")

# ── 6) unut_hafiza arac tanimi (save_note tanimindan sonra) ──
SN_DEF = r'''        {
          name: 'save_note',
          description: 'Save an important insight, decision, or piece of information for future context.',
          input_schema: {
            type: 'object',
            properties: {
              content: { type: 'string', description: 'Note content' },
              tags: { type: 'array', items: { type: 'string' }, description: 'Optional tags' }
            },
            required: ['content']
          }
        },'''
UNUT_DEF = SN_DEF + r'''
        {
          name: 'unut_hafiza',
          description: 'Kalici hafizadaki bir bilgiyi GECERSIZ kil (soft-forget, silme degil). Kullanici "onu unut", "o dogru degil", "beni/durumu yanlis tanidin", "bu artik gecerli degil" derse cagir. Eslesen kalici gercek(ler) gecerli=false olur, bir daha baglama girmez.',
          input_schema: {
            type: 'object',
            properties: {
              konu: { type: 'string', description: 'Unutulacak bilginin konusu ya da iceriginden bir ifade (eslestirme icin)' }
            },
            required: ['konu']
          }
        },'''
rep(SN_DEF, UNUT_DEF, "unut-arac-tanimi")

# ── 7) unut_hafiza handler (save_note handler'indan sonra) ──
SN_H = r'''        if (toolName === 'save_note') {
          const { content, tags = [] } = input;
          await query('INSERT INTO brain_notes (tenant_id, content, tags) VALUES ($1,$2,$3)', [tenantId, content, tags]);
          return { success: true, message: 'Not kaydedildi.' };
        }'''
UNUT_H = SN_H + r'''
        if (toolName === 'unut_hafiza') { /* HAFIZA_V15 */
          const _uq = String((input && input.konu) || '').trim();
          if (_uq.length < 2) return { success: false, message: 'Ne unutulacak belirtilmedi.' };
          const _ur = await query("UPDATE bi_tenant_hafiza SET gecerli=false WHERE tenant_id=$1 AND gecerli=true AND (icerik ILIKE '%'||$2||'%' OR konu ILIKE '%'||$2||'%') RETURNING id", [tenantId, _uq]);
          return { success: true, message: (_ur.rowCount || 0) + ' kayit unutuldu (gecersiz kilindi).' };
        }'''
rep(SN_H, UNUT_H, "unut-handler")

# ── 8) Sistem prompt kural 6: beyan/gozlem + unut farkindaligi ──
rep(
"6. Önemli bilgileri save_note kaydet.",
'6. Önemli bilgileri save_note kaydet. Kalıcı hafızan var: gozlem (veriden gozlenen) beyandan (soylenen) daha guvenilir — celisirse gozleme guven ve soz-eylem farkini fark et; kullanıcı "unut / yanlis tanidin / artik gecerli degil" derse unut_hafiza cagir.',
"sistem-prompt-kural6")

s = s + "\n/* HAFIZA_V15 */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] HAFIZA_V15 — beyan/gozlem etiketi + guven agirligi + unut_hafiza araci")
