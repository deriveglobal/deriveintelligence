#!/usr/bin/env python3
"""
fix_orphaned_rakip.py
Başarısız EBAT_SEARCH_V1 yamalarından kalan orphan kod bloklarını temizler.
Kalıp: saha handler'ı kapatan '}' (0 girintili) hemen ardından
       '+ vals.length);' ile başlayan ve
       'sendJson(response, 200, { rows }); return;' + '  }' ile biten
       gereksiz /api/rakip/piyasa tail kopyaları.
"""

import sys

SRC = '/opt/krb-assessment/server_container.mjs'
DST_CONTAINER = '/opt/krb-assessment/server_container.mjs'
DST_HOST      = '/opt/krb-assessment/server.mjs'

with open(SRC, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Her bozuk bölümün başını bul
broken_ranges = []
for i, l in enumerate(lines):
    stripped = l.strip()
    if stripped == '+ vals.length);' and i > 0 and lines[i-1].strip() == '}':
        # Bitiş: sendJson rows + return + } satırını ara (sonraki 40 satırda)
        end_idx = None
        for j in range(i, min(i + 40, len(lines))):
            if '{ rows }); return;' in lines[j]:
                # Bir sonraki satır '  }' mi?
                next_j = j + 1
                if next_j < len(lines) and lines[next_j].strip() == '}':
                    end_idx = next_j  # dahil
                    break
        if end_idx is not None:
            broken_ranges.append((i, end_idx))
            print(f'Bozuk bölüm: L{i+1} → L{end_idx+1} ({end_idx-i+1} satır)')
        else:
            print(f'UYARI: L{i+1} için bitiş bulunamadı — manuel kontrol gerekli')

if not broken_ranges:
    print('Bozuk bölüm yok veya kalıp eşleşmedi.')
    sys.exit(0)

# Silme işlemini sondan başa yap (indeks kaymaması için)
keep = [True] * len(lines)
for (start, end) in sorted(broken_ranges, reverse=True):
    for k in range(start, end + 1):
        keep[k] = False

new_lines = [l for i, l in enumerate(lines) if keep[i]]

with open(DST_CONTAINER, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

with open(DST_HOST, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

removed = len(lines) - len(new_lines)
print(f'OK — {len(broken_ranges)} bölüm silindi, toplam {removed} satır kaldırıldı')
print(f'Yeni dosya boyutu: {len(new_lines)} satır')
