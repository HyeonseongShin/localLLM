#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create .env from .env.example if it doesn't exist
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
  echo "[INFO] .env not found. Creating from .env.example..."
  cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
  echo "       Created .env with default values. Edit it to customize."
  echo ""
fi

# Load config from .env
set -o allexport
source "${SCRIPT_DIR}/.env"
set +o allexport

# Apply defaults if not set in .env
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
WEBUI_PORT="${WEBUI_PORT:-3000}"
DEFAULT_MODEL="${DEFAULT_MODEL:-gemma3:4b}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:${OLLAMA_PORT}}"
WEBUI_URL="http://localhost:${WEBUI_PORT}"
GPU=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --gpu) GPU=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: ./start.sh [--gpu]"; exit 1 ;;
  esac
done

echo "=== Local LLM Start ==="
echo "  GPU mode    : ${GPU}"
echo "  LLM model   : ${DEFAULT_MODEL}"
echo "  Embed model : ${EMBED_MODEL}"
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "[ERROR] Docker is not running. Please start Docker first."
  exit 1
fi

# Start containers
echo "[1/3] Starting containers..."
if [ "${GPU}" = true ]; then
  docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
else
  docker compose up -d
fi

# Wait for Ollama to be ready
echo "[2/3] Waiting for Ollama to be ready..."
until curl -s "${OLLAMA_URL}" > /dev/null 2>&1; do
  sleep 2
done

# Check and download models
echo "[3/3] Checking models..."

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
