# syntax=docker/dockerfile:1

# ---- Stage 1: compilar el frontend Flutter Web ----
FROM ghcr.io/cirruslabs/flutter:stable AS web-build
WORKDIR /web
COPY apps/web/pubspec.yaml apps/web/pubspec.lock ./
RUN flutter pub get
COPY apps/web/ .
RUN flutter build web --dart-define=API_URL=/api

# ---- Stage 2: instalar deps y compilar el backend ----
FROM node:24-slim AS backend-build
RUN apt-get update -y && apt-get install -y --no-install-recommends openssl \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY apps/backend/package.json apps/backend/package-lock.json ./
COPY apps/backend/prisma ./prisma
RUN npm ci
COPY apps/backend/tsconfig.json ./
COPY apps/backend/src ./src
RUN npx tsc -b
RUN npm prune --omit=dev

# ---- Stage 3: imagen final de runtime ----
FROM node:24-slim AS runtime
RUN apt-get update -y && apt-get install -y --no-install-recommends openssl \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production
COPY --from=backend-build /app/package.json ./package.json
COPY --from=backend-build /app/node_modules ./node_modules
COPY --from=backend-build /app/dist ./dist
COPY --from=backend-build /app/prisma ./prisma
COPY --from=web-build /web/build/web ./public

EXPOSE 4000
CMD ["npm", "run", "start"]
