# ==============================================================================
# Dockerfile for Cluster Manager Web Platform (appz)
# ==============================================================================
FROM node:22-alpine AS builder

WORKDIR /app

# Copy dependency specifications
COPY package*.json ./
RUN npm install

# Copy source code and build production assets
COPY . .
RUN npm run build

# Runtime Stage
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV SIMULATOR=false

# Install production dependencies & tsx execution runner
COPY package*.json ./
RUN npm install --omit=dev && npm install tsx

# Copy built frontend assets and server entry point
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server.ts ./server.ts
COPY --from=builder /app/index.html ./index.html

# Expose web service port
EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["npx", "tsx", "server.ts"]
