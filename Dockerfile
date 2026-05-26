# ============================================================================
# Surypus ERP/CRM Docker Configuration
# ============================================================================
# Multi-stage build for production with optimized caching

# Stage 1: Build environment
FROM haskell:9.12.4 AS builder

# Install build dependencies and PostgreSQL dev libraries
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy lock file and cabal files first - enables better caching of dependencies
COPY stack.yaml stack.yaml.lock* ./
COPY Surypus.cabal ./
COPY surypus-common/surypus-common.cabal surypus-common/
COPY surypus-api/surypus-api.cabal surypus-api/
COPY surypus-api-shim/surypus-api-shim.cabal surypus-api-shim/

# Pre-install dependencies (cached)
RUN stack setup --install-ghc && stack build --only-dependencies

# Copy project source files
COPY surypus-common surypus-common/
COPY surypus-api surypus-api/
COPY surypus-api-shim surypus-api-shim/
COPY src ./src
COPY app ./app
COPY config ./config

# Build with optimizations
RUN stack build --install-ghc --copy-bins \
    --ghc-options="-O2 -j4"

# Stage 2: Production runtime (minimal)
FROM debian:bookworm-slim

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    ca-certificates \
    curl \
    dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user
RUN groupadd -r surypus && useradd -r -g surypus surypus

WORKDIR /app

# Copy binary from builder
COPY --from=builder /root/.local/bin/surypus-api /usr/local/bin/surypus

# Create runtime directories
RUN mkdir -p /app/config /app/logs \
    && chown -R surypus:surypus /app

# Copy OPA policies if exists
RUN test -d opa/policies && cp -r opa/policies /app/opa/ || true

# Switch to non-root user
USER surypus

# Environment variables
ENV PORT=3000
ENV DB_HOST=postgres
ENV DB_PORT=5432
ENV DB_NAME=surypus
ENV DB_USER=surypus
ENV DB_PASSWORD=surypus_secret
ENV OPA_URL=http://opa:8181

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Run with dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["surypus"]