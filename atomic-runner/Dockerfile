# Atomic Red Team Runner
# Lightweight ARM64 container holding ART test definitions
# PowerShell tests execute on the Windows victim endpoint via CALDERA agent
# Linux-compatible ART tests can run directly in this container

FROM ubuntu:22.04

LABEL maintainer="MDR Demo Lab"
LABEL description="Atomic Red Team test runner and definition store"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    jq \
    net-tools \
    nmap \
    && rm -rf /var/lib/apt/lists/*

# SSH server for browser-based terminal access via Guacamole
RUN apt-get update && apt-get install -y openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && echo 'root:atomic' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Clone Atomic Red Team test definitions
RUN git clone --depth=1 https://github.com/redcanaryco/atomic-red-team.git /opt/atomic-red-team

# Install invoke-atomicredteam Python helper (for Linux-compatible tests)
RUN pip3 install atomic-operator

WORKDIR /opt/art

# Results output directory
RUN mkdir -p /opt/art/results /opt/art/tests

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
