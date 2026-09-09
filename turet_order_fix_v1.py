#!/usr/bin/env python3
# TURET_ORDER_FIX_V1 — KRITIK: erp_ingest.py entry-point sirasi bugu.
#   `if __name__ == "__main__":` blogu satir ~773'te; ama `def turet` (883), `BAGIMLILIK` (782),
#   `SQL_TURET` (790) ONDAN SONRA tanimli. Script calisinca __main__ -> yukle() -> turet() cagirir
#   ama turet HENUZ TANIMLI DEGIL -> NameError. yukle() sessizce yakalar, "ok:true" doner.
#   SONUC: turet HIC calismadi -> bi_marj_fact / bi_maliyet_ay / bi_maliyet_sku / bi_sinyal (kredi_asimi)
#   her yuklemede BAYAT kaldi. Kokpit odeme takvimi + karar kuyrugu + marj kubu donmus.
#   COZUM: __main__ blogunu dosya SONUNA tasi (tum tanimlardan sonra).
# erp_ingest.py. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

import sys
FP = sys.argv[1] if len(sys.argv) > 1 else "erp_ingest.py"
s = read(FP)
if "TURET_ORDER_FIX_V1" in s:
    print("turet-order: already present, skip"); print("DONE."); raise SystemExit

BLOCK = (
    'if __name__ == "__main__":\n'
    '    if len(sys.argv) >= 2 and sys.argv[1] == "--kuru":\n'
    '        print(json.dumps(kuru(sys.argv[2]), ensure_ascii=False, default=str, indent=2))\n'
    '    elif len(sys.argv) >= 3:\n'
    '        print(json.dumps(yukle(sys.argv[1], sys.argv[2]), ensure_ascii=False, default=str))\n'
    '    else:\n'
    '        sys.exit("kullanım: erp_ingest.py --kuru <dosya.xlsx>  |  erp_ingest.py <dosya.xlsx> <tenant_id>")\n'
)
assert s.count(BLOCK) == 1, "__main__ block anchor (count=%d)" % s.count(BLOCK)

# 1) mevcut konumdan kaldir
s = s.replace(BLOCK, "", 1)
# 2) dosya sonuna tasi (tum tanimlardan — turet/BAGIMLILIK/SQL_TURET — SONRA)
s = s.rstrip("\n") + "\n\n\n# TURET_ORDER_FIX_V1 — entry point EOF'a tasindi: yukle() cagirmadan once turet/BAGIMLILIK/SQL_TURET tanimli.\n" + BLOCK

write(FP, s)
print("turet-order: __main__ blogu dosya sonuna tasindi")
print("DONE.")
