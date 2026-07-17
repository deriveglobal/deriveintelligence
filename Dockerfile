# KRB Assessment — uygulama imaji
#
# ⚠ ONCEKI HALI IKI CIDDI BORC TASIYORDU:
#
#   1. `COPY ... server.mjs ...` — repodaki server.mjs 9 Temmuz tarihliydi ve
#      BAYATTI. Gercek dosya server_container.mjs (14 Temmuz). Imaj yeniden
#      derlenseydi sistem 8 GUN GERIYE doner, bir gunluk is kaybolurdu.
#      ✅ Artik server_container.mjs kopyalaniyor, isim karmasasi bitti.
#
#   2. Dagitim `docker cp` ile yapiliyordu. docker cp konteynerin YAZILABILIR
#      KATMANINA yazar: `docker restart` korur, ama `docker compose up
#      --force-recreate`, sunucu yeniden kurulumu ya da imaj yeniden derlenmesi
#      HEPSINI SILER. Tum is imajin icinde olmali.
#      ✅ Artik motor da (erp_ingest.py) imajda.
#
# ⚠ PYTHON: ERP yukleme motoru python3 + openpyxl + psycopg2 istiyor.
#   Konteyner USER=node (root degil) — bu yuzden calisma aninda `apk add`
#   CALISMAZ. Bagimliliklar DERLEME ANINDA, root asamasinda kurulmali.
FROM node:22-alpine

WORKDIR /app

# ⚠ PYTHON + BAGIMLILIKLAR — derleme aninda, root iken.
#   py3-psycopg2 alpine paketinden gelir (pip'le derlemesi C bagimliligi ister).
#   openpyxl saf python, pip ile.
RUN apk add --no-cache python3 py3-pip py3-psycopg2 \
 && python3 -m pip install --no-cache-dir --break-system-packages openpyxl \
 && python3 -c "import openpyxl, psycopg2; print('python bagimliliklari OK')"

COPY package.json ./
RUN npm install --omit=dev

# ⚠ server_container.mjs -> server.mjs.  Repodaki bayat server.mjs ARTIK KULLANILMIYOR.
COPY server_container.mjs ./server.mjs
COPY index.html styles.css app.js participant.js shared.js store.js homepage.html ./
COPY components ./components
COPY shells ./shells
COPY database ./database

# ⚠ ERP YUKLEME MOTORU — imajin icinde. docker cp ile degil.
# ⚠ OTOMATIK SURUMLEME (cache-bust) — her shell dosyasinin ICERIK HASH'i ?v='e yazilir.
#   Elle ?v= guncellemek UNUTULUR (14 Tem: saha.js 6 gun eski surumle yuklendi, is karanlikta).
#   Bu adim insan hatasini imkansiz kilar: dosya degisti mi hash degisir, degismedi mi ayni kalir.
COPY stamp_versions.mjs ./stamp_versions.mjs
RUN node stamp_versions.mjs /app

COPY erp_ingest.py ./erp_ingest.py

# yuklenen dosyalar icin gecici dizin (node kullanicisi yazabilmeli)
RUN mkdir -p /app/yukleme && chown -R node:node /app

ENV NODE_ENV=production
ENV PORT=3000
ENV PYTHONUNBUFFERED=1

EXPOSE 3000

USER node

CMD ["node", "server.mjs"]
