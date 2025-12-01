# Build stage
FROM oven/bun:1 AS build

WORKDIR /app

# Copy package files and local packages
COPY package*.json bun.lock ./
COPY packages/ ./packages/

# Install dependencies (including local packages)
RUN bun install

# Install @astrojs/node for standalone deployment
RUN bun add @astrojs/node

# Copy source code
COPY . .

# Modify astro.config.ts to use Node adapter instead of Vercel
# Also use passthrough image service (outputs direct image URLs, no /_image endpoint needed)
RUN sed -i '1i import node from "@astrojs/node";' astro.config.ts && \
    sed -i '1i import { passthroughImageService } from "astro/assets/services/passthrough";' astro.config.ts && \
    sed -i 's/adapter: vercel().*/adapter: node({ mode: "standalone" }),/' astro.config.ts && \
    sed -i '0,/service:[^,}]*/s//    service: passthroughImageService()/' astro.config.ts

# Build the application
RUN bun run build

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Minimal dependencies (no Sharp needed with passthrough image service)
RUN apk add --no-cache libc6-compat

# Copy built application from build stage
COPY --from=build /app/dist ./

# Copy node_modules from build stage
COPY --from=build /app/node_modules ./node_modules/

# Expose port 4321
EXPOSE 4321

ENV NODE_ENV=production

# Start the server
CMD ["node", "server/entry.mjs"]