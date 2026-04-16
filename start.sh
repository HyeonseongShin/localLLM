#!/bin/bash

set -e

MODEL="gemma3:4b"
OLLAMA_URL="http://localhost:11434"
WEBUI_URL="http://localhost:3000"
GPU=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --gpu) GPU=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: ./start.sh [--gpu]"; exit 1 ;;
  esac
done

echo "=== Local LLM Start ==="
echo "  GPU mode : ${GPU}"
echo "  Model    : ${MODEL}"
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

# Check and download model
echo "[3/3] Checking model: ${MODEL}"
if docker exec ollama ollama list | grep -q "${MODEL%:*}"; then
  echo "      Already installed."
else
  echo "      Downloading (~2-3 GB, please wait)..."
  docker exec ollama ollama pull "${MODEL}"
fi

echo ""
echo "=== Ready ==="
echo "  Open WebUI : ${WEBUI_URL}"
echo "  Ollama API : ${OLLAMA_URL}"
echo ""
echo "Open ${WEBUI_URL} in your browser."
