FROM python:3.12-slim

WORKDIR /app

# Install OpenSSH server, curl, and openssl for self-signed certs
RUN apt-get update && apt-get install -y openssh-server sudo curl openssl && \
    mkdir -p /var/run/sshd && \
    rm -rf /var/lib/apt/lists/*

# Create admin user with password 'password'
# Root password remains unset (SSH root login disabled by default)
RUN useradd -m -s /bin/bash admin && \
    echo 'admin:password' | chpasswd && \
    # Allow admin to run camb_conf without password
    echo 'admin ALL=(ALL) NOPASSWD: /usr/local/bin/camb_conf' >> /etc/sudoers

# Copy requirements and install dependencies
COPY lib/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy mock OLT server code (pre-compiled .so files — source not included)
COPY lib/app.cpython-312-x86_64-linux-gnu.so .
COPY lib/ssh_handler.cpython-312-x86_64-linux-gnu.so .
COPY lib/mock_cli.cpython-312-x86_64-linux-gnu.so .
COPY lib/camb_conf.cpython-312-x86_64-linux-gnu.so .
COPY lib/start.sh .
RUN sed -i 's/\r$//' start.sh && chmod +x start.sh

# ssh_handler launcher — wraps compiled module, invoked by debug shell script
RUN printf '#!/usr/bin/env python3\nfrom ssh_handler import main\nmain()\n' > /app/ssh_handler.py && \
    chmod +x /app/ssh_handler.py

# camb_conf launcher — wraps compiled module, installed as system command
RUN printf '#!/usr/bin/env python3\nimport sys\nsys.path.insert(0, "/app")\nfrom camb_conf import main\nmain()\n' > /usr/local/bin/camb_conf && \
    chmod +x /usr/local/bin/camb_conf

# Thin launcher — calls compiled module; this becomes the admin shell
RUN printf '#!/usr/bin/env python3\nfrom mock_cli import main\nmain()\n' > /app/mock_cli_launcher && \
    chmod +x /app/mock_cli_launcher

# Create mock shell commands
# debug command delegates to ssh_handler.py
RUN echo '#!/bin/bash' > /usr/local/bin/debug && \
    echo 'if [ "$1" = "su" ]; then' >> /usr/local/bin/debug && \
    echo '  /app/ssh_handler.py debug_su' >> /usr/local/bin/debug && \
    echo 'fi' >> /usr/local/bin/debug && \
    chmod +x /usr/local/bin/debug && \
    # Make camb_conf available as root command (for debug su scenario)
    ln -s /usr/local/bin/camb_conf /root/camb_conf

# Copy fixtures from parent directory
COPY fixtures /app/fixtures

# Generate self-signed certificate for HTTPS
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /app/server.key -out /app/server.crt \
    -subj "/C=US/ST=State/L=City/O=Mock OLT/CN=mock-olt"

# Configure SSH to use our custom shell handler
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'UsePAM no' >> /etc/ssh/sshd_config && \
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set admin user's shell to our compiled mock CLI launcher
RUN usermod -s /app/mock_cli_launcher admin

# Expose ports 22 (SSH) and 443 (HTTPS)
EXPOSE 22 443

# Run start script (SSH + FastAPI)
CMD ["/app/start.sh"]
