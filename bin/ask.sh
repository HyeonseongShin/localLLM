#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load config from .env
if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -o allexport
  source "${PROJECT_ROOT}/.env"
  set +o allexport
fi

python3 "${SCRIPT_DIR}/ask.py" "$@"
