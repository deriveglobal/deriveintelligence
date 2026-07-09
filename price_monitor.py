#!/usr/bin/env python3
"""
price_monitor.py — Rakip Lastik Fiyat İzleme Sistemi
=====================================================
Kullanım:
    python3 price_monitor.py probe    # Her siteden örnek sayfa kaydeder → HTML dosyaları
    python3 price_monitor.py scrape   # Tüm sitelerden fiyat çeker → DB'ye yazar
    python3 price_monitor.py scrape --site lastikborsasi   # Tek site
    python3 price_monitor.py scrape --dry-run              # DB'ye yazmadan stdout'a basar

Gereksinimler (sunucuda kurulur, bkz. deploy_price_monitor.sh):
    pip3 install playwright psycopg2-binary
    playwright install chromium
"""

import argparse
import asyncio
import json
import os
import random
import re
import sys
import urllib.parse
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Site konfigürasyonları
# ---------------------------------------------------------------------------
# probe_urls   : Her birinden rendered HTML kaydedilecek örnek URL'ler
# list_urls    : Ürün listesi / kategori sayfaları (paginated)
# next_page_sel: "Sonraki sayfa" butonu CSS seçicisi (varsa)
# item_sel     : Ürün kartı seçicisi
# fields       : Her kartta hangi alan, hangi seçici + (isteğe bağlı) regex
#   - sel  : CSS seçici
#   - attr : innerText yerine bu attribute alınır (ör. href)
#   - re   : regex — ilk grup alınır
# ---------------------------------------------------------------------------

