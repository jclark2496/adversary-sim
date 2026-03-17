#!/bin/bash
# Atomic Red Team Runner — Entrypoint
# SSH enabled for browser-based terminal access via Guacamole
# Tests are triggered via: docker exec advsim-atomic atomic-operator run --technique T1003.001

echo "[Adversary Sim] Atomic Red Team Runner ready"
echo "[Adversary Sim] ART definitions at: /opt/atomic-red-team/atomics/"
echo "[Adversary Sim] SSH: root@172.20.0.40 (password: atomic)"

# Start SSH daemon
/usr/sbin/sshd

# Keep container alive
tail -f /dev/null
