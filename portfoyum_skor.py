# -*- coding: utf-8 -*-
"""
portfoyum_skor.py — rep "Portföyüm" segment motoru (BG/NBD, gecelik)
--------------------------------------------------------------------
Ne yapar: bi_satis_faturalari'ndan her müşterinin sipariş GÜNLERİNİ çıkarır,
tenant başına BG/NBD ("buy-till-you-die") modeli fit eder, her müşteriye
p_alive (aktif olma olasılığı) + beklenen sipariş hızı hesaplar, ve segmenti
MÜŞTERİNİN KENDİ KADANSINA göre atar (sabit gün eşiği YOK) → saha_satis_skor.

Segment kuralı (model + kendi hikâyesi):
  x = tekrar sipariş sayısı (ayrı gün) - 1 ;  ratio = son_gun / medyan_gun (kendi aralığı)
  - x < 2  ya da medyan yok            → seyrek  (ritim kurulamıyor)
  - p_alive < 0.30 (model: kaybedildi) → son_gun>365 ? dormant : slip
  - ratio <= 1.5 (kendi aralığında)    → ok       (düzenli)
  - aksi (aralığını geçti, hâlâ canlı) → due      (sipariş vakti)
  (0.30 / 1.5 = model olasılığı ve kendi-kadans oranı üzerinde; ham gün eşiği değil.
   365 = bir mevsim yılı, "kayıyor" vs "uykuda" ayrımı için tek zorunlu zaman ölçüsü.)

I/O: DB'ye `docker exec … psql` ile bağlanır (host cron; devir §2 deseni).
Bağımlılık (host): python3, pip install pandas numpy lifetimes
Çalıştırma:  python3 portfoyum_skor.py            (uygula)
             python3 portfoyum_skor.py --dry      (yaz-ma, dağılımı yazdır)
Cron öneri:  30 3 * * *  cd /opt/krb-assessment && python3 portfoyum_skor.py >> /var/log/portfoyum_skor.log 2>&1
"""
import os, sys, csv, io, subprocess, warnings, statistics
from datetime import date
warnings.filterwarnings("ignore")
import numpy as np
import pandas as pd
from lifetimes import BetaGeoFitter

PG_CONTAINER = os.environ.get("PG_CONTAINER", "krb-assessment-postgres")
PG_USER      = os.environ.get("PG_USER", "assessment_app")
PG_DB        = os.environ.get("PG_DB", "assessment_platform")
DRY          = "--dry" in sys.argv
MIN_FIT      = 8       # bir tenant'ta model için gereken min. tekrar-müşteri
P_CHURN      = 0.30    # model olasılığı: bunun altı "muhtemelen kaybedildi"
RATIO_OK     = 1.5     # son_gun kendi medyanının bu katına kadar → düzenli
YIL_GUN      = 365     # dormant vs slip (tek zorunlu zaman ölçüsü)

def psql_read(sql):
    cmd = ["docker","exec",PG_CONTAINER,"psql","-U",PG_USER,"-d",PG_DB,
           "-v","ON_ERROR_STOP=1","-tAc", "COPY (%s) TO STDOUT WITH (FORMAT csv)" % sql]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr); raise SystemExit("psql read hata")
    return out.stdout

def psql_exec(sql_text):
    cmd = ["docker","exec","-i",PG_CONTAINER,"psql","-U",PG_USER,"-d",PG_DB,
           "-v","ON_ERROR_STOP=1","-q"]
    out = subprocess.run(cmd, input=sql_text, capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr); raise SystemExit("psql write hata")
    return out.stdout

def classify(x, p, son_gun, medyan_gun):
    if x < 2 or not medyan_gun or medyan_gun <= 0 or p is None:
        return "seyrek"
    ratio = son_gun / medyan_gun
    if p < P_CHURN:
        return "dormant" if son_gun > YIL_GUN else "slip"
    if ratio <= RATIO_OK:
        return "ok"
    return "due"

def q(s):  # tek tırnak kaçışı
    return "'" + str(s).replace("'", "''") + "'"

