#!/usr/bin/env bash
# detect-labops.sh
# Checks if the LabOps Docker network and key services exist.
# Returns "labops" or "standalone" to stdout.

if docker network inspect labops-net >/dev/null 2>&1; then
  echo "labops"
else
  echo "standalone"
fi