SITES = {
    # -----------------------------------------------------------------------
    # lastikborsasi.com
    # Kart yapısı:
    #   <div class="pro-shadow">                           ← item_sel (PARENT)
    #     <div class="product-image-area">...</div>        ← sadece resim
    #     <div class="cat-pro-info">                       ← metin: model, marka, fiyat
    #       <a href="/..."><h3 class="cat-pro-name">model</h3></a>
    #       <strong class="prod-brand-title"><a href="/markalar/...">Marka</a></strong>
    #       <strong class="cat-pro-price seenProductPrice">3.227,00 TL</strong>
    #     </div>
    #   </div>
    # Site ?page= param'ı desteklemiyor; her kategori tek sayfada ~24 ürün.
    # -----------------------------------------------------------------------
    "lastikborsasi": {
        "base": "https://www.lastikborsasi.com",
        "probe_urls": [
            "https://www.lastikborsasi.com/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/suv-4x4-lastikleri-c-93097",
        ],
        # Her sayfa ~24 ürün, sayfa numarası yok.
        # Ana kategori sayfaları (24 öne çıkan ürün) + marka bazlı sayfalar.
        # Marka sayfaları: /markalar/{marka}/{kategori-c-ID}
        "list_urls": [
            # --- Otomobil Lastikleri ---
            "https://www.lastikborsasi.com/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/michelin/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/bridgestone/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/continental/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/goodyear/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/pirelli/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/lassa/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/hankook/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/petlas/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/dayton/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/dunlop/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/falken/otomobil-lastikleri-c-271462",
            "https://www.lastikborsasi.com/markalar/nokian/otomobil-lastikleri-c-271462",
            # --- SUV / 4x4 Lastikleri ---
            "https://www.lastikborsasi.com/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/michelin/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/kormoran/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/continental/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/pirelli/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/bf-goodrich/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/goodyear/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/general-tire/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/petlas/suv-4x4-lastikleri-c-93097",
            "https://www.lastikborsasi.com/markalar/kumho/suv-4x4-lastikleri-c-93097",
            # --- Elektrikli Araç Lastikleri ---
            "https://www.lastikborsasi.com/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/michelin/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/goodyear/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/hankook/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/dunlop/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/bridgestone/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/pirelli/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/petlas/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/falken/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/Continental/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/lassa/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/dayton/elektrikli-arac-lastikleri-c-539212",
            "https://www.lastikborsasi.com/markalar/nokian/elektrikli-arac-lastikleri-c-539212",
            # --- Hafif Ticari Lastikleri ---
            "https://www.lastikborsasi.com/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/michelin/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/bridgestone/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/continental/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/petlas/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/lassa/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/hankook/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/dayton/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/kormoran/hafif-ticari-lastikleri-c-77901",
            "https://www.lastikborsasi.com/markalar/milestone/hafif-ticari-lastikleri-c-77901",
        ],
        "max_pages": 1,
        "wait_until": "networkidle",
        "next_page_sel": "a.pagination-next, a[rel='next']",
        "item_sel": ".pro-shadow",                        # 24 ürün, full kart wrapper
        "fields": {
            "marka":  {"sel": ".prod-brand-title a"},     # <a href="/markalar/goodyear">Goodyear</a>
            "model":  {"sel": ".cat-pro-name"},           # <h3 class="cat-pro-name">
            "ebat":   {"sel": ".cat-pro-name"},
            "fiyat":  {"sel": ".cat-pro-price, .seenProductPrice", "re": r"([\d\.,]+)"},
            "stok":   {"sel": None},
            "url":    {"sel": ".cat-pro-info a", "attr": "href"},  # ürün detay linki
        },
        "wait_sel": ".cat-pro-name",
        "wait_ms": 8000,
    },
    # lastix — KALDIRILDI (16 kayıt, CF engeli, verimli değil)
    # lastiksiparis — KALDIRILDI (düşük veri kalitesi, 203 kayıt)
    # -----------------------------------------------------------------------
    # lastikpazar.com
    # item_sel: .card (içinde .product-marka, .product-title, .product-price)
    #   marka: .product-marka        → "Hankook"
    #   model: .product-title h3 a   → "205/65 R16 C 8PR 107/105T VANTRA LT RA18"
    #   fiyat: .product-price        → "4.725,00 ₺"
    #   stok:  .product-stok b       → "var" / "yok"
    #   url  : .product-title h3 a href
    # -----------------------------------------------------------------------
    # DISABLED: lastikpazar.com
    # Platform: ASP.NET WebForms (WebBusiness altyapısı).
    # /lastikler → 404.aspx; /otomobil-lastikleri → 404.aspx.
    # Ürün listesi yalnızca __VIEWSTATE içeren POST isteğiyle erişilebilir (ebat filtresi formu).
    # GET tabanlı Playwright scraping mümkün değil; form doldurma gerekiyor.
    # Gelecekte: ebat bazlı POST form simülasyonu veya site yeniden yapılandırılırsa tekrar denenebilir.
    # "lastikpazar": { ... },  # DISABLED — ASP.NET WebForms POST required
    # -----------------------------------------------------------------------
    # lastikcim.com.tr — Cloudflare JS Challenge.
    # SmartProxy TR residential proxy ile açılıyor.
    # Seçiciler probe sonrası doğrulanacak (şimdilik placeholder).
    # -----------------------------------------------------------------------
    # "lastikcim": {
    #     "base": "https://www.lastikcim.com.tr",
    #     "proxy": {"server": "http://proxy.smartproxy.net:3120",
    #               "username": "smart-wclfyma0p4h6_area-TR", "password": "Fy211004"},
    #     "probe_urls": [
    #         "https://www.lastikcim.com.tr/lastik",
    #         "https://www.lastikcim.com.tr/lastik?page=2",
    #     ],
    #     "list_urls": ["https://www.lastikcim.com.tr/lastik?page={page}"],
    #     "max_pages": 50, "wait_until": "networkidle",
    #     "item_sel": "TODO", "fields": {}, "wait_sel": "TODO", "wait_ms": 15000,
    # },  # Proxy kuruldu — probe çalıştırıp item_sel belirle, sonra aktive et.

    # -----------------------------------------------------------------------
    # hepsiburada.com — SmartProxy TR residential proxy ile etkinleştirildi.
    # Probe doğrulama sonrası seçiciler:
    #   item_sel     : li[class*='productListContent']   ← ürün kartı wrapper
    #   marka        : [class*='brandName']              ← marka span
    #   model        : [class*='productName'], h3        ← ürün başlığı + ebat
    #   fiyat        : [class*='price'][class*='finalPrice'], [data-testid='price-current-value']
    #   url          : a (first anchor in card)
    # Kategoriler: binek yaz/kış/4mevsim, SUV yaz/kış/4mevsim, hafif ticari
    # -----------------------------------------------------------------------
    "hepsiburada": {
        # curl_cffi ile Akamai bypass — Playwright değil, TLS parmakizi sahteciliği
        "scrape_mode": "curl_cffi",
        "base": "https://www.hepsiburada.com",
        "proxy": {"server": "http://proxy.smartproxy.net:3120",
                  "username": "smart-wclfyma0p4h6_area-TR", "password": "Fy211004"},
        "probe_urls": [
            "https://www.hepsiburada.com/c/lastikler",
            "https://www.hepsiburada.com/c/lastikler?sayfa=2",
        ],
        "list_urls": [
            "https://www.hepsiburada.com/c/lastikler?sayfa={page}",
            "https://www.hepsiburada.com/c/suv-lastikleri?sayfa={page}",
            "https://www.hepsiburada.com/c/hafif-ticari-lastik?sayfa={page}",
        ],
        "max_pages": 50,
        # curl_cffi modu için Playwright alanları kullanılmaz — sadece list_urls işlenir
        "wait_until": "networkidle",
        "item_sel": None,
        "fields": {},
        "wait_sel": None,
        "wait_ms": 0,
        "search_url_tpl": "https://www.hepsiburada.com/ara?q={q}&siralama=fiyatadeg",
    },

    # -----------------------------------------------------------------------
    # n11.com — Türkiye'nin büyük pazaryerlerinden biri.
    # Kategori: lastik-c-9002 (lastik kategorisi ID)
    # Sayfalama: ?pg={page}
    # Probe selektörleri (Next.js SSR):
    #   item_sel     : .pro-list-item, div[class*='columnContent'] li
    #   marka        : başlıktan çıkarılır (N11 marka alanı tutarsız)
    #   model        : .productName a, h3.productName
    #   fiyat        : .price ins, .newPrice, [class*='price']
    #   url          : .productImage a, .productName a
    # -----------------------------------------------------------------------
    "n11": {
        "base": "https://www.n11.com",
        "proxy": {"server": "http://proxy.smartproxy.net:3120",
                  "username": "smart-wclfyma0p4h6_area-TR", "password": "Fy211004"},
        "probe_urls": [
            "https://www.n11.com/arama?q=lastik&srt=pl",
            "https://www.n11.com/arama?q=lastik&srt=pl&pg=2",
        ],
        "list_urls": [
            # Genel lastik araması (tüm tipler)
            "https://www.n11.com/arama?q=yaz+lastik&srt=pl&pg={page}",
            "https://www.n11.com/arama?q=kis+lastigi&srt=pl&pg={page}",
            "https://www.n11.com/arama?q=4+mevsim+lastik&srt=pl&pg={page}",
        ],
        "max_pages": 100,
        "wait_until": "domcontentloaded",  # networkidle → DOMContentLoaded: page 7+ timeout'u önler
        "page_delay_range": [4, 11],       # sayfalar arası 4-11 sn random bekleme (bot tespitini geciktir)
        # Probe doğrulandı (585KB, 20 ürün/sayfa):
        #   item   : a.product-item  ← <a href="/urun/..."> her ürünü sarar
        #   başlık : h2.product-item-title → "Petlas 205/55r16 91v Prime Comfort Yaz Lastiği 2026"
        #   fiyat  : h3.price-currency → "2.912,79 TL"
        #   yorum  : .rate-number-text → "(124)"
        #   url    : self href
        "item_sel": "a.product-item",
        "fields": {
            "marka":        {"sel": "h2.product-item-title", "re": r"^(\S+)"},
            "model":        {"sel": "h2.product-item-title"},
            "ebat":         {"sel": "h2.product-item-title"},
            "fiyat":        {"sel": "h3.price-currency", "re": r"([\d\.,]+)"},
            "stok":         {"sel": None},
            "url":          {"sel": "self", "attr": "href"},
            "yorum_sayisi": {"sel": ".rate-number-text", "re": r"\((\d+)\)"},
        },
        "wait_sel": "a.product-item",
        "wait_ms": 20000,
        # Watched scrape: marka + ebat araması
        "search_url_tpl": "https://www.n11.com/arama?q={q}&srt=pl",
    },

    # -----------------------------------------------------------------------
    # trendyol.com — SmartProxy TR residential proxy ile etkinleştirildi.
    # probe_1.html (896KB) doğrulandı — seçiciler aşağıda:
    #   item_sel     : a.product-card
    #   marka        : span.product-brand      → "Milestone"
    #   model        : span.product-name       → "185/65R15 88H CarMile (Yaz) (2026)"
    #   fiyat        : [data-testid="price-section"] → "2.020 TL"
    #   url          : sel="self" → <a> href attr
    #   puan         : [data-testid="average-rating"] → "4.4"  ← SSR'da mevcut
    #   yorum_sayisi : [data-testid="social-proof-content-basketCount"] .description span
    #                  → "332" (son 3 günde sepete ekleyen kişi sayısı) ← EN GÜÇLÜ TALEP SİNYALİ
    #   NOT: .total-count (yorum sayısı) → sadece ")" içeriyor, sayı JS render → kullanılamaz
    # -----------------------------------------------------------------------
    "trendyol": {
        "base": "https://www.trendyol.com",
        "proxy": {"server": "http://proxy.smartproxy.net:3120",
                  "username": "smart-wclfyma0p4h6_area-TR", "password": "Fy211004"},
        "probe_urls": [
            "https://www.trendyol.com/lastik-x-c103902",
            "https://www.trendyol.com/lastik-x-c103902?pi=2",
        ],
        "list_urls": ["https://www.trendyol.com/lastik-x-c103902?pi={page}"],
        "max_pages": 80,
        "wait_until": "domcontentloaded",
        "pre_click_sel": "#onetrust-accept-btn-handler",
        "pre_click_wait_ms": 3000,
        "item_sel": "a.product-card",
        "fields": {
            "marka":        {"sel": "span.product-brand"},
            "model":        {"sel": "span.product-name"},
            "ebat":         {"sel": "span.product-name"},
            "fiyat":        {"sel": "[data-testid='price-section'], .sale-price, .price-value",
                             "re": r"([\d\.,]+)"},
            "stok":         {"sel": None},
            "url":          {"sel": "self", "attr": "href"},
            "puan":         {"sel": "[data-testid='average-rating']"},
            "yorum_sayisi": {"sel": "[data-testid='social-proof-content-basketCount'] .description span",
                             "re": r"(\d+)"},
        },
        "wait_sel": "a.product-card",
        "wait_ms": 20000,
        # VIP watched scrape: Trendyol arama URL — aynı product-card yapısı
        "search_url_tpl": "https://www.trendyol.com/sr?q={q}&pi=1",
    },

    # -----------------------------------------------------------------------
    # pttavm.com — Proxy gereksiz (PTT bot koruması yok).
    # Kategori URL'leri 404; arama (search?q=lastik) çalışıyor.
    # Probe'da Schema.org ItemList JSON-LD doğrulandı: 48 ürün/sayfa.
    # scrape_mode: "jsonld" → CSS seçici yok, JSON-LD doğrudan parse ediliyor.
    # -----------------------------------------------------------------------
    "pttavm": {
        "base": "https://www.pttavm.com",
        "scrape_mode": "jsonld",          # Schema.org ItemList JSON-LD parse
        "probe_urls": [
            "https://www.pttavm.com/search?q=lastik",
            "https://www.pttavm.com/search?q=lastik&page=2",
        ],
        "list_urls": ["https://www.pttavm.com/search?q=lastik&page={page}"],
        "max_pages": 50,
        "wait_until": "networkidle",
        # item_sel / fields / wait_sel → jsonld modunda kullanılmaz
        "item_sel": "script[type='application/ld+json']",
        "fields": {},
        "wait_sel": None,
        "wait_ms": 10000,
        # VIP watched scrape: pttavm arama — aynı jsonld yapısı
        "search_url_tpl": "https://www.pttavm.com/search?q={q}&page=1",
    },

    # -----------------------------------------------------------------------
    # kolayoto.com (Shopify)
    # Shopify /products.json API kullanılır — Playwright gereksiz.
    # 250 ürün/sayfa, JS render sorunu yok, kategori bazlı filtreleme sorunsuz.
    # Koleksiyonlar:
    #   binek: yaz / kış / 4mevsim
    #   4x4-suv: yaz / kış / 4mevsim
    #   hafif ticari: yaz / kış / 4mevsim
    #   elektrikli araç lastikleri
    # -----------------------------------------------------------------------
    "kolayoto": {
        "base": "https://kolayoto.com",
        "scrape_mode": "shopify_api",   # Playwright yerine JSON API
        "probe_urls": [
            "https://kolayoto.com/collections/binek-yaz-lastikleri",
            "https://kolayoto.com/collections/binek-yaz-lastikleri?page=2",
        ],
        "list_urls": [
            "https://kolayoto.com/collections/binek-yaz-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/binek-kis-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/binek-4-mevsim-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/4x4-suv-yaz-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/4x4-suv-kis-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/4x4-suv-4-mevsim-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/hafif-ticari-yaz-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/hafif-ticari-kis-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/hafif-ticari-4-mevsim-lastikleri/products.json?limit=250&page={page}",
            "https://kolayoto.com/collections/elektrikli-arac-lastigi-fiyatlari/products.json?limit=250&page={page}",
        ],
        "max_pages": 20,
        # Aşağıdaki alanlar yalnızca probe modu için kullanılır (HTML scrape değil)
        "wait_until": "domcontentloaded",
        "item_sel": ".product-item",
        "fields": {},
        "wait_sel": "a.product-title",
        "wait_ms": 8000,
    },

    # -----------------------------------------------------------------------
    # akakce.com — Fiyat karşılaştırma aggregatörü.
    # Probe (akakce_probe_1.html, 338KB) doğrulandı — Astro/React SSR.
    # Ürün listesi <ul id="CPL"> server-side render edilir → domcontentloaded yeterli.
    # Her <li> üzerinde:
    #   data-mk  : marka (ör. "Continental")
    #   data-cp  : countOfPrices — kaç mağaza bu ürünü satıyor  ← TALEP SİNYALİ
    #   h3.pn_v8 : ürün adı + ebat
    #   span.pt_v9: fiyat → "3.971<i>,14 TL </i>" → regex ([\d\.,]+)
    #   a.iC     : ürün URL'si (href attr)
    # -----------------------------------------------------------------------
    "akakce": {
        "base": "https://www.akakce.com",
        "proxy": {"server": "http://proxy.smartproxy.net:3120",
                  "username": "smart-wclfyma0p4h6_area-TR", "password": "Fy211004"},
        "probe_urls": [
            "https://www.akakce.com/lastik.html",
            "https://www.akakce.com/lastik,2.html",
        ],
        "list_urls": ["https://www.akakce.com/lastik,{page}.html"],
        "max_pages": 50,
        "wait_until": "domcontentloaded",
        "item_sel": "#CPL li[data-pr]",
        "fields": {
            "marka":         {"sel": "self",       "attr": "data-mk"},
            "model":         {"sel": "h3.pn_v8"},
            "fiyat":         {"sel": "span.pt_v9", "re": r"([\d\.,]+)"},
            "url":           {"sel": "a.iC",       "attr": "href"},
            "satici_sayisi": {"sel": "self",       "attr": "data-cp"},
            "stok":          {"sel": None},
            "ebat":          {"sel": "h3.pn_v8"},
        },
        "wait_sel": "#CPL li[data-pr]",
        "wait_ms": 15000,
        # VIP watched scrape: arama URL şablonu ({q} = "marka ebat" URL-encoded)
        # Arama sayfası category page ile aynı #CPL yapısını kullanır.
        "search_url_tpl": "https://www.akakce.com/?q={q}",
        # Cloudflare engeli 15-16. sayfada tetikleniyor.
        # Uzun sayfalar arası bekleme (8-15 sn) ile daha fazla sayfa geçilmesi hedefleniyor.
        # CF tespit edildiğinde 60 sn bekle → aynı sayfayı 1 kez daha dene.
        "page_delay_range": [8, 15],
        "cf_retry_wait_sec": 60,
    },

    "cimri": {
        "base": "https://www.cimri.com",
        "proxy": {"server": "http://proxy.smartproxy.net:3120",
                  "username": "smart-wclfyma0p4h6_area-TR", "password": "Fy211004"},
        "probe_urls": [
            "https://www.cimri.com/lastikler",
            "https://www.cimri.com/lastikler?pg=2",
        ],
        "list_urls": ["https://www.cimri.com/lastikler?pg={page}"],
        "max_pages": 10,
        "wait_until": "networkidle",
        # item_sel + fields → probe_1.html incelendikten sonra doldurulacak
        "item_sel": "TODO",
        "fields": {},
        "wait_sel": "TODO",
        "wait_ms": 20000,
    },
}

