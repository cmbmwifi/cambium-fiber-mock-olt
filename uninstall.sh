#!/bin/bash
set -e

INSTALL_DIR="${MOCK_OLT_DIR:-/opt/cambium-fiber-mock-olt}"

echo "==> Cambium Fiber Mock OLT Uninstall"

# --- Remove containers, images, and volumes ---
if [ -d "$INSTALL_DIR" ]; then
    echo "==> Removing mock OLT containers, images, and volumes"
    cd "$INSTALL_DIR"
    docker compose down --rmi all --volumes 2>/dev/null || true
    echo "==> Removing $INSTALL_DIR"
    if [ ! -w "$(dirname "$INSTALL_DIR")" ]; then
        sudo rm -rf "$INSTALL_DIR"
    else
        rm -rf "$INSTALL_DIR"
    fi
else
    echo "==> $INSTALL_DIR not found — stopping containers by project name"
    PROJECT=$(docker ps --filter "name=cambium-fiber-api-mock-olt" --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | head -1 || true)
    if [ -n "$PROJECT" ]; then
        docker compose -p "$PROJECT" down --rmi all --volumes
    else
        echo "WARNING: Could not detect running mock OLT project — nothing removed" >&2
    fi
fi

echo "==> Uninstall complete"
