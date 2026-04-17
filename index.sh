#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="${SCRIPT_DIR}/docs"

# Load config from .env
if [ -f "${SCRIPT_DIR}/.env" ]; then
  set -o allexport
  source "${SCRIPT_DIR}/.env"
  set +o allexport
fi

echo "=== RAG Indexing ==="
echo "  Docs dir : ${DOCS_DIR}"
echo ""

# Check rag-api container is running
if ! docker ps --format '{{.Names}}' | grep -q "^rag-api$"; then
  echo "[ERROR] rag-api container is not running. Start it first with: ./start.sh"
  exit 1
fi

# Collect PDF files
mapfile -t pdfs < <(find "${DOCS_DIR}" -maxdepth 1 -name "*.pdf" | sort)

if [ ${#pdfs[@]} -eq 0 ]; then
  echo "[INFO] No PDF files found in docs/. Place PDF files there and try again."
  exit 0
fi

echo "Found ${#pdfs[@]} PDF file(s):"
for pdf in "${pdfs[@]}"; do
  echo "  - $(basename "${pdf}")"
done
echo ""

# Index each PDF
success=0
failed=0

for pdf in "${pdfs[@]}"; do
  filename="$(basename "${pdf}")"
  echo "[$(( success + failed + 1 ))/${#pdfs[@]}] Indexing: ${filename}"

  if docker exec rag-api python ingest.py "/data/docs/${filename}"; then
    (( success++ )) || true
  else
    echo "  [FAILED] ${filename}"
    (( failed++ )) || true
  fi
  echo ""
done

echo "=== Done ==="
echo "  Succeeded : ${success}"
if [ ${failed} -gt 0 ]; then
  echo "  Failed    : ${failed}"
fi
