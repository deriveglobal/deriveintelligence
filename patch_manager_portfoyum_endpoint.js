/* =====================================================================
   MANAGER_PORTFOYUM_V1 — Yönetici Portföyüm (book state + ekip varyans)
   ---------------------------------------------------------------------
   NEREYE: server_container.mjs · saha endpoint bloğuna, /api/saha/portfoyum
           endpoint'inin BİTTİĞİ yerden (return; } ~ satır 31879) HEMEN SONRA yapıştır.
   İLKE:  Salt-okunur. requireSahaAccess(...,["manager","admin"]). _sahaScopeSql KULLANMAZ
          (yönetici tüm tenant'ı görür). Canlıya YAZMAZ.

   ⭐ TEK DOĞRU KAYNAK — rep ekranıyla BİREBİR eşleşme garantisi:
      Per-rep sayılar /api/saha/portfoyum ile AYNI tanım:
        aktif=true + COALESCE(musteri_kodu,'')<>'' + DISTINCT musteri_kodu + segment=saha_satis_skor.
      Böylece bir rep'in ekranındaki "uyuyan" = manager ızgarasındaki "uyuyan".
      Kodsuz (musteri_kodu boş) = ayrı "eslesmeyen" sayısı (rep ekranında da ayrı). Skorsuz = kodlu ama skor yok.
      NOT: bir müşteri 2 rep'e atanmışsa (mükerrer) her iki rep'te de sayılır (rep ekranı da öyle);
           book toplamı DISTINCT olduğundan reps toplamından küçük olabilir — beklenen.
   DOĞRULANDI (2026-08-09 canlı): kovalar ok/seyrek/due/dormant/slip; kodlu-skorsuz+kodsuz~741; kapsam 90 gün.
   ===================================================================== */

