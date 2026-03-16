#!/bin/bash
# Atomic Red Team Runner — Entrypoint
# Keeps the container alive and ready to accept test execution commands
# Tests are triggered via: docker exec mdr-atomic-runner atomic-operator run --technique T1003.001

echo "[MDR Demo Lab] Atomic Red Team Runner ready"
echo "[MDR Demo Lab] ART definitions at: /opt/atomic-red-team/atomics/"
echo "[MDR Demo Lab] Run a test: docker exec mdr-atomic-runner atomic-operator run --technique TXXXX"

# Keep container alive
tail -f /dev/null