# ---------------------------------------------------------------------------
# Boyut ayrıştırma: "205/55R16" → (205, 55, 16)
# ---------------------------------------------------------------------------
EBAT_RE = re.compile(r"(\d{3})\s*/\s*(\d{2,3})\s*[Rr]?\s*(\d{2,3})")

def parse_ebat(text: str):
    if not text:
        return None, None, None
    m = EBAT_RE.search(text.replace(",", "."))
    if m:
        return int(m.group(1)), int(m.group(2)), int(m.group(3))
    return None, None, None

def parse_fiyat(text: str):
    """Türkçe format: "3.227,00 TL" → 3227.00
    Türkçe binlik ayraç hem nokta hem de nokta-tek olabilir:
      "3.227,00" → virgül var → nokta=binlik, virgül=ondalık → 3227.00
      "2.760"    → virgül yok, tek nokta, 3 rakam sonrasında → binlik → 2760
      "3227.00"  → virgül yok, tek nokta, 2 rakam sonrasında → ondalık → 3227.00
      "1.234.567"→ birden fazla nokta → hepsi binlik → 1234567
    """
    if not text:
        return None
    # Sadece rakam, nokta, virgül bırak
    cleaned = re.sub(r"[^\d,.]", "", text)
    if not cleaned:
        return None
    # Türkçe binlik ayraç: "3.227,00" → nokta = binlik, virgül = ondalık
    if "," in cleaned:
        cleaned = cleaned.replace(".", "").replace(",", ".")
    else:
        parts = cleaned.split(".")
        if len(parts) > 2:
            # "1.234.567" → birden fazla nokta → binlik
            cleaned = "".join(parts)
        elif len(parts) == 2 and len(parts[1]) == 3:
            # "2.760" → 3 haneli ondalık = Türkçe binlik ayraç
            cleaned = "".join(parts)
        # else: "3227.00" → tek nokta, 1-2 hane → ondalık, olduğu gibi bırak
    try:
        val = float(cleaned)
        return val if val > 0 else None
    except ValueError:
        return None

# ---------------------------------------------------------------------------
# Stealth yardımcısı: Cloudflare bot tespitini atlatmak için sayfa gizleme
# playwright-stealth kurulu değilse sessizce atlanır.
# ---------------------------------------------------------------------------
async def apply_stealth(page):
    try:
        from playwright_stealth import stealth_async
        await stealth_async(page)
    except ImportError:
        pass  # playwright-stealth kurulu değil, devam et


