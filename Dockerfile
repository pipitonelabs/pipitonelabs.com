# Build stages run on Alpine (musl) so bun resolves the same sharp
# prebuilt binaries (@img/sharp-linuxmusl-*) that the Alpine runtime needs.

# Full dependency install (dev + prod) for the build
FROM oven/bun:1.4.5-alpine AS deps

WORKDIR /app

COPY package*.json bun.lock bunfig.toml ./
COPY packages/ ./packages/

RUN bun install --frozen-lockfile

# Production-only dependencies for the runtime image
FROM oven/bun:1.4.5-alpine AS prod-deps

WORKDIR /app

COPY package*.json bun.lock bunfig.toml ./
COPY packages/ ./packages/

RUN bun install --frozen-lockfile --production

# Build stage
FROM deps AS build

COPY . .

# Use the Node adapter instead of Vercel
ENV BUILD_TARGET=docker

RUN bun run build

# Runtime stage (pinned for reproducibility; bump on Node security releases)
FROM node:22.23.5-alpine3.24

WORKDIR /app

# Pick up OS package fixes published after the base image was built
RUN apk upgrade --no-cache

# Non-root user (uid/gid 1001 must match the k8s securityContext)
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 --ingroup nodejs astrojs

COPY --from=build --chown=astrojs:nodejs /app/dist ./dist
COPY --from=prod-deps --chown=astrojs:nodejs /app/node_modules ./node_modules

USER astrojs

EXPOSE 4321

CMD ["node", "dist/server/entry.mjs"]
