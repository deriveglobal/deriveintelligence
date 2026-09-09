import os, random, datetime, math
from openpyxl import Workbook
random.seed(20260811)
OUT = "/tmp/anadolu_out"
os.makedirs(OUT, exist_ok=True)
TODAY = datetime.date(2026, 8, 11)
def dstr(d): return d.strftime("%Y-%m-%d")
REPS = ["Mehmet Aydin","Ayse Kaya","Emre Sahin","Zeynep Demir","Can Yilmaz","Burak Ozturk"]
CITIES = ["ISTANBUL","KOCAELI","SAKARYA","BURSA","YALOVA","DUZCE","BOLU"]
BRANDS = {"PETLAS":(0.090,"TBR"),"LASSA":(0.085,"PSR"),"MICHELIN":(0.045,"PSR"),"CONTINENTAL":(0.050,"TBR"),"SAILUN":(0.110,"OTR")}
EBATLAR_PSR = ["205/55R16","225/45R17","195/65R15","215/55R17","235/45R18"]
EBATLAR_TBR = ["315/80R22.5","295/80R22.5","385/65R22.5","13R22.5"]
EBATLAR_OTR = ["17.5R25","20.5R25"]
SKUS = []
_ci = 1000
for mk,(marj,kat) in BRANDS.items():
    ebs = EBATLAR_PSR if kat=="PSR" else (EBATLAR_TBR if kat=="TBR" else EBATLAR_OTR)
    for eb in ebs:
        _ci += 1
        base = {"PSR":3200,"TBR":12500,"OTR":26000}[kat]*random.uniform(0.8,1.25)
        SKUS.append({"kod":f"LST-{_ci}","marka":mk,"kat":kat,"ebat":eb,"liste":round(base,2),"marj":marj})
for s in SKUS:
    s["maliyet"] = round(s["liste"]*(1-s["marj"]),2)
    s["jant"] = s["ebat"].split("R")[-1] if "R" in s["ebat"] else ""
CUSTS = []
_mi = 100000
GRUPLAR = ["PERAKENDE","FILO TICARI","FILO TUKETICI","TOPTAN","KURUM","E-TICARET"]
NAMEP = ["Anadolu","Marmara","Ege","Yildiz","Guven","Oz","Aksu","Deniz","Kartal","Bereket","Sahin","Toros","Efe","Baris","Umut","Cinar","Akin","Zafer","Bolu","Sakarya"]
NAMES = ["Otomotiv","Lastik","Ticaret","Filo","Nakliyat","Oto","Rot Balans","Akaryakit","Grup","Dis Tic"]
for i in range(48):
    _mi += random.randint(3,40)
    grp = random.choice(GRUPLAR)
    CUSTS.append({"kod":f"M{_mi}","ad":f"{random.choice(NAMEP)} {random.choice(NAMES)} {random.choice(['A.S.','Ltd.','San.Tic.'])}".upper(),"grup":grp,"sehir":random.choice(CITIES),"rep":random.choice(REPS),"kanal":grp,"kredi":round(random.choice([250000,500000,750000,1000000,1500000]),2),"vergi":str(random.randint(1000000000,9999999999)),"vade":random.choice([0,30,45,60])})
def month_starts(n):
    y,m = 2024,9; out=[]
    for _ in range(n):
        out.append(datetime.date(y,m,1)); m+=1
        if m>12: m=1; y+=1
    return out
MONTHS = [d for d in month_starts(23) if d <= TODAY]
def kanon_grup(kat): return "LASTIK TUKETICI" if kat=="PSR" else "LASTIK TICARI"
def gen_satis():
    rows=[]; fno=500000; per_line=[]
    for mo in MONTHS:
        seas = 1.0 + (0.5 if mo.month in (10,11,12) else (-0.2 if mo.month in (6,7) else 0.0))
        for _ in range(int(random.uniform(70,120)*seas)):
            cust=random.choice(CUSTS); fno+=1
            ftar=datetime.date(mo.year,mo.month,random.randint(1,28))
            if ftar>TODAY: continue
            vade=ftar+datetime.timedelta(days=cust["vade"])
            for _l in range(random.randint(1,4)):
                sku=random.choice(SKUS)
                miktar=float(random.choice([2,4,4,8,10,20,40]))
                bf=round(sku["liste"]*random.uniform(0.985,1.015),2)
                st=round(miktar*bf,2)
                rows.append({"Kayit Tarihi":dstr(ftar),"Vade Tarihi":dstr(vade),"Belge Numarasi":str(fno),"Depo Adi":"MERKEZ DEPO","Sube Adi":"MERKEZ","Olusturan":cust["rep"],"Satis Calisani":cust["rep"],"Muhatap Kodu":cust["kod"],"Muhatap Adi":cust["ad"],"Satis Kanali Tanim":cust["kanal"],"Sehir Adi":cust["sehir"],"Odeme Kosulu":(f"{cust['vade']} Gun Vade" if cust["vade"] else "Pesin"),"Kalem Numarasi":sku["kod"],"Kalem Tanimi":f"{sku['marka']} {sku['ebat']}","Kalem Grubu":kanon_grup(sku["kat"]),"Kategori1":sku["kat"],"Kategori2":sku["marka"],"Kategori3":"","Ebat":sku["ebat"],"Jant Capi":sku["jant"],"Marka":sku["marka"],"Vergi No":cust["vergi"],"Vergi Dairesi":"","TC No":"","Para Birimi":"TRY","Miktar":miktar,"Indirim Sonrasi Fiyat":bf,"Satir Toplami":st})
                per_line.append({"cust":cust,"sku":sku,"ftar":ftar,"vade":vade,"miktar":miktar,"bf":bf,"st":st,"fno":str(fno)})
    return rows, per_line