# ---------------------------------------------------------------------------
# curl_cffi probe: Cloudflare korumalı sayfalarda TLS parmakizi sahteciliği
# curl_cffi kurulu değilse hata verir; deploy_price_monitor.sh'a ekle:
#   pip install curl_cffi
# ---------------------------------------------------------------------------
async def probe_site_curl_cffi(site_key: str, cfg: dict, out_dir: Path):
    """curl_cffi ile Chrome TLS parmakizini taklit ederek Cloudflare'ı atlatmayı dener."""
    try:
        from curl_cffi import requests as cf_requests
    except ImportError:
        print(f"  HATA: curl_cffi kurulu değil. deploy_price_monitor.sh'a 'curl_cffi' ekle.")
        return

    print(f"\n[PROBE] {site_key} (curl_cffi)")
    out_dir.mkdir(parents=True, exist_ok=True)

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    }

    for i, url in enumerate(cfg["probe_urls"]):
        print(f"  → {url}")
        try:
            resp = cf_requests.get(url, headers=headers, impersonate="chrome124", timeout=20)
            html = resp.text
            fname = out_dir / f"{site_key}_probe_{i+1}.html"
            fname.write_text(html, encoding="utf-8")
            cf_blocked = "Just a moment" in html or "challenge-platform" in html
            status = "⚠ CLOUDFLARE BLOĞU" if cf_blocked else "✓ İÇERİK ALINDI"
            print(f"     {status}: {fname} ({len(html)//1024} KB, HTTP {resp.status_code})")
        except Exception as e:
            print(f"     HATA: {e}")


# ---------------------------------------------------------------------------
# Intercept probe: XHR/fetch API çağrılarını yakalar
# Sayfada sayfalama butonuna tıklar, JSON yanıtlarını kaydeder.
# Kullanım: cfg["probe_mode"] = "intercept" olduğunda run_probe bu fonksiyonu çağırır.
# ---------------------------------------------------------------------------
async def probe_site_intercept(site_key: str, cfg: dict, out_dir: Path):
    """Playwright ağ interceptor ile sayfanın XHR/fetch JSON çağrılarını yakalar."""
    from playwright.async_api import async_playwright

    print(f"\n[PROBE-INTERCEPT] {site_key}")
    out_dir.mkdir(parents=True, exist_ok=True)

    api_calls = []

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        ctx = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="tr-TR",
        )
        page = await ctx.new_page()
        await apply_stealth(page)

        async def on_response(resp):
            ct = (resp.headers.get("content-type") or "")
            if "json" in ct or "javascript" in ct:
                try:
                    body = await resp.text()
                    if len(body) > 100:
                        api_calls.append({
                            "url": resp.url,
                            "status": resp.status,
                            "ct": ct,
                            "body": body,
                        })
                except Exception:
                    pass

        page.on("response", on_response)

        for probe_url in cfg["probe_urls"][:1]:  # İlk URL'i yükle
            print(f"  → Yükleniyor: {probe_url}")
            try:
                await page.goto(probe_url, wait_until=cfg.get("wait_until", "networkidle"), timeout=30000)
            except Exception as e:
                print(f"     Uyarı (goto): {e}")

            await page.wait_for_timeout(2000)

            # Sayfalama butonunu ara ve tıkla
            next_btn_sels = [
                cfg.get("next_page_sel", ""),
                "a[rel='next']", ".pagination .next", "button.next-page",
                "[class*='next']", "[class*='pagination'] a:last-child",
                "[class*='page-next']", "[data-page]",
            ]
            clicked = False
            for sel in next_btn_sels:
                if not sel:
                    continue
                try:
                    btn = await page.query_selector(sel)
                    if btn:
                        href = await btn.get_attribute("href") or ""
                        text = (await btn.inner_text()).strip() if not href else href
                        print(f"  → Sayfalama butonu bulundu: {sel!r} → {text[:60]}")
                        await btn.click()
                        await page.wait_for_timeout(3000)
                        clicked = True
                        break
                except Exception:
                    continue
            if not clicked:
                print("  → Sayfalama butonu bulunamadı — scroll denenecek")
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                await page.wait_for_timeout(2000)

        print(f"\n  {len(api_calls)} JSON/JS yanıtı yakalandı:")
        saved = 0
        for i, call in enumerate(api_calls):
            body = call["body"]
            # Ürün verisi içeriyor gibi görünenleri kaydet (basit heuristik)
            looks_like_products = any(kw in body for kw in [
                "product", "ürün", "urun", "lastik", "fiyat", "price", "items", "data",
            ])
            marker = "★" if looks_like_products else " "
            print(f"  {marker} [{call['status']}] {call['url'][:100]} ({len(body)} B)")
            if looks_like_products and saved < 10:
                fname = out_dir / f"{site_key}_api_{saved+1}.json"
                fname.write_text(
                    f"URL: {call['url']}\n\n{body}",
                    encoding="utf-8",
                )
                print(f"       → Kaydedildi: {fname.name}")
                saved += 1

        await browser.close()


# ---------------------------------------------------------------------------
# Probe modu: rendered HTML'i diske kaydet
# ---------------------------------------------------------------------------
async def probe_site(site_key: str, cfg: dict, out_dir: Path):
    from playwright.async_api import async_playwright

    print(f"\n[PROBE] {site_key}")
    out_dir.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        ctx_kwargs = dict(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="tr-TR",
        )
        if cfg.get("proxy"):
            ctx_kwargs["proxy"] = cfg["proxy"]
            print(f"  Proxy kullanılıyor: {cfg['proxy']['server']}")
        ctx = await browser.new_context(**ctx_kwargs)
        for i, url in enumerate(cfg["probe_urls"]):
            page = await ctx.new_page()
            await apply_stealth(page)
            try:
                print(f"  → {url}")
                wait_until = cfg.get("wait_until", "networkidle")
                try:
                    await page.goto(url, wait_until=wait_until, timeout=60000)
                except Exception as e:
                    # networkidle timeout: sayfa yüklenmiş olabilir, HTML'i kaydet
                    print(f"     Uyarı (goto timeout): mevcut HTML kaydediliyor...")
                    try:
                        html = await page.content()
                        if len(html) > 1000:
                            fname = out_dir / f"{site_key}_probe_{i+1}.html"
                            fname.write_text(html, encoding="utf-8")
                            print(f"     Kısmi HTML kaydedildi: {fname} ({len(html)//1024} KB)")
                        else:
                            print(f"     Sayfa boş geldi, atlanıyor.")
                    except Exception:
                        print(f"     HTML alınamadı: {e}")
                    await page.close()
                    continue
                # Cookie consent / overlay kapatma (ör. OneTrust) — probe'da da dene
                if cfg.get("pre_click_sel"):
                    try:
                        await page.wait_for_selector(cfg["pre_click_sel"], timeout=3000)
                        btn = await page.query_selector(cfg["pre_click_sel"])
                        if btn:
                            await btn.click()
                            await page.wait_for_timeout(cfg.get("pre_click_wait_ms", 2000))
                            print(f"     pre_click_sel {cfg['pre_click_sel']!r} tıklandı")
                    except Exception:
                        pass  # Overlay yoksa devam et
                if cfg.get("wait_sel") and cfg["wait_sel"] != "TODO":
                    try:
                        await page.wait_for_selector(cfg["wait_sel"], timeout=cfg.get("wait_ms", 5000))
                    except Exception:
                        pass  # devam et, seçici bulunamasa da HTML'i kaydet
                html = await page.content()
                fname = out_dir / f"{site_key}_probe_{i+1}.html"
                fname.write_text(html, encoding="utf-8")
                print(f"     Kaydedildi: {fname} ({len(html)//1024} KB)")
            except Exception as e:
                print(f"     HATA: {e}")
            finally:
                await page.close()
        await browser.close()

async def run_probe(sites: list, out_dir: Path):
    for key in sites:
        if key not in SITES:
            print(f"Bilinmeyen site: {key}")
            continue
        cfg = SITES[key]
        if cfg.get("scrape_mode") == "curl_cffi":
            await probe_site_curl_cffi(key, cfg, out_dir)
        elif cfg.get("probe_mode") == "intercept":
            await probe_site_intercept(key, cfg, out_dir)
        else:
            await probe_site(key, cfg, out_dir)

