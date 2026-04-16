# ── Stage 1: Install dependencies ──
FROM node:22-alpine AS deps
WORKDIR /app
COPY app/package*.json ./
RUN npm ci --omit=dev

# ── Stage 2: Production image ──
FROM node:22-alpine
WORKDIR /app

# Copy dependencies from stage 1
COPY --from=deps /app/node_modules ./node_modules

# Copy application code
COPY app/server.js ./

# Set environment
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Run as non-root user
USER node

# Start the app
CMD ["node", "server.js"]
