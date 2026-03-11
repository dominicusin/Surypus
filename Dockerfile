FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install GHC and Stack
RUN curl --proto '=https' --tlsv1.2 -sSf https://get.haskellstack.org/ | sh

# Set working directory
WORKDIR /app

# Copy project
COPY . .

# Build
RUN stack build

# Expose port
EXPOSE 8080

# Run
CMD ["stack", "exec", "surypus"]