import sys
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "REP_BRAIN_SCROLL_V1" in s:
    print("[skip] zaten var"); sys.exit(0)

# Dogru dosya mi? (asistan + PTR handler burada olmali)
assert "function vRepBrain" in s, "HATA: vRepBrain yok - yanlis/eski saha.js?"
assert 'document.querySelector(".ceo-wrap")' in s, "HATA: PTR sc() ceo-wrap ankoru yok - yanlis/eski saha.js?"

# 1) Asistan (rep-brain) dis sarmalayicisina .rb-wrap sinifi + marker
A1='    <div style="display:flex;flex-direction:column;height:100%;min-height:0">'
assert s.count(A1)==1, "A1 anchor: %d"%s.count(A1)
s=s.replace(A1, '    <div class="rb-wrap" style="display:flex;flex-direction:column;height:100%;min-height:0"> <!-- REP_BRAIN_SCROLL_V1 -->', 1)

# 2) PTR handler asistan ekraninda da kendini kapatsin (CEO sohbetiyle ayni mantik).
#    Saglam ankor: sadece querySelector argumani (satirin geri kalani surumden surume degisebilir).
A2='document.querySelector(".ceo-wrap")'
assert s.count(A2)==1, "A2 anchor: %d"%s.count(A2)
s=s.replace(A2, 'document.querySelector(".ceo-wrap, .rb-wrap")', 1)

open(F,"w",encoding="utf-8").write(s)
print("[ok] REP_BRAIN_SCROLL_V1 eklendi")