SATIS_HDR = ["Kayıt Tarihi","Vade Tarihi","Belge Numarası","Depo Adı","Sube Adı","Oluşturan","Satış Çalışanı","Muhatap Kodu","Muhatap Adı","Satış Kanalı Tanım","Şehir Adı","Ödeme Koşulu","Kalem Numarası","Kalem Tanımı","Kalem Grubu","Kategori1","Kategori2","Kategori3","Ebat","Jant Çapı","Marka","Vergi No","Vergi Dairesi","TC No","Para Birimi","Miktar","İndirim Sonrası Fiyat","Satır Toplamı"]
SATIS_KEYS = ["Kayit Tarihi","Vade Tarihi","Belge Numarasi","Depo Adi","Sube Adi","Olusturan","Satis Calisani","Muhatap Kodu","Muhatap Adi","Satis Kanali Tanim","Sehir Adi","Odeme Kosulu","Kalem Numarasi","Kalem Tanimi","Kalem Grubu","Kategori1","Kategori2","Kategori3","Ebat","Jant Capi","Marka","Vergi No","Vergi Dairesi","TC No","Para Birimi","Miktar","Indirim Sonrasi Fiyat","Satir Toplami"]
def gen_tedarikci(per_line):
    rows=[]; dno=900000
    SUPP={"PETLAS":("T900","PETLAS URETIM A.S."),"LASSA":("T901","BRISA LASSA A.S."),"MICHELIN":("T902","MICHELIN TR A.S."),"CONTINENTAL":("T903","CONTINENTAL TR"),"SAILUN":("T904","SAILUN IMPORT LTD")}
    for mo in MONTHS:
        for sku in SKUS:
            if random.random()<0.55: continue
            dno+=1
            ptar=datetime.date(mo.year,mo.month,random.randint(1,26))
            if ptar>TODAY: continue
            qty=float(random.choice([50,100,150,200])); cost=sku["maliyet"]*random.uniform(0.98,1.02)
            disc=20.0; unit=round(cost/(1-disc/100.0),2); row_total=round(qty*cost,2); gross=round(row_total*1.20,2)
            tk,tad=SUPP[sku["marka"]]
            rows.append({"Posting Date":dstr(ptar),"Document Number":str(dno),"Customer/Vendor Ref. No.":f"F{dno}","Satın Alma Sipariş No":f"PO{dno}","Branch Name":"MERKEZ","Customer/Vendor Code":tk,"Customer/Vendor Name":tad,"Item No.":sku["kod"],"Item Description":f"{sku['marka']} {sku['ebat']}","Group Name":kanon_grup(sku["kat"]),"Kategori1 ad":sku["kat"],"Lastik Jant Çapı":sku["jant"],"Marka ad":sku["marka"],"Payment Terms Code":"60 Gun","Quantity":qty,"Row Total":row_total,"Gross Total":gross,"Discount % per Row":disc,"Unit Price":unit})
    HDR=["Posting Date","Document Number","Customer/Vendor Ref. No.","Satın Alma Sipariş No","Branch Name","Customer/Vendor Code","Customer/Vendor Name","Item No.","Item Description","Group Name","Kategori1 ad","Lastik Jant Çapı","Marka ad","Payment Terms Code","Quantity","Row Total","Gross Total","Discount % per Row","Unit Price"]
    return HDR, rows
def gen_alacak():
    rows=[]
    for c in CUSTS:
        bal=0.0; docs=[]
        for _ in range(random.randint(1,4)):
            ac=round(random.uniform(20000,400000),2); gun=random.choice([0,0,0,15,35,70,120]); bal+=ac; docs.append((ac,gun))
        bal=round(bal,2)
        for ac,gun in docs:
            rows.append({"Customer/Vendor Code":c["kod"],"Customer/Vendor Name":c["ad"],"Group Name":c["grup"],"Sales Employee Name":c["rep"],"Account Balance":bal,"Kredi Limiti":c["kredi"],"Açık Tutar":ac,"Vadesi Geçen Gün":float(gun),"Document Total":ac})
    HDR=["Customer/Vendor Code","Customer/Vendor Name","Group Name","Sales Employee Name","Account Balance","Kredi Limiti","Açık Tutar","Vadesi Geçen Gün","Document Total"]
    return HDR, rows