def main():
    raw = psql_read("SELECT tenant_id::text, musteri_kodu, fatura_tarihi::date "
                    "FROM bi_satis_faturalari "
                    "WHERE satir_tutar>0 AND COALESCE(musteri_kodu,'')<>'' AND fatura_tarihi IS NOT NULL")
    df = pd.read_csv(io.StringIO(raw), header=None, names=["tenant","kod","tarih"],
                     dtype={"tenant":str,"kod":str}, parse_dates=["tarih"])
    if df.empty:
        print("veri yok"); return
    obs_end = df["tarih"].max().date()
    print("gözlem sonu:", obs_end, "| satır:", len(df), "| tenant:", df['tenant'].nunique())

    rows = []          # (tenant,kod,segment,p,exp30,siparis,son_gun,medyan)
    dist = {}
    for tenant, g in df.groupby("tenant"):
        feats = []
        for kod, gg in g.groupby("kod"):
            days = sorted(set(d.date() for d in gg["tarih"]))
            n = len(days)
            if n == 0: continue
            first, last = days[0], days[-1]
            son_gun = (obs_end - last).days
            x = n - 1
            t_x = (last - first).days
            T = max((obs_end - first).days, 1)
            gaps = [(days[i+1]-days[i]).days for i in range(len(days)-1)]
            medyan = int(round(statistics.median(gaps))) if gaps else None
            feats.append(dict(kod=kod, n=n, x=x, t_x=t_x, T=T, son_gun=son_gun, medyan=medyan))
        fit_df = pd.DataFrame([f for f in feats if f["x"] >= 1])
        bgf = None
        if len(fit_df) >= MIN_FIT:
            try:
                bgf = BetaGeoFitter(penalizer_coef=0.01)
                bgf.fit(fit_df["x"], fit_df["t_x"], fit_df["T"])
            except Exception as e:
                sys.stderr.write("fit hata (%s): %s\n" % (tenant[:8], e)); bgf = None
        for f in feats:
            p = exp30 = None
            if bgf is not None and f["x"] >= 2:
                try:
                    p = float(np.ravel(bgf.conditional_probability_alive(f["x"], f["t_x"], f["T"]))[0])
                    exp30 = float(bgf.conditional_expected_number_of_purchases_up_to_time(30, f["x"], f["t_x"], f["T"]))
                except Exception:
                    p = exp30 = None
            seg = classify(f["x"], p, f["son_gun"], f["medyan"])
            dist[seg] = dist.get(seg, 0) + 1
            rows.append((tenant, f["kod"], seg,
                         None if p is None else round(p, 4),
                         None if exp30 is None else round(exp30, 4),
                         f["n"], f["son_gun"], f["medyan"]))

    print("segment dağılımı:", dict(sorted(dist.items(), key=lambda x:-x[1])), "| müşteri:", len(rows))
    if DRY:
        print("--dry: yazılmadı."); return

    # upsert (parça parça)
    def val(r):
        t,k,seg,p,e,sip,sg,med = r
        f = lambda v: "NULL" if v is None else str(v)
        return "(%s,%s,%s,%s,%s,%s,%s,%s,now())" % (q(t), q(k), q(seg), f(p), f(e), f(sip), f(sg), f(med) if med is not None else "NULL")
    COLS = "tenant_id,musteri_kodu,segment,p_alive,exp30,siparis,son_gun,medyan_gun,hesaplandi_at"
    UPD  = ("segment=EXCLUDED.segment,p_alive=EXCLUDED.p_alive,exp30=EXCLUDED.exp30,"
            "siparis=EXCLUDED.siparis,son_gun=EXCLUDED.son_gun,medyan_gun=EXCLUDED.medyan_gun,hesaplandi_at=now()")
    CH = 800
    for i in range(0, len(rows), CH):
        chunk = rows[i:i+CH]
        sql = ("INSERT INTO saha_satis_skor (%s) VALUES %s ON CONFLICT (tenant_id,musteri_kodu) DO UPDATE SET %s;"
               % (COLS, ",".join(val(r) for r in chunk), UPD))
        psql_exec("BEGIN;" + sql + "COMMIT;")
    print("yazıldı: %d satır → saha_satis_skor" % len(rows))

if __name__ == "__main__":
    main()
