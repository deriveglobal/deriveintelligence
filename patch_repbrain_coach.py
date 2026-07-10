# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# REPBRAIN_COACH — give the rep Asistan read access to the rep's OWN data
# (rep_ozet: visits, quotes, reminders, neglected customers) + make it a coach
# that never says "erişimim yok".
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# A) add rep_ozet to the system-prompt tool list
rep('"- rakip_fiyat: bir ebat/marka için piyasa (e-ticaret) ve saha rakip fiyat aralığını getir.\\n" +',
    '"- rakip_fiyat: bir ebat/marka için piyasa (e-ticaret) ve saha rakip fiyat aralığını getir.\\n" +\n        "- rep_ozet: SENİN KENDİ performansın ve durumun — bu haftaki/dönemdeki ziyaretler, teklifler (durum+tutar), bekleyen hatırlatmalar, uzun süredir uğramadığın (ihmal) müşteriler. Performans/hafta/gelişim/ihmal sorularında MUTLAKA bunu çağır.\\n" +',
    "sys-tool")

# B) coach framing + never-say-no-access
rep('"Bugün: " + new Date().toISOString().slice(0,10) + ". Gereksiz soru sorma; kritik eksik varsa tek soruda sor. İş bitince kısa onayla.";',
    '"Bugün: " + new Date().toISOString().slice(0,10) + ". Sen aynı zamanda bir gelişim KOÇUSUN: performans/hafta/gelişim/ihmal sorularında ÖNCE rep_ozet ile GERÇEK veriyi çek, sonra somut rakamlarla ve motive edici şekilde yorumla. ASLA \\"erişimim yok\\", \\"veri yok\\", \\"göremiyorum\\" DEME — araçlarınla temsilcinin tüm verisine ulaşırsın. Gereksiz soru sorma; kritik eksik varsa tek soruda sor. İş bitince kısa onayla.";',
    "sys-coach")

# C) add rep_ozet tool to _repTools
rep("        { name: 'rakip_fiyat', description: 'Bir ebat/marka için e-ticaret ve saha rakip fiyat aralığı.', input_schema: { type:'object', properties:{ ebat:{type:'string'}, marka:{type:'string'} }, required:['ebat'] } }\n      ];",
    "        { name: 'rakip_fiyat', description: 'Bir ebat/marka için e-ticaret ve saha rakip fiyat aralığı.', input_schema: { type:'object', properties:{ ebat:{type:'string'}, marka:{type:'string'} }, required:['ebat'] } },\n        { name: 'rep_ozet', description: 'Temsilcinin KENDI performansi/durumu: donemdeki ziyaretler, teklifler (durum+tutar), bekleyen hatirlatmalar, ihmal edilen musteriler.', input_schema: { type:'object', properties:{ gun:{type:'number', description:'kac gun geriye (varsayilan 7)'} } } }\n      ];",
    "tool-def")

# D) add rep_ozet handler in _runRepTool (after rep-specific rakip_fiyat block)
rep('''          const sRows = inp.marka ? [session.tenantId, ebat, inp.marka] : [session.tenantId, ebat];
          const sa = await pool.query("SELECT MIN(rakip_fiyat) AS min, MAX(rakip_fiyat) AS max, COUNT(*) AS n FROM saha_rakip_teklif WHERE tenant_id=$1 AND ebat=$2" + (inp.marka?" AND lower(rakip_marka)=lower($3)":""), sRows);
          return { eticaret_piyasa: et.rows[0], saha_gercek: sa.rows[0] };
        }
        return { hata: 'bilinmeyen araç: ' + nm };''',
    '''          const sRows = inp.marka ? [session.tenantId, ebat, inp.marka] : [session.tenantId, ebat];
          const sa = await pool.query("SELECT MIN(rakip_fiyat) AS min, MAX(rakip_fiyat) AS max, COUNT(*) AS n FROM saha_rakip_teklif WHERE tenant_id=$1 AND ebat=$2" + (inp.marka?" AND lower(rakip_marka)=lower($3)":""), sRows);
          return { eticaret_piyasa: et.rows[0], saha_gercek: sa.rows[0] };
        }
        if (nm === 'rep_ozet') {
          const gun = Math.min(90, Math.max(1, Number(inp.gun)||7));
          const since = "NOW() - INTERVAL '" + gun + " days'";
          const ziy = await pool.query("SELECT durum, count(*)::int n FROM saha_ziyaret WHERE tenant_id=$1 AND rep_id=$2 AND created_at>=" + since + " GROUP BY durum", [session.tenantId, session.userId]);
          const tek = await pool.query("SELECT durum, count(*)::int n, COALESCE(SUM(toplam_tutar),0)::numeric tutar FROM saha_teklif WHERE tenant_id=$1 AND rep_id=$2 AND created_at>=" + since + " GROUP BY durum", [session.tenantId, session.userId]);
          const notr = await pool.query("SELECT count(*)::int n FROM saha_rep_not WHERE tenant_id=$1 AND rep_id=$2 AND COALESCE(tamamlandi,false)=false AND hatirlatma_tarihi IS NOT NULL AND hatirlatma_tarihi <= CURRENT_DATE", [session.tenantId, session.userId]);
          const ihmal = await pool.query("SELECT m.firma, MAX(z.ziyaret_tarihi) son FROM saha_ziyaret z JOIN saha_musteri m ON m.id=z.musteri_id WHERE z.tenant_id=$1 AND z.rep_id=$2 GROUP BY m.id, m.firma HAVING MAX(z.ziyaret_tarihi) < CURRENT_DATE - INTERVAL '21 days' ORDER BY son ASC LIMIT 5", [session.tenantId, session.userId]);
          return { gun, ziyaretler: ziy.rows, teklifler: tek.rows, bekleyen_hatirlatma: notr.rows[0].n, ihmal_edilen_musteriler: ihmal.rows };
        }
        return { hata: 'bilinmeyen araç: ' + nm };''',
    "tool-handler")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
