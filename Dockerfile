# ============================================================================
# Surypus ERP/CRM Docker Configuration
# ============================================================================
# Multi-stage build for production

# Stage 1: Build environment
FROM haskell:9.6.6 AS builder

WORKDIR /build

# Copy stack files first for better caching
COPY stack.yaml stack.yaml.lock ./
COPY Surypus.cabal ./

# Install dependencies
RUN stack setup

# Copy source and build
COPY src ./src
COPY test ./test

# Build production executable
RUN stack build --install-ghc --copy-bins

# Stage 2: Production runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r surypus && useradd -r -g surypus surypus

WORKDIR /app

# Copy binary from builder
COPY --from=builder /root/.local/bin/surypus /usr/local/bin/
COPY --from=builder /root/.local/bin/surypus-job-worker /usr/local/bin/

# Create runtime directories
RUN mkdir -p /app/config /app/logs && chown -R surypus:surypus /app

# Switch to non-root user
USER surypus

# Environment variables
ENV PORT=8080
ENV DB_HOST=localhost
ENV DB_PORT=5432
ENV DB_NAME=surypus
ENV DB_USER=postgres
ENV DB_PASSWORD=

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/v1/health || exit 1

# Run the application
CMD ["surypus"]