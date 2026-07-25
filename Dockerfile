# Stage 1: Build Dependencies
FROM node:20-alpine AS builder
WORKDIR /app
COPY src/app/package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime Environment
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080

# Create non-root application user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -u 1001 -S nodejs -G nodejs

# Copy dependencies and application source
COPY --from=builder /app/node_modules ./node_modules
COPY src/app/package*.json ./
COPY src/app/index.js ./
COPY src/app/public ./public

# Set ownership to non-root user
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 8080

CMD ["node", "index.js"]
