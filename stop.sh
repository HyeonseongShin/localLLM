#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOWN=false

for arg in "$@"; do
  case $arg in
    --down) DOWN=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: ./stop.sh [--down]"; exit 1 ;;
  esac
done

echo "=== Local LLM Stop ==="

if [ "${DOWN}" = true ]; then
  echo "  Mode: down (removing containers and network)"
  docker compose --project-directory "${SCRIPT_DIR}" down
else
  echo "  Mode: stop (containers paused, network preserved)"
  docker compose --project-directory "${SCRIPT_DIR}" stop
fi

echo "Done."
