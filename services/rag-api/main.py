import logging
import time

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from langserve import add_routes
from pydantic import BaseModel
from typing import List

from chain import get_rag_chain

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _build_chain_with_retry(retries: int = 10, delay: float = 3.0):
    """Retry chain initialization since Qdrant / Ollama containers may not be ready yet."""
    for attempt in range(1, retries + 1):
        try:
            return get_rag_chain()
        except Exception as exc:
            if attempt == retries:
                raise
            logger.warning(
                "Services not ready (attempt %d/%d): %s — retrying in %.0fs",
                attempt, retries, exc, delay,
            )
            time.sleep(delay)


rag_chain = _build_chain_with_retry()

app = FastAPI(title="RAG API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# LangServe: auto-generates /rag/invoke, /rag/stream, /rag/playground
add_routes(app, rag_chain, path="/rag")


# ── OpenAI-compatible endpoints for Open WebUI integration ───────────────────

class Message(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str = "rag"
    messages: List[Message]
    stream: bool = False


@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [{"id": "rag", "object": "model", "owned_by": "local"}],
    }


@app.post("/v1/chat/completions")
async def chat_completions(req: ChatRequest):
    question = req.messages[-1].content
    answer = rag_chain.invoke(question)
    return {
        "id": "chatcmpl-rag",
        "object": "chat.completion",
        "model": "rag",
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": answer},
                "finish_reason": "stop",
            }
        ],
    }
