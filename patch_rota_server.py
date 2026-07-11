# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ROTA — Eftal's bug: "Asistan konum kaydedilmiyor, rota öner deyince konum yok diyor".
#
# Real cause: saha_rep_profil was WRITE-ONLY. Nothing read it. The front even sends
# current_lat/current_lng on route questions and the server ignored them. And the
# rep agent had NO route tool at all. So "rota öner" could never work.
#
# Fix:
#   1. Resolve the starting point: today's daily start -> live GPS -> home base.
#   2. Inject it into the system prompt (context, not a tool — the model always sees it).
#   3. Add a real rota_oner tool. Customers have NO coordinates (0/1015), but they do
#      have city/district — so return the data and let the model do the geography.
#   4. Endpoints for the daily starting point.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# ── 1) resolve starting point + build the context block, before the tools array ──
rep(
'''      const _repTools = [
        { name: 'musteri_ara', description: 'Müşteriyi firma adıyla ara.', input_schema: { type:'object', properties:{ q:{type:'string'} }, required:['q'] } },''',
'''      // ── BAŞLANGIÇ NOKTASI: bugünkü başlangıç → canlı GPS → ev/merkez ──────────
      let _bas = null;
      try {
        const _gb = await pool.query(
          "SELECT sehir, ilce, lat, lng FROM saha_rep_gunluk_baslangic WHERE tenant_id=$1 AND rep_id=$2 AND tarih=CURRENT_DATE",
          [session.tenantId, session.userId]);
        if (_gb.rowCount) _bas = { kaynak: 'BUGUN', sehir: _gb.rows[0].sehir, ilce: _gb.rows[0].ilce, lat: _gb.rows[0].lat, lng: _gb.rows[0].lng };
      } catch (_) {}
      if (!_bas && body.current_lat && body.current_lng) {
        _bas = { kaynak: 'GPS', sehir: null, ilce: null, lat: body.current_lat, lng: body.current_lng };
      }
      if (!_bas) {
        try {
          const _bp = await pool.query(
            "SELECT base_adres, base_lat, base_lng FROM saha_rep_profil WHERE tenant_id=$1 AND rep_id=$2",
            [session.tenantId, session.userId]);
          if (_bp.rowCount && (_bp.rows[0].base_adres || _bp.rows[0].base_lat)) {
            _bas = { kaynak: 'MERKEZ', sehir: _bp.rows[0].base_adres, ilce: null, lat: _bp.rows[0].base_lat, lng: _bp.rows[0].base_lng };
          }
        } catch (_) {}
      }
      const _basMetin = _bas
        ? `${_bas.sehir || ''}${_bas.ilce ? ' / ' + _bas.ilce : ''}${_bas.lat ? ` (${_bas.lat}, ${_bas.lng})` : ''}`.trim()
        : '';
      const _konumEk = _bas
        ? "\\n\\nBAŞLANGIÇ NOKTASI (" +
          (_bas.kaynak === 'BUGUN' ? 'bugün için ayarlandı' : _bas.kaynak === 'GPS' ? 'şu anki GPS konumu' : 'ev/merkez konumu') +
          "): " + _basMetin +
          "\\n- rota_oner: Rota / 'kimleri ziyaret etmeliyim' / gezi planı sorularında MUTLAKA bu aracı çağır." +
          "\\n- Müşterilerde GPS koordinatı YOKTUR; sadece şehir/ilçe bilgisi vardır. Rota kurarken kendi Türkiye coğrafya bilgini kullan: başlangıç noktasına yakın şehir/ilçeleri grupla, aynı bölgedekileri arka arkaya koy, uzun süredir uğranmamışlara öncelik ver. Tahmini km verme; yerine mantıklı bir sıra ve kısa gerekçe ver."
        : "\\n\\nBAŞLANGIÇ NOKTASI: AYARLANMAMIŞ. Rota sorulursa önce 'Bugün nereden başlıyorsun?' diye SOR (şehir yeter). Kullanıcı şehir söylerse rota_oner aracını o şehirle çağır.";

      const _repTools = [
        { name: 'rota_oner', description: 'Bugunku ziyaret rotasi icin aday musteriler: temsilcinin KENDI musterilerinden en uzun suredir ugranmamis olanlari sehir/ilce ve son ziyaret bilgisiyle dondurur. Rota, gezi plani, "kimleri ziyaret etmeliyim", "bugun nereye gideyim" sorularinda MUTLAKA cagir. Musterilerde koordinat YOKTUR; donen sehir/ilce metnine ve kendi cografya bilgine gore sirala.', input_schema: { type:'object', properties:{ sehir:{type:'string', description:'Sadece bu sehir/ilce ile filtrele (opsiyonel)'}, gun:{type:'number', description:'En az kac gundur ziyaret edilmemis olsun (opsiyonel)'}, limit:{type:'number', description:'varsayilan 30'} } } },
        { name: 'musteri_ara', description: 'Müşteriyi firma adıyla ara.', input_schema: { type:'object', properties:{ q:{type:'string'} }, required:['q'] } },''',
    "rota-konum-and-tool")

