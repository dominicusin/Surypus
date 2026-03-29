# ============================================================================
# Surypus ERP/CRM Docker Configuration
# ============================================================================
# Multi-stage build for production

# Stage 1: Build environment
FROM haskell:9.6.6 AS builder

# Install PostgreSQL 14 development libraries from source
# (required for hasql-1.10.3 which uses PostgreSQL 14+ pipeline features)
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    && cd /tmp \
    && wget https://ftp.postgresql.org/pub/source/v14.11/postgresql-14.11.tar.gz \
    && tar -xzf postgresql-14.11.tar.gz \
    && cd postgresql-14.11 \
    && ./configure --prefix=/usr/local/pgsql14 --without-icu \
    && make -j$(nproc) \
    && make install \
    && cd / && rm -rf /tmp/postgresql-14.11* \
    && echo "/usr/local/pgsql14/lib" > /etc/ld.so.conf.d/pgsql14.conf \
    && ldconfig

WORKDIR /build

# Set PostgreSQL 14 path
ENV PATH="/usr/local/pgsql14/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/pgsql14/lib:$LD_LIBRARY_PATH"
ENV PG_CONFIG="/usr/local/pgsql14/bin/pg_config"

# Copy stack files first for better caching
COPY stack.yaml stack.yaml.lock ./
COPY Surypus.cabal ./

# Install dependencies
RUN stack setup

# Copy source and build
COPY src ./src
COPY app ./app
COPY test ./test

# Build production executable
RUN stack build --install-ghc --copy-bins

# Stage 2: Production runtime
FROM debian:bookworm-slim

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libpq5 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r surypus && useradd -r -g surypus surypus

WORKDIR /app

# Copy binary from builder
COPY --from=builder /root/.local/bin/surypus /usr/local/bin/

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