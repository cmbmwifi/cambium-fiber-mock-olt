#!/bin/bash
# Start script for mock OLT - runs SSH server and FastAPI in parallel

# Verify the API container is reachable on the shared network
if ! getent hosts cambium-fiber-api &>/dev/null; then
    echo "ERROR: Cannot reach 'cambium-fiber-api' on this network." >&2
    echo "" >&2
    echo "  These mock OLTs were installed against API version ${API_VERSION}." >&2
    echo "" >&2
    echo "  If the Cambium Fiber API container is stopped, start it and then" >&2
    echo "  restart this container." >&2
    echo "" >&2
    echo "  If the API has been upgraded to a newer version, reinstall the mock OLTs" >&2
    echo "  to connect them to the new version:" >&2
    echo "    curl -fsSL https://raw.githubusercontent.com/cmbmwifi/cambium-fiber-mock-olt/main/uninstall.sh | bash" >&2
    echo "    curl -fsSL https://raw.githubusercontent.com/cmbmwifi/cambium-fiber-mock-olt/main/install.sh | bash" >&2
    exit 1
fi

# Start SSH server
/usr/sbin/sshd

# Start FastAPI server with HTTPS (self-signed cert)
exec uvicorn app:app --host 0.0.0.0 --port 443 --ssl-keyfile=/app/server.key --ssl-certfile=/app/server.crt