# ── 2) implement the tool ────────────────────────────────────────────────────
rep(
'''      async function _runRepTool(nm, inp) {
        if (nm === 'musteri_ara') {''',
'''      async function _runRepTool(nm, inp) {
        if (nm === 'rota_oner') {
          const _g = Math.max(Number(inp.gun) || 0, 0);
          const _l = Math.min(Math.max(Number(inp.limit) || 30, 5), 60);
          const _s = String(inp.sehir || '').trim();
          const p = [session.tenantId, session.userId];
          let w = '';
          if (_s) { p.push('%' + _s + '%'); w += ` AND (m.il ILIKE $${p.length} OR m.ilce ILIKE $${p.length})`; }
          if (_g > 0) { p.push(_g); w += ` AND (sz.son_ziyaret IS NULL OR sz.son_ziyaret::date <= (CURRENT_DATE - $${p.length}::int))`; }
          p.push(_l);
          const r = await pool.query(`
            SELECT m.id, m.firma, m.il, m.ilce, m.durum, m.telefon,
                   sz.son_ziyaret::date AS son_ziyaret,
                   CASE WHEN sz.son_ziyaret IS NULL THEN NULL
                        ELSE (CURRENT_DATE - sz.son_ziyaret::date) END AS gun_gecti
              FROM saha_musteri m
              LEFT JOIN LATERAL (
                SELECT MAX(z.ziyaret_tarihi) AS son_ziyaret
                  FROM saha_ziyaret z
                 WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'
              ) sz ON true
             WHERE m.tenant_id = $1 AND m.aktif = true AND m.sorumlu_rep = $2 ${w}
             ORDER BY (sz.son_ziyaret IS NULL) DESC, sz.son_ziyaret ASC NULLS FIRST, m.firma
             LIMIT $${p.length}`, p);
          return {
            baslangic: _bas ? { kaynak: _bas.kaynak, sehir: _bas.sehir, ilce: _bas.ilce, lat: _bas.lat, lng: _bas.lng } : null,
            uyari: 'Musterilerde GPS koordinati yok; sehir/ilce metnine ve kendi cografya bilgine gore grupla ve sirala. Km tahmini verme.',
            aday_sayisi: r.rowCount,
            adaylar: r.rows
          };
        }
        if (nm === 'musteri_ara') {''',
    "rota-tool-impl")

# ── 3) feed the location into the model's system prompt ──────────────────────
rep(
"          const _res = await anthropic.messages.create({ model: 'claude-sonnet-4-6', max_tokens: 1400, system: _repSys, tools: _repTools, messages: _msgs });",
"          const _res = await anthropic.messages.create({ model: 'claude-sonnet-4-6', max_tokens: 1400, system: _repSys + _konumEk, tools: _repTools, messages: _msgs });",
    "rota-inject-prompt")

# ── 4) daily starting point endpoints ────────────────────────────────────────
rep(
'    if (method === "GET" && path === "/api/saha/rep-profil") {',
'''    if (method === "GET" && path === "/api/saha/gunluk-baslangic") {
      const session = await requireSahaAccess(request);
      const r = await pool.query(
        "SELECT sehir, ilce, lat, lng, kaynak, created_at FROM saha_rep_gunluk_baslangic WHERE tenant_id=$1 AND rep_id=$2 AND tarih=CURRENT_DATE",
        [session.tenantId, session.userId]);
      const b = await pool.query(
        "SELECT base_adres, base_lat, base_lng FROM saha_rep_profil WHERE tenant_id=$1 AND rep_id=$2",
        [session.tenantId, session.userId]);
      sendJson(response, 200, { bugun: r.rows[0] || null, merkez: b.rows[0] || null });
      return;
    }
    if (method === "PUT" && path === "/api/saha/gunluk-baslangic") {
      const session = await requireSahaAccess(request);
      const p = await readJson(request);
      const kaynak = ["MANUEL","GPS","OTOMATIK"].includes(p.kaynak) ? p.kaynak : "MANUEL";
      const sehir = String(p.sehir || "").trim() || null;
      if (!sehir && !(p.lat && p.lng)) { sendJson(response, 400, { error: "Şehir veya koordinat gerekli." }); return; }
      await pool.query(
        `INSERT INTO saha_rep_gunluk_baslangic (tenant_id, rep_id, tarih, sehir, ilce, lat, lng, kaynak)
         VALUES ($1,$2,CURRENT_DATE,$3,$4,$5,$6,$7)
         ON CONFLICT (rep_id, tarih) DO UPDATE
           SET sehir=$3, ilce=$4, lat=$5, lng=$6, kaynak=$7, created_at=now()`,
        [session.tenantId, session.userId, sehir, String(p.ilce || "").trim() || null,
         p.lat ?? null, p.lng ?? null, kaynak]);
      sendJson(response, 200, { ok: true });
      return;
    }
    if (method === "DELETE" && path === "/api/saha/gunluk-baslangic") {
      const session = await requireSahaAccess(request);
      await pool.query("DELETE FROM saha_rep_gunluk_baslangic WHERE tenant_id=$1 AND rep_id=$2 AND tarih=CURRENT_DATE",
        [session.tenantId, session.userId]);
      sendJson(response, 200, { ok: true });
      return;
    }
    if (method === "GET" && path === "/api/saha/rep-profil") {''',
    "gunluk-baslangic-endpoints")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
