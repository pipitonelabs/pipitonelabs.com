# Build stage
FROM oven/bun:1 AS build

WORKDIR /app

# Install system dependencies for Sharp (using apt for Debian-based image)
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    libvips-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure Sharp to use bundled libvips
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1

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
RUN sed -i '2a import node from "@astrojs/node";' astro.config.ts && \
    sed -i 's/adapter: vercel(),/adapter: node({ mode: "standalone" }),/' astro.config.ts

# Build the application
RUN bun run build

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Install Sharp runtime dependencies for Alpine
RUN apk add --no-cache vips

# Copy built application and dependencies from build stage
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules/

# Expose port 4321
EXPOSE 4321

# Start the server
CMD ["node", "dist/server/entry.mjs"]