def gen_tahsilat(per_line):
    rows=[]; inv={}
    for pl in per_line:
        inv.setdefault((pl["cust"]["kod"],pl["fno"]),{"cust":pl["cust"],"ftar":pl["ftar"],"vade":pl["vade"],"tut":0.0})
        inv[(pl["cust"]["kod"],pl["fno"])]["tut"]+=pl["st"]
    for (kod,fno),v in inv.items():
        if random.random()<0.25: continue
        odeme=v["vade"]+datetime.timedelta(days=max(0,int(random.gauss(8,12))))
        if odeme>TODAY: continue
        rows.append({"Fatura Belge Numarası":fno,"Fatura Tarihi":dstr(v["ftar"]),"Fatura Vade Tarihi":dstr(v["vade"]),"Tahsilat Tarihi":dstr(odeme),"Customer/Vendor Code":kod,"Customer/Vendor Name":v["cust"]["ad"],"Sales Employee Name":v["cust"]["rep"],"Fatura Tutarı":round(v["tut"],2),"Ödenen Tutar":round(v["tut"],2),"Tahsilat türü":random.choice(["Havale","Cek","Kredi Karti"]),"Vadesi Geçen Gün":float(max(0,(odeme-v["vade"]).days)),"Tahsilat Süresi":float((odeme-v["ftar"]).days),"Group Name":v["cust"]["grup"]})
    HDR=["Fatura Belge Numarası","Fatura Tarihi","Fatura Vade Tarihi","Tahsilat Tarihi","Customer/Vendor Code","Customer/Vendor Name","Sales Employee Name","Fatura Tutarı","Ödenen Tutar","Tahsilat türü","Vadesi Geçen Gün","Tahsilat Süresi","Group Name"]
    return HDR, rows
def gen_cari():
    rows=[]
    for k,ad in [("T900","PETLAS URETIM A.S."),("T901","BRISA LASSA A.S."),("T902","MICHELIN TR A.S."),("T903","CONTINENTAL TR"),("T904","SAILUN IMPORT LTD")]:
        rows.append({"BP Code":k,"BP Name":ad,"Account Balance":round(-random.uniform(500000,4000000),2),"Bağlı Müşteri Kodu":"","Bağlı Müşteri Bakiyesi":0.0})
    for c in random.sample(CUSTS,4):
        rows.append({"BP Code":"T"+c["kod"][1:],"BP Name":c["ad"],"Account Balance":round(-random.uniform(100000,800000),2),"Bağlı Müşteri Kodu":c["kod"],"Bağlı Müşteri Bakiyesi":round(random.uniform(100000,900000),2)})
    HDR=["BP Code","BP Name","Account Balance","Bağlı Müşteri Kodu","Bağlı Müşteri Bakiyesi"]
    return HDR, rows
def gen_stok():
    rows=[]
    for sku in SKUS:
        adet=float(random.choice([0,10,25,60,120,240])); kul=round(adet*random.uniform(0.85,1.0),2)
        rows.append({"Warehouse Name":"MERKEZ DEPO","Item No.":sku["kod"],"Item Description":f"{sku['marka']} {sku['ebat']}","Group Name":kanon_grup(sku["kat"]),"Marka ad":sku["marka"],"Kategori1 ad":sku["kat"],"Kategori2 ad":"","Kategori3 ad":"","In Stock":adet,"Taahhüt Edilen":0.0,"Kullanılabilir Miktar":kul,"List Price":sku["liste"],"Minimum Inventory Level":10.0,"Maximum Inventory Level":300.0})
    HDR=["Warehouse Name","Item No.","Item Description","Group Name","Marka ad","Kategori1 ad","Kategori2 ad","Kategori3 ad","In Stock","Taahhüt Edilen","Kullanılabilir Miktar","List Price","Minimum Inventory Level","Maximum Inventory Level"]
    return HDR, rows
def dump(path,hdr,rows,keys=None):
    wb=Workbook(); ws=wb.active; ws.append(hdr); keys=keys or hdr
    for r in rows: ws.append([r.get(k,"") for k in keys])
    wb.save(path)
def main():
    satis, per_line = gen_satis()
    dump(f"{OUT}/01_satis_faturalari.xlsx", SATIS_HDR, satis, SATIS_KEYS)
    h,r=gen_tedarikci(per_line); dump(f"{OUT}/02_tedarikci_faturalari.xlsx",h,r)
    h,r=gen_alacak();            dump(f"{OUT}/03_alacak_yaslandirma.xlsx",h,r)
    h,r=gen_tahsilat(per_line);  dump(f"{OUT}/04_tahsilat.xlsx",h,r)
    h,r=gen_cari();              dump(f"{OUT}/05_cari_bakiye.xlsx",h,r)
    h,r=gen_stok();              dump(f"{OUT}/06_stok_anlik.xlsx",h,r)
    c=sum(p["st"] for p in per_line); m=sum(p["miktar"]*p["sku"]["maliyet"] for p in per_line)
    print(f"satis={len(satis)} ciro={c/1e6:.0f}M marj=%{100*(c-m)/c:.1f} musteri={len(CUSTS)} sku={len(SKUS)} ay={len(MONTHS)}")
main()
