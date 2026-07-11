# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# SEARCH — Eftal: "add a search box to Müşteri and Ziyaret".
#   Müşteri : the box EXISTS but is rendered *below* the big amber Kontrol panel,
#             so on a phone it sits under the fold. Move it to the top, and widen
#             the match from firma-only to firma/il/ilçe/ERP kodu/vergi no.
#   Ziyaret : no search at all. Visits are already in memory -> instant client filter.
#   Bonus   : the client asks for limit/offset and expects hasMore, but the server
#             hardcoded LIMIT 200 and returned neither -> "load more" never appeared
#             and customers past 200 were unreachable.
import sys
which = sys.argv[1]
fn = sys.argv[2]
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

if which == "server":
    rep(
'''      if (q)     { params.push(`%${q}%`);   sql += ` AND m.firma ILIKE $${params.length}`; }
      sql += ` ORDER BY sz.son_ziyaret DESC NULLS LAST, m.firma ASC LIMIT 200`;
      const result = await query(sql, params);
      sendJson(response, 200, { musteriler: result.rows });
      return;''',
'''      if (q) {
        params.push(`%${q}%`);
        const qi = params.length;
        sql += ` AND (m.firma ILIKE $${qi} OR m.il ILIKE $${qi} OR m.ilce ILIKE $${qi}
                      OR m.musteri_kodu ILIKE $${qi} OR m.vergi_no ILIKE $${qi})`;
      }
      // honour limit/offset (the client always sent them; we were ignoring both)
      let _lim = parseInt(url.searchParams.get("limit") || "50", 10);
      if (!Number.isFinite(_lim) || _lim < 1) _lim = 50;
      if (_lim > 200) _lim = 200;
      let _off = parseInt(url.searchParams.get("offset") || "0", 10);
      if (!Number.isFinite(_off) || _off < 0) _off = 0;
      params.push(_lim + 1); const _li = params.length;   // +1 row = "is there more?"
      params.push(_off);     const _oi = params.length;
      sql += ` ORDER BY sz.son_ziyaret DESC NULLS LAST, m.firma ASC LIMIT $${_li} OFFSET $${_oi}`;
      const result = await query(sql, params);
      const hasMore = result.rows.length > _lim;
      sendJson(response, 200, { musteriler: hasMore ? result.rows.slice(0, _lim) : result.rows, hasMore });
      return;''',
        "musteri-search-and-paging")

elif which == "front":
    # 1) Müşteri: search box ABOVE the panels, and say what it searches
    rep(
'''    <button class="saha-cta" id="yeni-musteri">＋ Müşteri</button>
    <div id="kontrol-paneli"></div>
    ${S.role !== "rep" ? `<div id="bakim-paneli"></div>` : ""}
    <input class="giris" id="mus-filtre" placeholder="Müşteri ara…" autocomplete="off">
    <div id="mus-liste"><div class="saha-load">Yükleniyor…</div></div>`;''',
'''    <button class="saha-cta" id="yeni-musteri">＋ Müşteri</button>
    <input class="giris" id="mus-filtre" placeholder="🔍 Ara — firma, şehir, ilçe, ERP kodu, vergi no" autocomplete="off">
    <div id="kontrol-paneli"></div>
    ${S.role !== "rep" ? `<div id="bakim-paneli"></div>` : ""}
    <div id="mus-liste"><div class="saha-load">Yükleniyor…</div></div>`;''',
        "musteri-search-to-top")

    # 2) Ziyaret: filter the in-memory list on text too
    rep(
'''    function renderListe(repFiltre) {
      let liste = bugunFiltre
        ? ziyaretler.filter(z => z.ziyaret_tarihi && String(z.ziyaret_tarihi).slice(0, 10) === bugunISO)
        : ziyaretler;
      if (repFiltre) liste = liste.filter(z => (z.rep_full_name || z.rep_adi || "") === repFiltre);

      const listEl = document.getElementById("ziyaret-liste");
      if (listEl) listEl.innerHTML = liste.length
        ? liste.map(zKart).join("")
        : `<div class="saha-bos">${repFiltre ? "Bu temsilciye ait ziyaret yok." : bugunFiltre ? "Bugün tamamlanan ziyaret yok." : "Henüz ziyaret yok. İlk ziyaretini kaydet!"}</div>`;''',
'''    function renderListe(repFiltre) {
      let liste = bugunFiltre
        ? ziyaretler.filter(z => z.ziyaret_tarihi && String(z.ziyaret_tarihi).slice(0, 10) === bugunISO)
        : ziyaretler;
      if (repFiltre) liste = liste.filter(z => (z.rep_full_name || z.rep_adi || "") === repFiltre);

      const ara = (document.getElementById("ziy-filtre")?.value || "").trim().toLocaleLowerCase("tr");
      if (ara) {
        liste = liste.filter(z =>
          [z.firma, z.il, z.ilce, z.lokasyon_adi, z.notlar, z.rep_full_name, z.rep_adi]
            .some(v => String(v || "").toLocaleLowerCase("tr").includes(ara)));
      }

      const listEl = document.getElementById("ziyaret-liste");
      if (listEl) listEl.innerHTML = liste.length
        ? liste.map(zKart).join("")
        : `<div class="saha-bos">${ara ? "Aramayla eşleşen ziyaret yok." : repFiltre ? "Bu temsilciye ait ziyaret yok." : bugunFiltre ? "Bugün tamamlanan ziyaret yok." : "Henüz ziyaret yok. İlk ziyaretini kaydet!"}</div>`;''',
        "ziyaret-text-filter")

    # 3) Ziyaret: render the box + wire it
    rep(
'''    main().innerHTML = `
      <button class="saha-cta" id="yeni-ziyaret">＋ Yeni Ziyaret</button>
      ${filtreBandi}
      ${repSecEl}
      <div id="ziyaret-liste"></div>`;

    renderListe("");
    main().querySelector("#yeni-ziyaret").addEventListener("click", () => musteriSecModal(z => ziyaretFormModal(z, "kaydet")));
    main().querySelector("#filtre-kaldir")?.addEventListener("click", () => loadView("ziyaretler"));
    main().querySelector("#rep-filtre")?.addEventListener("change", function() { renderListe(this.value); });''',
'''    main().innerHTML = `
      <button class="saha-cta" id="yeni-ziyaret">＋ Yeni Ziyaret</button>
      <input class="giris" id="ziy-filtre" placeholder="🔍 Ara — firma, şehir, not…" autocomplete="off">
      ${filtreBandi}
      ${repSecEl}
      <div id="ziyaret-liste"></div>`;

    renderListe("");
    main().querySelector("#yeni-ziyaret").addEventListener("click", () => musteriSecModal(z => ziyaretFormModal(z, "kaydet")));
    main().querySelector("#filtre-kaldir")?.addEventListener("click", () => loadView("ziyaretler"));
    main().querySelector("#rep-filtre")?.addEventListener("change", function() { renderListe(this.value); });
    let _zt = null;
    main().querySelector("#ziy-filtre")?.addEventListener("input", () => {
      clearTimeout(_zt);
      _zt = setTimeout(() => renderListe(main().querySelector("#rep-filtre")?.value || ""), 200);
    });''',
        "ziyaret-search-box")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
