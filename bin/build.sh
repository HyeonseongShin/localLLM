#!/bin/bash

# Rebuild Docker images for services that have local source code.
# Run this whenever you change files under rag-api/.
# After building, restart with: ./bin/start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Local LLM Build ==="
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit 1
fi

docker compose --project-directory "${PROJECT_ROOT}" build

echo ""
echo "Build complete. Run ./bin/start.sh to start."
