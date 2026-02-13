FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable

WORKDIR /app

# Install Playwright dependencies for Chromium
RUN apt-get update &&     DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends  jq  libnss3     libnspr4     libatk1.0-0     libatk-bridge2.0-0     libcups2     libdrm2     libxkbcommon0     libxcomposite1     libxdamage1     libxfixes3     libxrandr2     libgbm1     libasound2     libpango-1.0-0     libcairo2     libatspi2.0-0     libgtk-3-0     && apt-get clean &&     rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then       apt-get update &&       DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES &&       apt-get clean &&       rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*;     fi

RUN curl -fsSL https://tailscale.com/install.sh | sh

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# Install Playwright CLI and browsers (Chromium only)
RUN npm install -g playwright && playwright install chromium

# Create symlink so openclaw can find Chromium at standard Linux path
RUN ln -sf /root/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome /usr/bin/chromium

ENV NODE_ENV=production
ENV PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright

# Allow non-root user to write temp files during runtime/tests.
RUN chown -R node:node /app

# Create directories for Tailscale state
RUN mkdir -p /var/lib/tailscale /var/run/tailscale

# Copy and set up the startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh


# Note: Running as root is required for Tailscale to manage network interfaces.
# The node application runs under the start.sh wrapper.
# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
CMD ["start.sh"]
