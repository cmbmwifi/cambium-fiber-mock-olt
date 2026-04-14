#!/bin/bash
set -e

INSTALL_DIR="${MOCK_OLT_DIR:-/opt/cambium-fiber-mock-olt}"
API_COMPOSE="/opt/cambium-fiber-api/docker-compose.yml"
GITHUB_REPO="cmbmwifi/cambium-fiber-mock-olt"
RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases"

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

# --- Detect API version ---
API_VERSION=$(docker inspect cambium-fiber-api \
    --format '{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null || true)
if [ -z "$API_VERSION" ]; then
    echo "ERROR: Could not detect API version from cambium-fiber-api image label." >&2
    echo "       Ensure the Cambium Fiber API container is running and properly tagged." >&2
    exit 1
fi

echo "==> Using API version: $API_VERSION"

# --- Create install dir ---
if [ ! -d "$INSTALL_DIR" ]; then
    if [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
        sudo mkdir -p "$INSTALL_DIR"
        sudo chown "${USER}:${USER}" "$INSTALL_DIR"
    else
        mkdir -p "$INSTALL_DIR"
    fi
fi

# --- Download docker-compose.yml ---
echo "==> Downloading docker-compose.yml"
curl -fsSL "${RAW_BASE}/docker-compose.yml" -o "$INSTALL_DIR/docker-compose.yml"

# --- Download and load Docker image ---
RELEASE_TAG="v${API_VERSION}"
TARBALL_URL="${RELEASE_BASE}/download/${RELEASE_TAG}/cambium-fiber-mock-olt-${RELEASE_TAG}.tar.gz"
echo "==> Downloading mock OLT image (${RELEASE_TAG})..."
tmp_tar=$(mktemp)
if ! curl -fsSL "$TARBALL_URL" -o "$tmp_tar"; then
    echo "ERROR: Failed to download image tarball from:" >&2
    echo "       $TARBALL_URL" >&2
    echo "       Check that release ${RELEASE_TAG} exists." >&2
    rm -f "$tmp_tar"
    exit 1
fi
echo "==> Loading Docker image..."
docker load -i "$tmp_tar"
rm -f "$tmp_tar"

# --- Write .env ---
printf 'COMPOSE_PROJECT_NAME=cambium-fiber-api\nAPI_VERSION=%s\nMOCK_OLT_IMAGE=cambium-fiber-mock-olt:%s\n' \
    "$API_VERSION" "$RELEASE_TAG" > "$INSTALL_DIR/.env"

# --- Start mock OLTs ---
echo "==> Starting mock OLT containers"
cd "$INSTALL_DIR"
docker compose up -d

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
