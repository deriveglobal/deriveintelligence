#!/usr/bin/env python3
# fix_ebat_concat.py
# Ebat search'i CONCAT(genislik,'/',profil,'R',cap) ile genişletir.
# Böylece Akakçe'nin "205/55 R16" formatı da arama sonuçlarına girer.
# Sadece tek satır değişir — güvenli, $ işareti içermiyor.

SRC = '/opt/krb-assessment/server.mjs'

BAD  = 'where.push("ebat  ILIKE $" + vals.length);'
GOOD = 'where.push("(ebat ILIKE $" + vals.length + " OR CONCAT(genislik,\'/\',profil,\'R\',cap) ILIKE $" + vals.length + ")"); // EBAT_CONCAT_V1'

with open(SRC, 'r', encoding='utf-8') as f:
    src = f.read()

if GOOD.split('//')[0].strip() in src or 'EBAT_CONCAT_V1' in src:
    print('-- Zaten uygulanmis, atlandi')
    exit(0)

if BAD not in src:
    print('x BAD string bulunamadi — kontrol et:')
    idx = src.find('if (ebat)')
    print(repr(src[idx:idx+200]))
    exit(1)

src = src.replace(BAD, GOOD, 1)

with open(SRC, 'w', encoding='utf-8') as f:
    f.write(src)

print('OK -- EBAT_CONCAT_V1 uygulandı')
print('  Eski:', BAD)
print('  Yeni:', GOOD)
