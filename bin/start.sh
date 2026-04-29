#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Create .env from .env.example if it doesn't exist
if [ ! -f "${PROJECT_ROOT}/.env" ]; then
  echo "[INFO] .env not found. Creating from .env.example..."
  cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"
  echo "       Created .env with default values. Edit it to customize."
  echo ""
fi

# Load config from .env
set -o allexport
source "${PROJECT_ROOT}/.env"
set +o allexport

# Apply defaults if not set in .env
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
WEBUI_PORT="${WEBUI_PORT:-3000}"
DEFAULT_MODEL="${DEFAULT_MODEL:-gemma3:4b}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:${OLLAMA_PORT}}"
WEBUI_URL="http://localhost:${WEBUI_PORT}"
GPU=false
BUILD=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --gpu)   GPU=true ;;
    --build) BUILD=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: ./bin/start.sh [--gpu] [--build]"; exit 1 ;;
  esac
done

echo "=== Local LLM Start ==="
echo "  GPU mode    : ${GPU}"
echo "  Build       : ${BUILD}"
echo "  LLM model   : ${DEFAULT_MODEL}"
echo "  Embed model : ${EMBED_MODEL}"
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit 1
fi

# Compute step counter
STEP=0
TOTAL_STEPS=$([ "${BUILD}" = true ] && echo 4 || echo 3)

# Install host tools on --build
if [ "${BUILD}" = true ]; then
  STEP=$((STEP+1))
  echo "[${STEP}/${TOTAL_STEPS}] Installing host tools..."
  pip install oterm --upgrade --quiet
  echo "      oterm: $(oterm --version 2>/dev/null || echo 'installed')"
  echo ""
fi

# Start containers
STEP=$((STEP+1))
echo "[${STEP}/${TOTAL_STEPS}] Starting containers..."
if [ "${GPU}" = true ]; then
  docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -f "${PROJECT_ROOT}/docker-compose.gpu.yml" up -d ${BUILD:+--build}
else
  docker compose -f "${PROJECT_ROOT}/docker-compose.yml" up -d ${BUILD:+--build}
fi

# Wait for Ollama to be ready
STEP=$((STEP+1))
echo "[${STEP}/${TOTAL_STEPS}] Waiting for Ollama to be ready..."
until curl -s "${OLLAMA_URL}" > /dev/null 2>&1; do
  sleep 2
done

# Check and download models
STEP=$((STEP+1))
echo "[${STEP}/${TOTAL_STEPS}] Checking models..."

if docker exec ollama ollama list | grep -q "${DEFAULT_MODEL%:*}"; then
  echo "      ${DEFAULT_MODEL}: already installed."
else
  echo "      Downloading ${DEFAULT_MODEL} (~2-3 GB, please wait)..."
  docker exec ollama ollama pull "${DEFAULT_MODEL}"
fi

if docker exec ollama ollama list | grep -q "${EMBED_MODEL%:*}"; then
  echo "      ${EMBED_MODEL}: already installed."
else
  echo "      Downloading ${EMBED_MODEL} (~300 MB, please wait)..."
  docker exec ollama ollama pull "${EMBED_MODEL}"
fi

echo ""
echo "=== Ready ==="
echo "  Open WebUI : ${WEBUI_URL}"
echo "  Ollama API : ${OLLAMA_URL}"
echo ""
echo "Open ${WEBUI_URL} in your browser."
