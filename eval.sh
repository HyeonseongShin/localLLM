#!/usr/bin/env bash
# RAG 응답 품질 빠른 평가 — start.sh 이후 실행
# 사용: ./eval.sh
# 커스텀 쿼리: QUERIES=("질문1" "질문2") ./eval.sh
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && source .env

RAG_API_PORT=${RAG_API_PORT:-8000}
RAG_URL="http://localhost:${RAG_API_PORT}"

echo "Waiting for RAG API at ${RAG_URL}..."
until curl -sf "${RAG_URL}/v1/models" > /dev/null 2>&1; do
  sleep 3
done
echo "RAG API ready."
echo ""

# 테스트 쿼리 목록 — 실제 인덱싱된 문서에 맞게 교체하세요
DEFAULT_QUERIES=(
  "What is retrieval augmented generation?"
  "What vector database does this system use?"
  "Which embedding model is used for document indexing?"
  "What LLM generates the final answer?"
)
QUERIES=("${QUERIES[@]:-${DEFAULT_QUERIES[@]}}")

PASS=0
FAIL=0

for Q in "${QUERIES[@]}"; do
  PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'input': sys.argv[1]}))" "$Q")
  ANSWER=$(
    curl -sf -X POST "${RAG_URL}/rag/invoke" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('output',''))" 2>/dev/null \
    || echo ""
  )

  if [ -n "$ANSWER" ]; then
    echo "[PASS] Q: $Q"
    echo "       A: $(echo "$ANSWER" | head -c 200)"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] Q: $Q  →  empty or error response"
    FAIL=$((FAIL + 1))
  fi
  echo ""
done

echo "=== Eval Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
