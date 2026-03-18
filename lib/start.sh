#!/bin/bash
# Start script for mock OLT - runs SSH server and FastAPI in parallel

# Start SSH server
/usr/sbin/sshd

# Start FastAPI server with HTTPS (self-signed cert)
exec uvicorn app:app --host 0.0.0.0 --port 443 --ssl-keyfile=/app/server.key --ssl-certfile=/app/server.crt