# ---------------------------------------------------------------------------
# Scrape modu: veriyi çek → DB'ye yaz
# ---------------------------------------------------------------------------
async def scrape_page(page, cfg: dict, url: str) -> list[dict]:
    """Tek bir liste sayfasını çekip ürün listesi döndürür."""
    wait_until = cfg.get("wait_until", "networkidle")
    try:
        await page.goto(url, wait_until=wait_until, timeout=60000)
    except Exception as e:
        print(f"  goto hata: {e}")
        return []

    # Cookie consent / overlay kapatma (ör. OneTrust)
    if cfg.get("pre_click_sel"):
        try:
            await page.wait_for_selector(cfg["pre_click_sel"], timeout=3000)
            btn = await page.query_selector(cfg["pre_click_sel"])
            if btn:
                await btn.click()
                await page.wait_for_timeout(cfg.get("pre_click_wait_ms", 2000))
        except Exception:
            pass  # Overlay yoksa devam et

    if cfg.get("wait_sel"):
        try:
            await page.wait_for_selector(cfg["wait_sel"], timeout=cfg.get("wait_ms", 5000))
        except Exception:
            title = await page.title()
            print(f"    ⚠ wait_sel '{cfg['wait_sel']}' zaman aşımı — sayfa: {title!r}")

    # Tek JS evaluate çağrısıyla tüm item verilerini çek.
    # ElementHandle tutmak yerine JS içinde DOM sorgula → stale handle hatası olmaz.
    js_fields = {
        field: {
            "sel": fcfg.get("sel"),
            "attr": fcfg.get("attr") or None,
            "isSelf": fcfg.get("sel") == "self",
        }
        for field, fcfg in cfg["fields"].items()
    }

    raw_rows = await page.evaluate(
        """([itemSel, fields]) => {
            const items = Array.from(document.querySelectorAll(itemSel));
            if (!items.length) return [];
            return items.map(item => {
                const row = {};
                for (const [field, fcfg] of Object.entries(fields)) {
                    if (!fcfg.sel) { row[field] = null; continue; }
                    const el = fcfg.isSelf ? item : item.querySelector(fcfg.sel);
                    if (!el) { row[field] = null; continue; }
                    row[field] = fcfg.attr
                        ? (el.getAttribute(fcfg.attr) || null)
                        : ((el.innerText || '').trim() || null);
                }
                return row;
            });
        }""",
        [cfg["item_sel"], js_fields],
    )

    if not raw_rows:
        title = await page.title()
        print(f"    ürün bulunamadı — sayfa: {title!r}")
        return []

    results = []
    for row in raw_rows:
        # Python-side regex uygula
        for field, fcfg in cfg["fields"].items():
            if fcfg.get("re") and row.get(field):
                m = re.search(fcfg["re"], row[field])
                row[field] = m.group(1) if m else row[field]

        # URL'yi mutlak yap
        if row.get("url") and not row["url"].startswith("http"):
            row["url"] = cfg["base"].rstrip("/") + "/" + row["url"].lstrip("/")

        # Fiyat ve ebat ayrıştır
        row["fiyat_num"] = parse_fiyat(row.get("fiyat") or "")
        ebat_str = row.get("ebat") or (row.get("model") or "")
        row["genislik"], row["profil"], row["cap"] = parse_ebat(ebat_str)

        # Talep sinyalleri → integer
        if row.get("satici_sayisi"):
            try:
                row["satici_sayisi"] = int(str(row["satici_sayisi"]).strip())
            except (ValueError, TypeError):
                row["satici_sayisi"] = None
        if row.get("yorum_sayisi"):
            try:
                row["yorum_sayisi"] = int(re.sub(r"[^\d]", "", str(row["yorum_sayisi"]))) or None
            except (ValueError, TypeError):
                row["yorum_sayisi"] = None
        # Puan → float (ör. "4.4" veya "4,4")
        if row.get("puan"):
            try:
                row["puan"] = float(str(row["puan"]).strip().replace(",", "."))
            except (ValueError, TypeError):
                row["puan"] = None

        if row.get("fiyat_num") and row.get("fiyat_num") >= 100 and row.get("marka"):
            results.append(row)

    return results


async def scrape_site_shopify_api(site_key: str, cfg: dict, dry_run: bool, db_conn):
    """Shopify /products.json API üzerinden veri çeker (Playwright gereksiz).
    Rate limiting: sayfa aralarında 2 sn, koleksiyon aralarında 5 sn bekleme.
    429 alınırsa 30 sn bekle, 1 kere yeniden dene.
    Fiyat: birden fazla variant varsa en yüksek fiyatlı (gerçek lastik fiyatı).
    """
    import urllib.request, json as _json, time

    print(f"\n[SCRAPE] {site_key} (Shopify API)")
    total = 0

    for col_idx, url_tpl in enumerate(cfg["list_urls"]):
        if col_idx > 0:
            time.sleep(30)  # koleksiyonlar arası bekleme (rate limit önlemi)

        for page_num in range(1, cfg["max_pages"] + 1):
            if page_num > 1:
                time.sleep(5)   # sayfa arası bekleme

            url = url_tpl.format(page=page_num)
            print(f"  sayfa {page_num}: {url}")

            data = None
            for attempt in range(2):
                try:
                    req = urllib.request.Request(
                        url,
                        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0"}
                    )
                    with urllib.request.urlopen(req, timeout=20) as resp:
                        data = _json.loads(resp.read())
                    break   # başarılı
                except urllib.error.HTTPError as e:
                    if e.code == 429 and attempt == 0:
                        print(f"  → 429 Rate limit, 120 sn bekleniyor...")
                        time.sleep(120)
                    else:
                        print(f"  → HATA: {e}")
                        data = None
                        break
                except Exception as e:
                    print(f"  → HATA: {e}")
                    data = None
                    break

            if data is None:
                break

            products = data.get("products", [])
            if not products:
                print("  → ürün yok, duruyorum")
                break

            rows = []
            for p in products:
                title  = (p.get("title") or "").strip()
                vendor = (p.get("vendor") or "").strip()
                handle = (p.get("handle") or "").strip()
                url_p  = f"{cfg['base'].rstrip('/')}/products/{handle}"

                # En yüksek fiyatlı variant = gerçek lastik satış fiyatı
                # (variants[0] bazen placeholder/boş slot olabilir)
                variants = p.get("variants") or [{}]
                best_price = 0.0
                best_price_str = ""
                for v in variants:
                    ps = v.get("price") or ""
                    pv = parse_fiyat(ps)
                    if pv and pv > best_price:
                        best_price = pv
                        best_price_str = ps

                fiyat_num = best_price if best_price > 0 else None
                genislik, profil, cap = parse_ebat(title)

                if fiyat_num and fiyat_num >= 100 and vendor:
                    rows.append({
                        "marka":     vendor,
                        "model":     title,
                        "ebat":      title,
                        "fiyat":     best_price_str,
                        "fiyat_num": fiyat_num,
                        "stok":      None,
                        "url":       url_p,
                        "genislik":  genislik,
                        "profil":    profil,
                        "cap":       cap,
                    })

            print(f"  → {len(rows)} ürün")
            total += len(rows)

            if dry_run:
                for r in rows[:3]:
                    print(f"    {r['marka']} | {r['model']} | {r['fiyat_num']} TRY")
            else:
                insert_rows(db_conn, site_key, rows)

            # Shopify: son sayfa döndüğünde limit'ten az ürün gelir
            if len(products) < 250:
                break

    print(f"[SCRAPE] {site_key} tamamlandı: {total} ürün")
    return total


