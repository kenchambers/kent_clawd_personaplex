FROM --platform=linux/amd64 nvidia/cuda:12.4.1-runtime-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tbilisi

# Install system dependencies (single layer to reduce image size)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3-pip git curl libopus-dev unzip nginx jq \
    chromium-browser chromium-codecs-ffmpeg \
    fonts-liberation libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 libgbm1 \
    libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 libasound2 libpangocairo-1.0-0 \
    && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set Chromium path for Moltbot browser tool
ENV CHROME_PATH=/usr/bin/chromium-browser

# Ensure npm global packages are in PATH (critical for moltbot at runtime)
ENV PATH="/usr/local/bin:$PATH"

# Create python symlink (python3.11 is installed, but scripts expect 'python')
RUN ln -sf /usr/bin/python3.11 /usr/bin/python && ln -sf /usr/bin/python3.11 /usr/bin/python3

# Install rclone for Supabase Storage sync
RUN curl -fsSL https://rclone.org/install.sh | bash

# Install GitHub CLI for autonomous PR workflow
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Install Moltbot and verify installation
# Set npm prefix to /usr/local for consistent global bin path across npm versions
RUN npm config set prefix /usr/local \
    && npm install -g moltbot@latest && npm cache clean --force \
    && echo "Verifying moltbot installation:" \
    && which moltbot \
    && moltbot --version

# Install AI coding assistants for autonomous development
RUN npm install -g @anthropic-ai/claude-code @google/gemini-cli && npm cache clean --force

# Upgrade pip and setuptools to fix Ubuntu 22.04's install_layout bug
RUN pip install --upgrade pip setuptools wheel

# Clone and install PersonaPlex (note: package is in moshi/ subdirectory)
RUN git clone --depth 1 https://github.com/nvidia/personaplex.git /opt/personaplex \
    && cd /opt/personaplex && pip install --no-cache-dir moshi/. \
    && rm -rf /opt/personaplex/.git

# Build PersonaPlex client
WORKDIR /opt/personaplex/client
RUN npm install && npm run build && npm cache clean --force

# Install orchestrator dependencies (rarely changes - cache this layer)
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Moltbot bootstrap files (changes less frequently)
COPY moltbot/ ./moltbot/

# Copy nginx config for reverse proxy
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy orchestrator code (changes more frequently - near end for better caching)
COPY orchestrator/ ./orchestrator/

# Copy startup and sync scripts (changes most frequently - at end)
COPY scripts/start.sh scripts/workspace_sync.sh ./
RUN chmod +x start.sh workspace_sync.sh

# Port 8998: nginx reverse proxy (external entry point)
# Routes: /health, /api/* -> orchestrator:5000, /* -> personaplex:8999
EXPOSE 8998

# Moltbot workspace directory
# NOTE: SaladCloud provides local disk (e.g., 100GB) but it's EPHEMERAL.
# Data persists during normal operation but is lost on node reallocation.
# For true persistence across reallocations, integrate cloud storage (S3/GCS).
VOLUME ["/root/clawd"]

# Health check via nginx reverse proxy (required for SaladCloud container gateway)
# start-period=300s allows time for PersonaPlex model download (~7GB) on first run
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD curl -f http://127.0.0.1:8998/health || exit 1

# Environment variables (set via SaladCloud portal or API)
# HF_TOKEN - Required for PersonaPlex model access
# ANTHROPIC_API_KEY - Required for LLM command extraction
# MOLTBOT_WORKSPACE - Workspace path (default: ~/clawd)
# PERSONAPLEX_VOICE - Voice model (default: NATM1)
# WHATSAPP_PHONE - For notifications
# PERSONAPLEX_URL - Public URL for WhatsApp links
#
# Supabase Storage (for workspace persistence):
# SUPABASE_S3_ENDPOINT - e.g., https://<project>.supabase.co/storage/v1/s3
# SUPABASE_S3_ACCESS_KEY - From Supabase Dashboard > Storage > S3 Access Keys
# SUPABASE_S3_SECRET_KEY - From Supabase Dashboard > Storage > S3 Access Keys
# SUPABASE_BUCKET - Bucket name (default: moltbot-workspace)
# SYNC_INTERVAL - Seconds between backups (default: 300)

CMD ["./start.sh"]
