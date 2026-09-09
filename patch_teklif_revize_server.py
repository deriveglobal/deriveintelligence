#!/usr/bin/env python3
# TEKLIF_REVIZE_V1 — "Yeni surum / Rev." : verilen teklif revize edilemiyor sikayeti (Huseyin Bilgi).
#   Orijinal teklif DEGISMEZ. Kalemleriyle birlikte yeni bir TASLAK kopya acilir, orijinale bagli
#   (kok_teklif_id + revizyon_no). Revize edilebilir durumlar: ONAY_BEKLIYOR, ONAYLANDI, SUNULDU, KAYBEDILDI.
#   Idempotent (marker: TEKLIF_REVIZE_V1). node --check + .bak deploy scriptte korur.
import sys, re

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "TEKLIF_REVIZE_V1"

# ── 1) Sema: revize baglanti kolonlari (idempotent ALTER) ──
if "kok_teklif_id" not in src:
    ddl_anchor = "      ALTER TABLE saha_teklif ADD COLUMN IF NOT EXISTS kalem_kodu text;"
    if ddl_anchor not in src:
        print("HATA: DDL anchor (kalem_kodu ALTER) bulunamadi"); sys.exit(1)
    ddl_add = (ddl_anchor
        + "\n      ALTER TABLE saha_teklif ADD COLUMN IF NOT EXISTS kok_teklif_id uuid;  -- " + MARK
        + "\n      ALTER TABLE saha_teklif ADD COLUMN IF NOT EXISTS revizyon_no integer NOT NULL DEFAULT 1;  -- " + MARK
        + "\n      CREATE INDEX IF NOT EXISTS idx_saha_teklif_kok ON saha_teklif (tenant_id, kok_teklif_id);  -- " + MARK)
    src = src.replace(ddl_anchor, ddl_add, 1)
    print("[+] DDL: kok_teklif_id / revizyon_no eklendi")
else:
    print("[=] DDL zaten mevcut")

# ── 2) PUT handler: 'revize' action branch ──
if ("p.action === \"revize\"" not in src):
    # default duzenleme branch'inden ONCE ekle
    anchor = ("      } else {\n"
              "        // ── Düzenleme: sadece TASLAK teklifler düzenlenebilir ──")
    if anchor not in src:
        print("HATA: PUT default-edit anchor bulunamadi"); sys.exit(1)
    revize = r'''      } else if (p.action === "revize") {  // ''' + MARK + r'''
        // Yeni sürüm: orijinal DEĞIŞMEZ; kalemleriyle birlikte yeni TASLAK kopya açılır (bağlı).
        const REVIZE_OK = ["ONAY_BEKLIYOR", "ONAYLANDI", "SUNULDU", "KAYBEDILDI"];
        if (!REVIZE_OK.includes(eski.durum)) {
          sendJson(response, 400, { error: `"${eski.durum}" durumundaki teklif revize edilemez. (Revize yalnızca onay bekleyen, onaylanan, sunulan veya kaybedilen tekliflerde.)` }); return;
        }
        const _kok = eski.kok_teklif_id || eski.id;
        const _revRes = await query(
          `SELECT COALESCE(MAX(revizyon_no), 1) + 1 AS next FROM saha_teklif WHERE tenant_id = $1 AND (id = $2 OR kok_teklif_id = $2)`,
          [session.tenantId, _kok]);
        const _revNo = Number(_revRes.rows[0].next) || 2;
        // Başlık: jsonb ile birebir kopya; yalnız durum/sahip/sonuç alanları sıfırlanır.
        const _yeni = await query(`
          INSERT INTO saha_teklif
          SELECT (jsonb_populate_record(NULL::saha_teklif,
            to_jsonb(t)
            || jsonb_build_object(
                 'id', gen_random_uuid(),
                 'durum', 'TASLAK',
                 'created_by', $3::uuid,
                 'created_at', now(),
                 'updated_at', now(),
                 'ziyaret_id', NULL,
                 'iskonto_talep_id', NULL,
                 'sonuc_tarihi', NULL,
                 'kayip_nedeni', NULL,
                 'rakip_marka', NULL,
                 'rakip_model', NULL,
                 'rakip_fiyat', NULL,
                 'onay_seviyesi', NULL,
                 'kok_teklif_id', $4::uuid,
                 'revizyon_no', $5::int
               )
          )).*
          FROM saha_teklif t
          WHERE t.tenant_id = $1 AND t.id = $2
          RETURNING *
        `, [session.tenantId, m[1], session.userId, _kok, _revNo]);
        const _yeniId = _yeni.rows[0].id;
        // Kalemleri kopyala (onay alanları sıfırlanır)
        await query(`
          INSERT INTO saha_teklif_kalem
          SELECT (jsonb_populate_record(NULL::saha_teklif_kalem,
            to_jsonb(k)
            || jsonb_build_object(
                 'id', gen_random_uuid(),
                 'teklif_id', $2::uuid,
                 'onay_durumu', 'BEKLIYOR',
                 'onaylayan_iskonto_pct', NULL,
                 'onaylayan_id', NULL,
                 'onay_tarihi', NULL,
                 'onay_notu', NULL,
                 'created_at', now()
               )
          )).*
          FROM saha_teklif_kalem k
          WHERE k.teklif_id = $1
        `, [m[1], _yeniId]);
        await query(`INSERT INTO saha_teklif_log (teklif_id,alan,eski_deger,yeni_deger,degistiren_kullanici) VALUES ($1,$2,$3,$4,$5)`,
          [_yeniId, 'Revize (kaynak)', `${eski.durum} · ${String(m[1]).slice(-6)}`, `Rev.${_revNo} yeni taslak`, session.userId]);
        await query(`INSERT INTO saha_teklif_log (teklif_id,alan,eski_deger,yeni_deger,degistiren_kullanici) VALUES ($1,$2,$3,$4,$5)`,
          [m[1], 'Revize edildi', eski.durum, `Rev.${_revNo} taslağı oluşturuldu (${String(_yeniId).slice(-6)})`, session.userId]);
        sendJson(response, 200, { teklif: _yeni.rows[0], revizyon_no: _revNo, kaynak_id: m[1] });
        return;
'''
    src = src.replace(anchor, revize + anchor, 1)
    print("[+] PUT: revize action eklendi")
else:
    print("[=] revize action zaten mevcut")

if src == orig:
    print("[=] Degisiklik yok (idempotent)")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