// (1) VERİ — GET /api/saha/manager-portfoyum?donem=buay|3ay|6ay|12ay|ytd
if (method === "GET" && path === "/api/saha/manager-portfoyum") {
  const session = await requireSahaAccess(request, ["manager", "admin"]);
  const T = session.tenantId;
  let _u; try { _u = new URL(request.url, "http://x"); } catch (e) { _u = null; }
  const donem = (_u && _u.searchParams.get("donem")) || "12ay";
  const DSTART = donem === "buay" ? "date_trunc('month',CURRENT_DATE)"
              : donem === "3ay"  ? "CURRENT_DATE - INTERVAL '3 months'"
              : donem === "6ay"  ? "CURRENT_DATE - INTERVAL '6 months'"
              : donem === "ytd"  ? "date_trunc('year',CURRENT_DATE)"
              :                    "CURRENT_DATE - INTERVAL '12 months'";

  // A) BOOK STATE — DISTINCT kodlu müşteri üzerinden canlılık dağılımı (rep ekranıyla aynı taban)
  const bookR = await query(
    `SELECT COALESCE(sk.segment,'skorsuz') AS kova, count(*) AS n
       FROM (SELECT DISTINCT m.musteri_kodu, m.tenant_id
               FROM saha_musteri m
              WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')<>'') mk
       LEFT JOIN saha_satis_skor sk ON sk.tenant_id=mk.tenant_id AND sk.musteri_kodu=mk.musteri_kodu
      GROUP BY 1`, [T]);
  const book = { ok: 0, seyrek: 0, due: 0, dormant: 0, slip: 0, skorsuz: 0, eslesmeyen: 0 };
  for (const r of bookR.rows) { book[r.kova] = Number(r.n) || 0; }
  // kodsuz (eşleşmeyen) — rep ekranında da ayrı tutulur
  const eslR = await query(
    `SELECT count(*) AS n FROM saha_musteri
      WHERE tenant_id=$1 AND aktif=true AND COALESCE(musteri_kodu,'')=''`, [T]);
  book.eslesmeyen = Number(eslR.rows[0] && eslR.rows[0].n) || 0;

  // B) EKİP VARYANS — per-rep, DISTINCT kodlu müşteri (rep ekranı tanımı) + davranış + ciro(dönem)
  const repR = await query(
    `WITH base AS (
        SELECT m.sorumlu_rep, m.musteri_kodu,
               max(sk.segment)          AS segment,
               bool_or(zv.mid IS NOT NULL) AS visited90
          FROM saha_musteri m
          LEFT JOIN saha_satis_skor sk ON sk.tenant_id=m.tenant_id AND sk.musteri_kodu=m.musteri_kodu
          LEFT JOIN (SELECT DISTINCT musteri_id AS mid FROM saha_ziyaret
                       WHERE tenant_id=$1 AND ziyaret_tarihi >= CURRENT_DATE - INTERVAL '90 days') zv
                 ON zv.mid = m.id
         WHERE m.tenant_id=$1 AND m.aktif=true AND m.sorumlu_rep IS NOT NULL
           AND COALESCE(m.musteri_kodu,'')<>''
         GROUP BY m.sorumlu_rep, m.musteri_kodu
     ),
     ciro AS (
        SELECT d.sorumlu_rep, sum(f.satir_tutar) AS c
          FROM (SELECT DISTINCT sorumlu_rep, musteri_kodu, tenant_id
                  FROM saha_musteri
                 WHERE tenant_id=$1 AND aktif=true AND sorumlu_rep IS NOT NULL
                   AND COALESCE(musteri_kodu,'')<>'') d
          JOIN bi_satis_faturalari f
            ON f.tenant_id::text=d.tenant_id::text AND f.musteri_kodu=d.musteri_kodu
         WHERE f.satir_tutar>0 AND f.fatura_tarihi >= ${DSTART}
           AND f.grup_adi NOT IN ('PRİM HAKEDİŞLERİ','HAMMADDE','DURAN VARLIKLAR','ALINAN HIZMETLER')
         GROUP BY d.sorumlu_rep
     )
     SELECT COALESCE(u.full_name,u.name,'—') AS rep, base.sorumlu_rep AS user_id,
            count(*)                                        AS portfoy,
            count(*) FILTER (WHERE base.segment='slip')     AS kayiyor,
            count(*) FILTER (WHERE base.segment='dormant')  AS uyuyan,
            count(*) FILTER (WHERE base.segment='due')      AS siparis_vakti,
            count(*) FILTER (WHERE base.segment='seyrek')   AS seyrek,
            count(*) FILTER (WHERE base.segment='ok')       AS duzenli,
            count(*) FILTER (WHERE base.segment IS NULL)    AS skorsuz,
            round(100.0*count(*) FILTER (WHERE base.visited90)/NULLIF(count(*),0)) AS kapsam90,
            round(100.0*count(*) FILTER (WHERE base.segment IN ('slip','dormant') AND base.visited90)
                  /NULLIF(count(*) FILTER (WHERE base.segment IN ('slip','dormant')),0))  AS kayan_ziyaret90,
            round(COALESCE(max(ciro.c),0))                  AS ciro_donem
       FROM base
       LEFT JOIN ciro    ON ciro.sorumlu_rep=base.sorumlu_rep
       LEFT JOIN users u ON u.id=base.sorumlu_rep
      GROUP BY u.full_name, u.name, base.sorumlu_rep
      ORDER BY portfoy DESC`, [T]);

  const reps = repR.rows
    .map(r => ({
      rep: r.rep, user_id: r.user_id, portfoy: +r.portfoy || 0,
      kayiyor: +r.kayiyor || 0, uyuyan: +r.uyuyan || 0, siparis_vakti: +r.siparis_vakti || 0,
      seyrek: +r.seyrek || 0, duzenli: +r.duzenli || 0, skorsuz: +r.skorsuz || 0,
      kapsam90: r.kapsam90 == null ? null : +r.kapsam90,
      kayan_ziyaret90: r.kayan_ziyaret90 == null ? null : +r.kayan_ziyaret90,
      ciro_donem: +r.ciro_donem || 0
    }))
    .filter(r => r.portfoy >= 2);  // sentinel/sistem hesapları ele (KRB Yönetim Paneli vb.)

  const ozet = {
    saha_rep_say: reps.length,
    portfoy_musteri: reps.reduce((a, c) => a + c.portfoy, 0),
    skorlu: book.ok + book.seyrek + book.due + book.dormant + book.slip,
    skorsuz: book.skorsuz,
    eslesmeyen: book.eslesmeyen,
    ciro_donem: reps.reduce((a, c) => a + c.ciro_donem, 0)
  };
  sendJson(response, 200, { donem, book, reps, ozet });
  return;
}

// (2) EKRAN — GET /api/saha/manager-portfoyum/ekran  → shell HTML (finans.html deseni)
if (method === "GET" && path === "/api/saha/manager-portfoyum/ekran") {
  if (response.headersSent) return;
  try {
    await requireSahaAccess(request, ["manager", "admin"]);
    const _h = await readFile("/app/shells/manager_portfoyum.html", "utf8");
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(_h);
  } catch (e) {
    if (!response.headersSent) sendJson(response, 403, { error: "yetki yok / ekran bulunamadi" });
  }
  return;
}
