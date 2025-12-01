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
RUN sed -i '1a import node from "@astrojs/node";' astro.config.ts && \
    sed -i 's/adapter: vercel(),/adapter: node({ mode: "standalone" }),/' astro.config.ts

# Build the application
RUN bun run build

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Install Sharp dependencies for Alpine
RUN apk add --no-cache \
    vips-dev \
    fftw-dev \
    build-base \
    libc6-compat \
    python3

# Copy built application from build stage
COPY --from=build /app/dist ./

# Copy package.json for reinstalling sharp
COPY --from=build /app/package.json ./

# Reinstall Sharp for Alpine (critical - Debian binaries don't work on Alpine)
RUN npm install sharp --platform=linuxmusl --arch=x64

# Expose port 4321
EXPOSE 4321

# Enable verbose debug logging for image processing issues
ENV NODE_ENV=development
ENV DEBUG=*
ENV NODE_DEBUG=module,http
ENV NODE_OPTIONS="--trace-warnings --unhandled-rejections=strict"

# Start the server with error logging wrapper
CMD ["sh", "-c", "node server/entry.mjs 2>&1 | tee /dev/stderr"]