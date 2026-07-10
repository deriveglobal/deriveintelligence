# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# CEO_FORMAT — same human/plain rule for the CEO Assistant: no markdown
# tables/asterisks/headings, conversational Turkish, minimal emoji.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = r"onemli konularda proaktif uyar.';"
NEW = r"onemli konularda proaktif uyar.\n15. BICIM cok onemli: Duz, insani sohbet dili yaz. Markdown KULLANMA: tablo (|, ---), kalin yildiz (**), baslik (#) YASAK — ekranda cirkin gorunur. Kisa cumleler; liste gerekiyorsa satir basinda sade tire (-). En fazla 1-2 emoji, abartma. Rakamlari cumle icinde dogal ver.';"

c = s.count(OLD)
assert c == 1, "ABORT: CEO prompt end found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: ceo-format")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