async def scrape_site_jsonld(site_key: str, cfg: dict, dry_run: bool, db_conn):
    """Schema.org ItemList JSON-LD tabanlı scraper (pttavm vb.).
    Her sayfa yüklenince <script type='application/ld+json'> etiketleri parse edilir.
    CSS seçici gerektirmez; yapılandırılmış veri doğrudan okunur.
    """
    import json as _json
    from playwright.async_api import async_playwright

    print(f"\n[SCRAPE] {site_key} [jsonld]")
    total = 0

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        ctx_kwargs = dict(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="tr-TR",
        )
        if cfg.get("proxy"):
            ctx_kwargs["proxy"] = cfg["proxy"]
            print(f"  Proxy kullanılıyor: {cfg['proxy']['server']}")
        ctx = await browser.new_context(**ctx_kwargs)
        page = await ctx.new_page()
        await apply_stealth(page)

        page_start = cfg.get("page_start", 1)
        for url_tpl in cfg["list_urls"]:
            seen_urls: set = set()
            for page_num in range(page_start, cfg["max_pages"] + page_start):
                url = url_tpl.format(page=page_num)
                print(f"  sayfa {page_num}: {url}")

                wait_until = cfg.get("wait_until", "networkidle")
                try:
                    await page.goto(url, wait_until=wait_until, timeout=60000)
                except Exception as e:
                    print(f"  goto hata: {e}")
                    break

                # Cookie consent / overlay kapatma
                if cfg.get("pre_click_sel"):
                    try:
                        await page.wait_for_selector(cfg["pre_click_sel"], timeout=3000)
                        btn = await page.query_selector(cfg["pre_click_sel"])
                        if btn:
                            await btn.click()
                            await page.wait_for_timeout(cfg.get("pre_click_wait_ms", 2000))
                    except Exception:
                        pass

                # JSON-LD script tag'larını bul ve ItemList'i parse et
                scripts = await page.query_selector_all('script[type="application/ld+json"]')
                rows: list[dict] = []
                for script in scripts:
                    try:
                        text = await script.inner_text()
                        data = _json.loads(text)
                        if data.get("@type") != "ItemList":
                            continue
                        for item_el in data.get("itemListElement", []):
                            item = item_el.get("item", {})
                            if item.get("@type") != "Product":
                                continue
                            offers = item.get("offers", {})
                            if isinstance(offers, list):
                                offers = offers[0] if offers else {}
                            name      = (item.get("name") or "").strip()
                            price_str = str(offers.get("price", ""))
                            url_val   = item.get("url", "")
                            avail     = offers.get("availability", "")
                            in_stock  = "InStock" in avail

                            fiyat_num        = parse_fiyat(price_str)
                            genislik, profil, cap = parse_ebat(name)
                            marka = name.split()[0] if name else None

                            if fiyat_num and fiyat_num >= 100 and name:
                                rows.append({
                                    "marka":    marka,
                                    "model":    name,
                                    "ebat":     name,
                                    "fiyat":    price_str,
                                    "fiyat_num": fiyat_num,
                                    "stok":     "Stokta Var" if in_stock else "Stok Yok",
                                    "url":      url_val,
                                    "genislik": genislik,
                                    "profil":   profil,
                                    "cap":      cap,
                                })
                    except Exception:
                        continue

                if not rows:
                    title = await page.title()
                    print(f"    JSON-LD ürün bulunamadı — sayfa: {title!r}, duruyorum")
                    break

                # Sayfa sarma tespiti
                if "{page}" in url_tpl:
                    page_urls = {r.get("url") for r in rows if r.get("url")}
                    if page_urls and page_urls.issubset(seen_urls):
                        print(f"  → Sarma tespit edildi (sayfa {page_num}), duruyorum")
                        break
                    seen_urls.update(page_urls)

                print(f"  → {len(rows)} ürün")
                total += len(rows)

                if dry_run:
                    for r in rows[:3]:
                        print(f"    {r.get('marka')} | {r.get('model','')[:45]} | {r.get('fiyat_num')} TRY")
                else:
                    insert_rows(db_conn, site_key, rows)

                if "{page}" not in url_tpl:
                    break

        await browser.close()

    print(f"[SCRAPE] {site_key} tamamlandı: {total} ürün")
    return total


def _find_products_in_json(obj, depth=0):
    """
    Recursively find product-like objects in a JSON tree.
    A product has a non-empty 'name' (or 'title'/'displayName') string AND
    a numeric or string 'price' (or 'salePrice'/'campaignPrice'/'currentPrice').
    Returns list of dicts: {name, price, brand}
    """
    if depth > 12 or not obj:
        return []
    results = []
    if isinstance(obj, list):
        for item in obj:
            results.extend(_find_products_in_json(item, depth + 1))
        return results
    if not isinstance(obj, dict):
        return []

    name = obj.get("name") or obj.get("title") or obj.get("displayName") or obj.get("productName") or ""
    raw_price = (obj.get("price") or obj.get("salePrice") or obj.get("campaignPrice")
                 or obj.get("currentPrice") or obj.get("originalPrice"))

    if name and isinstance(name, str) and len(name) > 6 and raw_price is not None:
        try:
            price = float(str(raw_price).replace(".", "").replace(",", ".").strip())
        except (ValueError, AttributeError):
            price = None
        if price and price > 100:
            brand = None
            if isinstance(obj.get("brand"), dict):
                brand = obj["brand"].get("name")
            elif isinstance(obj.get("brand"), str):
                brand = obj["brand"]
            elif isinstance(obj.get("brandName"), str):
                brand = obj["brandName"]
            results.append({"name": name, "price": price, "brand": brand})

    for v in obj.values():
        if isinstance(v, (dict, list)):
            results.extend(_find_products_in_json(v, depth + 1))
    return results


async def scrape_site_curl_cffi(site_key: str, cfg: dict, dry_run: bool, db_conn):
    """
    curl_cffi tabanlı scraper: TLS parmakizi sahteciliği ile Akamai/Cloudflare bypass.
    __NEXT_DATA__ JSON'dan ürün verisi çeker, regex ile fallback yapar.
    """
    try:
        from curl_cffi import requests as cf_requests
    except ImportError:
        print(f"[SCRAPE] {site_key}: curl_cffi kurulu değil — pip install curl_cffi")
        return 0

    proxy_cfg = cfg.get("proxy")
    proxies = None
    if proxy_cfg:
        server = proxy_cfg["server"]
        user   = proxy_cfg.get("username", "")
        passwd = proxy_cfg.get("password", "")
        if user:
            parts = server.split("://", 1)
            proxies = {
                "http":  f"{parts[0]}://{user}:{passwd}@{parts[1]}",
                "https": f"{parts[0]}://{user}:{passwd}@{parts[1]}",
            }
        else:
            proxies = {"http": server, "https": server}

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Encoding": "gzip, deflate, br",
        "Cache-Control": "no-cache",
    }

    print(f"\n[SCRAPE] {site_key} (curl_cffi / Akamai bypass)")
    if proxies:
        print(f"  Proxy: {cfg['proxy']['server']}")
    total = 0

    for url_tpl in cfg["list_urls"]:
        for page_num in range(1, cfg.get("max_pages", 30) + 1):
            url = url_tpl.format(page=page_num)
            print(f"  sayfa {page_num}: {url}")

            try:
                resp = cf_requests.get(
                    url, headers=headers, proxies=proxies,
                    impersonate="chrome124", timeout=25,
                )
                html = resp.text
            except Exception as e:
                print(f"  → fetch hatası: {e}")
                break

            # Bot bloğu kontrolü
            if resp.status_code != 200 or "güvenlik" in html[:500].lower() or len(html) < 5000:
                print(f"  → HTTP {resp.status_code}, {len(html)} B — engellenmiş, duruyorum")
                break

            # ── __NEXT_DATA__ parse ───────────────────────────────────────────
            rows = []
            nd_match = re.search(r'<script[^>]+id=["\']__NEXT_DATA__["\'][^>]*>([^<]+)</script>', html)
            if nd_match:
                try:
                    nd = json.loads(nd_match.group(1))
                    products = _find_products_in_json(nd)
                    for p in products:
                        w, a, r = parse_ebat(p["name"])
                        if not w:
                            continue
                        ebat = f"{w}/{a}R{r}"
                        marka = p.get("brand") or (p["name"].split()[0] if p["name"] else None)
                        rows.append({
                            "marka": marka, "ebat": ebat,
                            "fiyat": p["price"], "stok": None,
                            "url": url, "satici_sayisi": None,
                            "yorum_sayisi": None, "puan": None,
                        })
                except (json.JSONDecodeError, Exception) as e:
                    print(f"  → __NEXT_DATA__ parse hatası: {e}")

            # ── Regex fallback: JSON-LD Schema.org ────────────────────────────
            if not rows:
                for ld_match in re.finditer(
                    r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>([^<]+)</script>', html
                ):
                    try:
                        ld = json.loads(ld_match.group(1))
                        for p in _find_products_in_json(ld):
                            w, a, r = parse_ebat(p["name"])
                            if w:
                                rows.append({
                                    "marka": p.get("brand") or p["name"].split()[0],
                                    "ebat": f"{w}/{a}R{r}", "fiyat": p["price"],
                                    "stok": None, "url": url,
                                    "satici_sayisi": None, "yorum_sayisi": None, "puan": None,
                                })
                    except Exception:
                        pass

            if not rows:
                print(f"  → 0 ürün — son sayfa veya yapı değişti, duruyorum")
                break

            print(f"  → {len(rows)} ürün")
            total += len(rows)

            if dry_run:
                for r in rows[:3]:
                    print(f"     {r['marka']} | {r['ebat']} | {r['fiyat']} TL")
            else:
                insert_rows(db_conn, site_key, rows)

            # Sayfa sarma: 0 ürün → dur; sayfa {page} yoksa → tek URL
            if "{page}" not in url_tpl:
                break

            import time
            time.sleep(random.uniform(1.5, 3.0))

    print(f"[SCRAPE] {site_key} tamamlandı: {total} ürün")
    return total


