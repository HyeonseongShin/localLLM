#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Local LLM Data Reset ==="
echo ""
echo "What would you like to reset?"
echo "  1) Open WebUI only  (accounts, chat history)"
echo "  2) Models only      (downloaded Ollama models)"
echo "  3) Qdrant only      (RAG vector index)"
echo "  4) Everything       (WebUI + models + Qdrant)"
echo ""
read -r -p "Choose (1/2/3/4): " choice

case "${choice}" in
  1) target="webui" ;;
  2) target="models" ;;
  3) target="qdrant" ;;
  4) target="all" ;;
  *) echo "Invalid choice. Cancelled."; exit 1 ;;
esac

echo ""
case "${target}" in
  webui)   echo "This will permanently delete Open WebUI accounts and chat history." ;;
  models)  echo "This will permanently delete all downloaded Ollama models." ;;
  qdrant)  echo "This will permanently delete the Qdrant vector index. Documents in docs/ are not affected." ;;
  all)     echo "This will permanently delete Open WebUI data, downloaded models, and the Qdrant vector index." ;;
esac
echo ""
read -r -p "Are you sure? (yes/N): " confirm

if [ "${confirm}" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "[1/2] Stopping containers..."
docker compose --project-directory "${PROJECT_ROOT}" down

echo "[2/2] Removing volumes..."
case "${target}" in
  webui)
    docker volume rm locallm_open_webui_data
    ;;
  models)
    docker volume rm locallm_ollama_data
    ;;
  qdrant)
    docker volume rm locallm_qdrant_data
    ;;
  all)
    docker volume rm locallm_ollama_data locallm_open_webui_data locallm_qdrant_data
    ;;
esac

echo ""
echo "Done. Run ./bin/start.sh to restart."
