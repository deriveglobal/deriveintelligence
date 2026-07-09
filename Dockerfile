FROM node:22-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY index.html styles.css app.js participant.js shared.js store.js server.mjs homepage.html ./
COPY components ./components
COPY shells ./shells
COPY database ./database

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

# Non-root user for security
RUN id -u node 2>/dev/null || (groupadd -r node && useradd -r -g node -s /bin/false node)
RUN chown -R node:node /app 2>/dev/null || true
USER node

CMD ["node", "server.mjs"]
