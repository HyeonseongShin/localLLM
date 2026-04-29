#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DOWN=false

for arg in "$@"; do
  case $arg in
    --down) DOWN=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: ./bin/stop.sh [--down]"; exit 1 ;;
  esac
done

echo "=== Local LLM Stop ==="

if [ "${DOWN}" = true ]; then
  echo "  Mode: down (removing containers and network)"
  docker compose --project-directory "${PROJECT_ROOT}" down
else
  echo "  Mode: stop (containers paused, network preserved)"
  docker compose --project-directory "${PROJECT_ROOT}" stop
fi

echo "Done."