async def scrape_site(site_key: str, cfg: dict, dry_run: bool, db_conn):
    if cfg.get("scrape_mode") == "shopify_api":
        return await scrape_site_shopify_api(site_key, cfg, dry_run, db_conn)
    if cfg.get("scrape_mode") == "jsonld":
        return await scrape_site_jsonld(site_key, cfg, dry_run, db_conn)
    if cfg.get("scrape_mode") == "curl_cffi":
        return await scrape_site_curl_cffi(site_key, cfg, dry_run, db_conn)

    from playwright.async_api import async_playwright

    print(f"\n[SCRAPE] {site_key}")
    total = 0

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        ctx_kwargs = dict(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="tr-TR",
        )
        if cfg.get("proxy"):
            ctx_kwargs["proxy"] = cfg["proxy"]
            print(f"  Proxy kullanılıyor: {cfg['proxy']['server']}")
        ctx = await browser.new_context(**ctx_kwargs)
        page = await ctx.new_page()
        await apply_stealth(page)

        page_start = cfg.get("page_start", 1)  # Sayfalama başlangıç numarası (ör. lastix: ?page=2'den başlar)
        for url_tpl in cfg["list_urls"]:
            seen_urls: set = set()  # Sayfa sarma tespiti: tekrar eden URL → son sayfa geçildi
            for page_num in range(page_start, cfg["max_pages"] + page_start):
                url = url_tpl.format(page=page_num)
                print(f"  sayfa {page_num}: {url}")
                rows = await scrape_page(page, cfg, url)
                if not rows:
                    # Cloudflare engeli mi, yoksa gerçekten son sayfa mı?
                    title = await page.title()
                    cf_blocked = any(kw in title.lower() for kw in ["bir dakika", "just a moment", "challenge"])
                    cf_wait = cfg.get("cf_retry_wait_sec", 0)
                    if cf_blocked and cf_wait > 0:
                        print(f"  ⚠ Cloudflare engeli: {title!r} — {cf_wait} sn bekleniyor, yeniden deneniyor...")
                        await asyncio.sleep(cf_wait)
                        rows = await scrape_page(page, cfg, url)
                        if not rows:
                            print("  → CF engeli devam ediyor, duruyorum")
                            break
                    else:
                        print(f"  → ürün yok, duruyorum (sayfa: {title!r})")
                        break

                # URL tabanlı sayfalama → sarma tespiti SAYIMDAN ÖNCE (duplicate önlemek için).
                if "{page}" in url_tpl:
                    page_urls = {r.get("url") for r in rows if r.get("url")}
                    if page_urls and page_urls.issubset(seen_urls):
                        print(f"  → Sayfa sarma tespit edildi (sayfa {page_num} = sayfa 1), duruyorum")
                        break
                    seen_urls.update(page_urls)

                # Sayım ve kayıt (sarma tespit edilmemişse veya {page} yoksa).
                print(f"  → {len(rows)} ürün")
                total += len(rows)

                if dry_run:
                    for r in rows[:3]:
                        demand = []
                        if r.get("satici_sayisi") is not None:
                            demand.append(f"{r['satici_sayisi']} satıcı")
                        if r.get("yorum_sayisi") is not None:
                            demand.append(f"{r['yorum_sayisi']} sepet")
                        if r.get("puan") is not None:
                            demand.append(f"★{r['puan']}")
                        demand_str = " | " + ", ".join(demand) if demand else ""
                        print(f"    {r.get('marka')} | {r.get('model','')[:50]} | {r.get('fiyat_num')} TRY{demand_str}")
                else:
                    insert_rows(db_conn, site_key, rows)

                # Sonraki sayfa kararı:
                # {page} varsa → URL numarası artır, döngü devam eder.
                # {page} yoksa → her URL şablonu yalnızca 1 kez yüklenir, çık.
                if "{page}" not in url_tpl:
                    break

                # Bot tespitini geciktirmek için sayfalar arası random bekleme.
                # Her site kendi page_delay_range'ini belirleyebilir (ör. akakce: 8-15 sn).
                delay_range = cfg.get("page_delay_range", [2.0, 5.0])
                delay = random.uniform(delay_range[0], delay_range[1])
                await asyncio.sleep(delay)

        await browser.close()

    print(f"[SCRAPE] {site_key} tamamlandı: {total} ürün")
    return total


def insert_rows(conn, site_key: str, rows: list[dict]):
    cur = conn.cursor()
    sql = """
        INSERT INTO bi_rakip_fiyat
            (kaynak, marka, model, ebat, genislik, profil, cap,
             fiyat, stok, url, satici_sayisi, yorum_sayisi, puan)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """
    for r in rows:
        try:
            cur.execute(sql, (
                site_key,
                (r.get("marka") or "").strip()[:200],
                (r.get("model") or "").strip()[:500],
                (r.get("ebat")  or "").strip()[:500],  # Ham platform başlığı — transform layer'da normalize edilir
                r.get("genislik"),
                r.get("profil"),
                r.get("cap"),
                r.get("fiyat_num"),
                (r.get("stok") or "")[:50] or None,
                (r.get("url") or "")[:500],
                r.get("satici_sayisi"),   # INTEGER: akakce data-cp (kaç mağaza)
                r.get("yorum_sayisi"),    # INTEGER: trendyol sepete ekleyen kişi (3 gün)
                r.get("puan"),            # NUMERIC: trendyol yıldız puanı (ör. 4.4)
            ))
        except Exception as e:
            print(f"  INSERT hata: {e}")
    conn.commit()
    cur.close()


# ---------------------------------------------------------------------------
# Watched scrape: VIP izleme listesindeki SKU'ları hedefli ara
# ---------------------------------------------------------------------------

