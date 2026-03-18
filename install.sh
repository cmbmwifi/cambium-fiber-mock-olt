#!/bin/bash
set -e

REPO_URL="https://github.com/cmbmwifi/cambium-fiber-mock-olt.git"
INSTALL_DIR="${MOCK_OLT_DIR:-/opt/cambium-fiber-mock-olt}"
API_COMPOSE="/opt/cambium-fiber-api/docker-compose.yml"

echo "==> Cambium Fiber Mock OLT Setup"

# --- Prerequisites check ---
if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is not installed." >&2
    exit 1
fi
if ! docker compose version &>/dev/null; then
    echo "ERROR: docker compose plugin is not installed." >&2
    exit 1
fi
if [ ! -f "$API_COMPOSE" ]; then
    echo "ERROR: Cambium Fiber API is not installed at /opt/cambium-fiber-api." >&2
    echo "       Install it first: https://github.com/cmbmwifi/cambium-fiber-api" >&2
    exit 1
fi

if ! docker inspect cambium-fiber-api &>/dev/null; then
    echo "ERROR: Cambium Fiber API is installed but not running." >&2
    echo "       Start it first, then re-run this installer." >&2
    exit 1
fi

# --- Create install dir (with sudo if /opt isn't writable) ---
if [ ! -d "$INSTALL_DIR" ]; then
    if [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
        sudo mkdir -p "$INSTALL_DIR"
        sudo chown "${USER}:${USER}" "$INSTALL_DIR"
    else
        mkdir -p "$INSTALL_DIR"
    fi
fi

# --- Clone or update repo ---
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "==> Updating existing repo at $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "==> Cloning repo to $INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# --- Start mock OLTs ---
echo "==> Starting mock OLT containers"
cd "$INSTALL_DIR"

# Detect the network the API container is on and write it to .env
API_NETWORK=$(docker inspect cambium-fiber-api \
    --format '{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}' 2>/dev/null | head -1)
if [ -z "$API_NETWORK" ]; then
    echo "WARNING: Could not detect API network — using default 'cambium-fiber-api_default'" >&2
    API_NETWORK="cambium-fiber-api_default"
fi

# Detect the API version to keep container names in sync
API_VERSION=$(docker inspect cambium-fiber-api \
    --format '{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null || true)
if [ -z "$API_VERSION" ]; then
    echo "ERROR: Could not detect API version from cambium-fiber-api image label." >&2
    echo "       Ensure the Cambium Fiber API container is running and properly tagged." >&2
    exit 1
fi
COMPOSE_PROJECT_NAME="cambium-fiber-api_${API_VERSION//./-}"

printf 'API_NETWORK=%s\nCOMPOSE_PROJECT_NAME=%s\nAPI_VERSION=%s\n' \
    "$API_NETWORK" "$COMPOSE_PROJECT_NAME" "$API_VERSION" > "$INSTALL_DIR/.env"
echo "==> Using API network: $API_NETWORK"
echo "==> Using API version: $API_VERSION"

docker compose up -d --build

echo ""
echo "==> Done! Open the Cambium Fiber API setup wizard and add these OLTs:"
echo ""
echo "   Hostname       HTTPS Port   SSH Port"
echo "   mock-olt-631   443          22"
echo "   mock-olt-632   443          22"
echo "   mock-olt-633   443          22"
echo "   mock-olt-634   443          22"
echo "   mock-olt-635   443          22"
echo "   mock-olt-636   443          22"
echo ""
echo "   Credential group — Username: admin  Password: password"
