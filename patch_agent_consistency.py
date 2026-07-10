# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# AGENT_CONSISTENCY — core reliability rule for BOTH agents (rep Asistan + CEO
# Assistant): never self-contradict in one message; never assert a negative
# ("yok / goremiyorum / erisimim yok") without calling the relevant tool THIS
# turn; never repeat a prior turn's stale negative. Supersedes the price-only fix.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# ---- REP Asistan (system prompt is a double-quoted JS string -> embed \" ) ----
rep_old = 'İş bitince kısa onayla.";'
rep_new = ('İş bitince kısa onayla. '
           'TUTARLILIK (EN ÖNEMLİ KURAL): Tek bir mesajda kendinle ASLA çelişme. Bir şeyin '
           '\\"yok / göremiyorum / erişimim yok\\" olduğunu ancak BU turda ilgili aracı çağırıp '
           'sonucu gördükten sonra söyle; aracı çağırmadan ya da önceki turdan hatırlayarak olumsuz '
           'hüküm verme. Durum/veri değişmiş olabilir — her soruda ilgili aracı YENİDEN çağır ve '
           'YALNIZCA bu anki sonuca göre konuş. Önce \\"yok\\" deyip sonra aynı mesajda veri vermek '
           'gibi çelişkiler güveni yıkar.";')
rep(rep_old, rep_new, "rep-consistency")

# ---- CEO Assistant (system prompt is a single-quoted JS string -> plain " ok) ----
ceo_old = "Rakamlari cumle icinde dogal ver.';"
ceo_new = ('Rakamlari cumle icinde dogal ver.\\n'
           '16. TUTARLILIK (EN ONEMLI KURAL): Tek bir mesajda kendinle ASLA celisme. Bir verinin/durumun '
           '"yok / goremiyorum / elimde yok" oldugunu ancak BU turda ilgili araci cagirip sonucu gordukten '
           'sonra soyle; araci cagirmadan ya da onceki turdan hatirlayarak olumsuz hukum verme. Durum/veri '
           'degismis olabilir — her soruda ilgili araci YENIDEN cagir ve YALNIZCA bu anki sonuca gore konus. '
           'Once "yok" deyip sonra ayni mesajda veri vermek gibi celiskiler guveni yikar.\';')
rep(ceo_old, ceo_new, "ceo-consistency")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
