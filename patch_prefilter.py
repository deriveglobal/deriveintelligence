#!/usr/bin/env python3
# PREFILTER_V1 — cheap keyword gate before the intent LLM call. A note only
# reaches Haiku if it plausibly carries a signal (number/price, date/follow-up,
# competitor brand, or risk/opportunity cue). Boilerplate logging notes skip
# the call entirely. Biased toward calling when unsure (never drops real risk).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK: %s" % tag)

PREFILTER = r"""function _intentPrefilter(text) {
  let t = " " + String(text).toLowerCase()
    .replace(/i̇/g, "i").replace(/ı/g, "i").replace(/ş/g, "s").replace(/ğ/g, "g")
    .replace(/ü/g, "u").replace(/ö/g, "o").replace(/ç/g, "c") + " ";
  // numbers (price / quantity / size)
  if (/\d{2,}/.test(t)) return true;
  // price / commercial words
  if (/(\btl\b|lira|₺|fiyat|iskonto|indirim|ucuz|pahal|\bzam\b|kampanya|teklif|butce|maliyet|kdv)/.test(t)) return true;
  // date / follow-up cues
  if (/(yarin|bugun|\bdun\b|hafta|\bay\b|\bgun|pazartesi|\bsali\b|carsamba|persembe|\bcuma|cumartesi|pazar|sonra|onumuzdeki|gelecek|aksam|sabah|ogle|tarih|ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|aralik|donec|donus|arayac|gorusec|bekliyor|randevu|hatirlat|takip)/.test(t)) return true;
  // competitor brands / rivalry
  if (/(pirelli|michelin|bridgestone|goodyear|continental|lassa|petlas|starmaxx|hankook|kumho|nokian|nexen|falken|yokohama|dunlop|goodride|sailun|triangle|windforce|kormoran|debica|\bbarum|hifly|aeolus|linglong|maxxis|\btoyo|vredestein|marshal|rakip|\bmarka)/.test(t)) return true;
  // risk cues (churn / payment / complaint)
  if (/(baska|terk|memnun deg|sikayet|kizgin|birak|kesme|kesecek|\bborc|odeme|gecik|iptal|sorun|problem|kacir|kaybet|rakibe|vazgec|\bkus|sikinti|guven|gidiy|gitti)/.test(t)) return true;
  // opportunity / demand cues
  if (/(filo|\bsube|buyu|artir|yeni magaza|anlasma|potansiyel|genisle|ihtiyac|alacak|istiyor|talep|siparis|\badet|lazim|palet|stok)/.test(t)) return true;
  return false;
}

async function _extractIntent(text) {"""
rep("async function _extractIntent(text) {", PREFILTER, "prefilter-fn")

rep("    if (!text || String(text).trim().length < 4) return [];",
    "    if (!text || String(text).trim().length < 4) return [];\n    if (!_intentPrefilter(text)) return [];",
    "prefilter-gate")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
