FROM node:24-bookworm-slim AS build

WORKDIR /app

COPY package.json package-lock.json ./
COPY frontend/package.json frontend/package-lock.json ./frontend/
COPY backend/package.json backend/package-lock.json ./backend/

RUN npm ci

COPY . .

# VITE_API_URL vazio = URLs relativas no browser (proxy pelo serve-frontend.js)
# Passar como build arg: docker build --build-arg VITE_API_URL=""
ARG VITE_API_URL=""
ENV VITE_API_URL=${VITE_API_URL}

RUN npm run build


FROM node:24-bookworm-slim AS runtime

WORKDIR /app

ENV NODE_ENV=production

COPY backend/package.json backend/package-lock.json ./backend/
RUN npm ci --omit=dev --prefix backend

COPY backend/src ./backend/src
COPY scripts/start.js ./scripts/start.js
COPY scripts/serve-frontend.js ./scripts/serve-frontend.js
COPY --from=build /app/frontend/dist ./frontend/dist

EXPOSE 5173

USER node

CMD ["node", "--env-file=.env", "scripts/start.js"]
