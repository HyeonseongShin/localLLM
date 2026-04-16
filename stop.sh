#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Local LLM Stop ==="

docker compose --project-directory "${SCRIPT_DIR}" down

echo "Done."
