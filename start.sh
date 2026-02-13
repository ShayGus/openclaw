#!/bin/sh
set -e

# Start tailscaled in the background
tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &

# Wait for tailscaled to be ready
sleep 2

# Support both TAILSCALE_AUTH_KEY and TS_AUTHKEY for compatibility
AUTH_KEY="${TAILSCALE_AUTH_KEY:-$TS_AUTHKEY}"

# Authenticate with Tailscale if auth key is provided
if [ -n "$AUTH_KEY" ]; then
  tailscale up --authkey="$AUTH_KEY" --hostname="${TAILSCALE_HOSTNAME:-${FLY_APP_NAME:-openclaw-gateway}}"

  # Set up Tailscale serve to proxy to the gateway port
  tailscale serve --bg 18789
fi

# Clean up stale Chrome lock files from previous container instances
rm -f /home/node/.openclaw/browser/*/user-data/SingletonLock       /home/node/.openclaw/browser/*/user-data/SingletonSocket       /home/node/.openclaw/browser/*/user-data/SingletonCookie 2>/dev/null || true

# Execute the main application
exec node dist/index.js gateway --bind "${OPENCLAW_GATEWAY_BIND:-lan}" --port 18789
