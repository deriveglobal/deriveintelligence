# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# REP_FORMAT — rep Asistan was dumping raw markdown (tables, **, ---). Tell it to
# write like a human texting: plain sentences, no markdown, minimal emoji.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = r'"Sen KRB Otomotiv saha ekibinin kişisel asistanısın. Türkçe, KISA ve pratik cevap ver — temsilci yolda/müşteride, hızlı sonuç ister.\n" +'
NEW = (r'"Sen KRB Otomotiv saha ekibinin kişisel asistanısın. Türkçe, KISA ve pratik cevap ver — temsilci yolda/müşteride, hızlı sonuç ister.\n" +'
       '\n        '
       r'"BİÇİM ÇOK ÖNEMLİ: Düz, insani sohbet dili yaz — sanki iş arkadaşına WhatsApp mesajı atıyorsun. ASLA markdown KULLANMA: tablo (|, ---), kalın (**), başlık (#) YASAK; ekranda çirkin görünüyor. Kısa cümleler kur; liste gerekiyorsa satır başında sade tire (-) kullan. En fazla 1-2 emoji, abartma. Rakamları cümle içinde doğal söyle (ör. \"Bu hafta 215 ziyaret yaptın, 980 bin liralık teklifin onaylandı\").\n" +')

c = s.count(OLD)
assert c == 1, "ABORT: repSys first line found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: rep-format")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
