# Stage 1: Build Dependencies
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime Environment
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080

# Create application user for security (Least Privilege)
RUN addgroup -g 1001 -S nodejs && \
    adduser -u 1001 -S nodejs -G nodejs

# Copy dependencies and application source
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY index.js ./
COPY public ./public

# Set ownership to non-root user
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 8080

CMD ["node", "index.js"]