async def _watched_scrape_playwright(site_key: str, cfg: dict, url: str) -> list:
    """Arama URL'sini mevcut Playwright seçicilerle çeker (1 sayfa)."""
    from playwright.async_api import async_playwright
    rows = []
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        ctx_kwargs = dict(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="tr-TR",
        )
        if cfg.get("proxy"):
            ctx_kwargs["proxy"] = cfg["proxy"]
        ctx = await browser.new_context(**ctx_kwargs)
        page = await ctx.new_page()
        await apply_stealth(page)
        rows = await scrape_page(page, cfg, url)
        await browser.close()
    return rows


async def _watched_scrape_jsonld(cfg: dict, url: str) -> list:
    """Arama URL'sini jsonld modunda çeker (pttavm vb.) — 1 sayfa."""
    import json as _json
    from playwright.async_api import async_playwright
    rows = []
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        ctx = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
            ),
            locale="tr-TR",
        )
        page = await ctx.new_page()
        await apply_stealth(page)
        try:
            await page.goto(url, wait_until=cfg.get("wait_until", "networkidle"), timeout=30000)
        except Exception:
            pass
        scripts = await page.query_selector_all('script[type="application/ld+json"]')
        for script in scripts:
            try:
                data = _json.loads(await script.inner_text())
                if data.get("@type") != "ItemList":
                    continue
                for item_el in data.get("itemListElement", []):
                    item = item_el.get("item", {})
                    if item.get("@type") != "Product":
                        continue
                    offers = item.get("offers", {})
                    if isinstance(offers, list):
                        offers = offers[0] if offers else {}
                    name      = (item.get("name") or "").strip()
                    price_str = str(offers.get("price", ""))
                    url_val   = item.get("url", "")
                    fiyat_num = parse_fiyat(price_str)
                    genislik, profil, cap = parse_ebat(name)
                    marka_g = name.split()[0] if name else None
                    if fiyat_num and fiyat_num >= 100:
                        rows.append({
                            "marka": marka_g, "model": name, "ebat": name,
                            "fiyat": price_str, "fiyat_num": fiyat_num,
                            "stok": None, "url": url_val,
                            "genislik": genislik, "profil": profil, "cap": cap,
                        })
            except Exception:
                continue
        await browser.close()
    return rows


def _filter_watched(rows: list, marka: str, ebat: str, model_pattern: str) -> list:
    """Scrape sonuçlarını marka + ebat ile filtreler."""
    marka_l = marka.lower()
    ebat_l  = ebat.replace(" ", "").lower()
    out = []
    for r in rows:
        row_marka = (r.get("marka") or r.get("model") or "").lower()
        row_ebat  = (r.get("ebat")  or r.get("model") or "").replace(" ", "").lower()
        if marka_l in row_marka and ebat_l in row_ebat:
            if model_pattern and not re.search(model_pattern, r.get("model") or "", re.IGNORECASE):
                continue
            out.append(r)
    return out


async def run_watched_scrape(dry_run: bool):
    """
    VIP izleme listesi scrape: bi_rakip_izle tablosundaki aktif SKU'ları
    search_url_tpl'si olan tüm kaynaklarda arar.
    Fiyat değişimi alarm_esigi'ni aşarsa bi_rakip_fiyat_alarm'a kaydeder.
    """
    import psycopg2

    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("HATA: DATABASE_URL ayarlı değil.")
        sys.exit(1)

    conn = psycopg2.connect(db_url)
    cur  = conn.cursor()

    # İzleme listesini al
    cur.execute("""
        SELECT id, marka, ebat, model_pattern, alarm_esigi
        FROM bi_rakip_izle
        WHERE aktif = TRUE
        ORDER BY id
    """)
    izle_list = cur.fetchall()

    if not izle_list:
        print("[WATCHED] İzleme listesi boş.")
        conn.close()
        return

    print(f"\n[WATCHED SCRAPE] {len(izle_list)} SKU izlenecek\n")

    # En güncel fiyatlar — alarm karşılaştırması için
    cur.execute("SELECT kaynak, marka, ebat, fiyat FROM bi_rakip_fiyat_son")
    son_fiyat_map = {
        (row[0], row[1].lower(), row[2].lower()): float(row[3])
        for row in cur.fetchall()
    }

    for izle_id, marka, ebat, model_pat, alarm_esigi in izle_list:
        q = urllib.parse.quote(f"{marka} {ebat}")
        print(f"  [{marka} | {ebat}]")

        for site_key, cfg in SITES.items():
            if not cfg.get("search_url_tpl"):
                continue

            url = cfg["search_url_tpl"].format(q=q)

            try:
                if cfg.get("scrape_mode") == "jsonld":
                    raw_rows = await _watched_scrape_jsonld(cfg, url)
                else:
                    raw_rows = await _watched_scrape_playwright(site_key, cfg, url)
            except Exception as e:
                print(f"    {site_key}: HATA {e}")
                continue

            filtered = _filter_watched(raw_rows, marka, ebat, model_pat)
            if not filtered:
                continue

            print(f"    {site_key}: {len(filtered)} eşleşme")

            # Alarm kontrolü — her eşleşen ürün için fiyat değişimini kontrol et
            for r in filtered:
                new_price = r.get("fiyat_num")
                if not new_price:
                    continue
                old_price = son_fiyat_map.get((site_key, marka.lower(), ebat.lower()))
                if old_price and alarm_esigi:
                    change_pct = abs(new_price - old_price) / old_price * 100
                    if change_pct >= float(alarm_esigi):
                        yon = "YUKARI" if new_price > old_price else "ASAGI"
                        print(f"    ⚠ ALARM {site_key}: {yon} %{change_pct:.1f} ({old_price:.0f} → {new_price:.0f})")
                        if not dry_run:
                            cur.execute("""
                                INSERT INTO bi_rakip_fiyat_alarm
                                    (izle_id, kaynak, marka, ebat,
                                     eski_fiyat, yeni_fiyat, degisim_pct, yon)
                                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                            """, (izle_id, site_key, marka, ebat,
                                  old_price, new_price, round(change_pct, 2), yon))

            if not dry_run:
                insert_rows(conn, site_key, filtered)

    if not dry_run:
        conn.commit()
    cur.close()
    conn.close()
    print("\n[WATCHED SCRAPE] tamamlandı")


async def run_scrape(sites: list, dry_run: bool):
    conn = None
    if not dry_run:
        import psycopg2
        db_url = os.environ.get("DATABASE_URL")
        if not db_url:
            print("HATA: DATABASE_URL ortam değişkeni ayarlı değil.")
            sys.exit(1)
        conn = psycopg2.connect(db_url)

    for key in sites:
        if key not in SITES:
            print(f"Bilinmeyen site: {key}")
            continue
        await scrape_site(key, SITES[key], dry_run, conn)

    if conn:
        conn.close()

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Rakip lastik fiyat izleme")
    parser.add_argument(
        "mode",
        choices=["probe", "scrape", "watched"],
        help=(
            "probe: HTML kaydet | "
            "scrape: tam fiyat çekimi (günde 1x) | "
            "watched: VIP izleme listesi scrape (günde 3x: 08/13/20)"
        ),
    )
    parser.add_argument("--site", help="Tek site (ör. lastikborsasi). Belirtilmezse hepsi çalışır.")
    parser.add_argument("--dry-run", action="store_true", help="DB'ye yazmadan stdout'a yaz")
    parser.add_argument("--out-dir", default="/tmp/price_probe", help="Probe HTML çıktı dizini")
    args = parser.parse_args()

    sites = [args.site] if args.site else list(SITES.keys())

    if args.mode == "probe":
        asyncio.run(run_probe(sites, Path(args.out_dir)))
        print(f"\nProbe tamamlandı. HTML dosyaları: {args.out_dir}")
        print("Selektörleri kontrol edip SITES konfigürasyonunu güncelleyin, ardından 'scrape' modunu çalıştırın.")
    elif args.mode == "watched":
        asyncio.run(run_watched_scrape(args.dry_run))
    else:
        asyncio.run(run_scrape(sites, args.dry_run))


if __name__ == "__main__":
    main()
