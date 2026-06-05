# ============================================================================
# Surypus ERP/CRM Docker Configuration
# ============================================================================
# Multi-stage build for production with optimized caching
# Library first, then executable linked against it

# Stage 1: Build environment
FROM haskell:9.6 AS builder

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

# Pre-install dependencies (cached)
RUN stack setup --install-ghc && stack build --only-dependencies

# Copy project source files
COPY surypus-common surypus-common/
COPY surypus-api surypus-api/
COPY src ./src
COPY app ./app
COPY config ./config
COPY web ./web

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
COPY --from=builder /root/.local/bin/surypus-server /usr/local/bin/surypus-server

# Copy web assets
COPY --from=builder /build/web ./web

# Environment variables
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

# Run with dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["surypus-server"]
