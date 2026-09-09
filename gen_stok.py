import os, random, datetime
from openpyxl import Workbook
OUT="/tmp/anadolu_out"; os.makedirs(OUT,exist_ok=True)
TODAY=datetime.date(2026,8,11)
random.seed(20260811)
BRANDS={"PETLAS":(0.090,"TBR"),"LASSA":(0.085,"PSR"),"MICHELIN":(0.045,"PSR"),"CONTINENTAL":(0.050,"TBR"),"SAILUN":(0.110,"OTR")}
EP=["205/55R16","225/45R17","195/65R15","215/55R17","235/45R18"]
ET=["315/80R22.5","295/80R22.5","385/65R22.5","13R22.5"]; EO=["17.5R25","20.5R25"]
SKUS=[]; _ci=1000
for mk,(marj,kat) in BRANDS.items():
    ebs=EP if kat=="PSR" else (ET if kat=="TBR" else EO)
    for eb in ebs:
        _ci+=1
        base={"PSR":3200,"TBR":12500,"OTR":26000}[kat]*random.uniform(0.8,1.25)
        SKUS.append({"kod":f"LST-{_ci}","marka":mk,"kat":kat,"ebat":eb,"maliyet":round(round(base,2)*(1-marj),2)})
def kg(kat): return "LASTIK TUKETICI" if kat=="PSR" else "LASTIK TICARI"
def months(n):
    y,mo=2024,9; out=[]
    for _ in range(n):
        out.append(datetime.date(y,mo,1)); mo+=1
        if mo>12: mo=1;y+=1
    return out
MONTHS=[d for d in months(23) if d<=TODAY]
HDR=["Belge Tarihi","Belge Türü","Belge No","Muhatap Kodu","Muhatap Tanımı","Sales Employee Name","Warehouse Name","Kalem Kodu","Group Name","Kategori1 ad","Marka ad","Kalem Tanımı","Price","Giriş Miktarı","Giriş Fiyatı","Çıkış Miktarı","Çıkış Fiyatı","Stock Balance","Remarks"]
rows=[]; bno=700000
for mo in MONTHS:
    bt=min(datetime.date(mo.year,mo.month,15),TODAY).strftime("%Y-%m-%d")
    for sku in SKUS:
        bno+=1; cikis=100.0; ct=round(cikis*sku["maliyet"],2)
        rows.append({"Belge Tarihi":bt,"Belge Türü":"Müşteri Faturası","Belge No":str(bno),"Muhatap Kodu":"","Muhatap Tanımı":"","Sales Employee Name":"","Warehouse Name":"MERKEZ DEPO","Kalem Kodu":sku["kod"],"Group Name":kg(sku["kat"]),"Kategori1 ad":sku["kat"],"Marka ad":sku["marka"],"Kalem Tanımı":f"{sku['marka']} {sku['ebat']}","Price":sku["maliyet"],"Giriş Miktarı":0.0,"Giriş Fiyatı":0.0,"Çıkış Miktarı":cikis,"Çıkış Fiyatı":ct,"Stock Balance":0.0,"Remarks":""})
wb=Workbook(); ws=wb.active; ws.append(HDR)
for r in rows: ws.append([r.get(k,"") for k in HDR])
wb.save(f"{OUT}/07_stok_hareket.xlsx")
print("stok_hareket satir:",len(rows))
