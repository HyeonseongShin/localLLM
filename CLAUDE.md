# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A local LLM environment built on Docker + Ollama + Gemma3 + Open WebUI + SearXNG + RAG (Qdrant + LangChain).

| Component | Role | Port |
|-----------|------|------|
| Ollama | LLM runtime and model management (REST API) | 11434 |
| Gemma3 | Google lightweight open-source LLM model | - |
| Open WebUI | ChatGPT-style web UI | 3000 |
| SearXNG | Self-hosted web search backend for Open WebUI | 8088 |
| Qdrant | Vector database for RAG | 6333 |
| RAG API | FastAPI + LangServe RAG server (OpenAI-compatible) | 8000 |

## Commands

### Service Lifecycle
```bash
./bin/start.sh          # Start (CPU)
./bin/start.sh --gpu    # Start with NVIDIA GPU
./bin/stop.sh           # Stop containers (network preserved, fast restart)
./bin/stop.sh --down    # Remove containers and network (use after config changes)
./bin/reset_data.sh     # Interactively delete volume data
```

### RAG Indexing
```bash
# Place PDFs in rag-docs/ then run
./bin/index.sh

# Index a single file
docker exec rag-api python ingest.py /data/docs/document.pdf
```

### Model Management
```bash
docker exec ollama ollama list                    # List installed models
docker exec ollama ollama pull gemma3:12b         # Download a model
docker exec -it ollama ollama run gemma3:4b       # Chat via CLI
```

### Access URLs
- Open WebUI:      http://localhost:3000
- Ollama API:      http://localhost:11434
- SearXNG UI:      http://localhost:8088
- RAG API:         http://localhost:8000
- RAG Playground:  http://localhost:8000/rag/playground
- Qdrant UI:       http://localhost:6333/dashboard

## Configuration

All settings live in `.env` (gitignored). Created automatically from `.env.example` on first `./start.sh`.

| Variable | Default | Used by |
|----------|---------|---------|
| `OLLAMA_URL` | `http://localhost:11434` | `start.sh`, `ask.sh` |
| `OLLAMA_PORT` | `11434` | `docker-compose.yml`, `start.sh` |
| `SEARXNG_PORT` | `8088` | `docker-compose.yml` |
| `WEBUI_PORT` | `3000` | `docker-compose.yml`, `start.sh` |
| `WEBUI_NAME` | `Local AI` | `docker-compose.yml` → Open WebUI |
| `WEBUI_AUTH` | `true` | `docker-compose.yml` → Open WebUI |
| `ENABLE_RAG_WEB_SEARCH` | `true` | `docker-compose.yml` → Open WebUI |
| `DEFAULT_MODEL` | `gemma3:4b` | `start.sh`, `ask.sh`, `rag-api` |
| `EMBED_MODEL` | `nomic-embed-text` | `start.sh`, `rag-api` |
| `QDRANT_PORT` | `6333` | `docker-compose.yml` |
| `RAG_API_PORT` | `8000` | `docker-compose.yml` |
| `QDRANT_COLLECTION` | `documents` | `rag-api` |

`docker-compose.yml` reads `.env` automatically. `start.sh` and `ask.sh` source it explicitly before use.

## Architecture

```
Browser → Open WebUI (3000) → Ollama API (11434) → Gemma3 model
               ↓ web search            ↑ RAG answers
          SearXNG (8088)        RAG API (8000)
               ↑                   ↓         ↓
         ask.sh / ask.py       Qdrant (6333)  Ollama (11434)
                                vector search   LLM answer
```

- All services share a dedicated bridge network named `localllm`, isolated from other Docker containers on the host
- Open WebUI ↔ Ollama: internal Docker network via `OLLAMA_BASE_URL=http://ollama:11434`
- Open WebUI ↔ SearXNG: internal Docker network via `SEARXNG_QUERY_URL=http://searxng:8080/...`
- Open WebUI ↔ RAG API: internal Docker network via `http://rag-api:8000/v1` (OpenAI-compatible)
- RAG API ↔ Qdrant: internal Docker network via `QDRANT_URL=http://qdrant:6333`
- RAG API ↔ Ollama: internal Docker network via `OLLAMA_BASE_URL=http://ollama:11434`
- `ask.sh` connects to Ollama from the host via `OLLAMA_URL` in `.env`
- GPU config is isolated in `docker-compose.gpu.yml`, merged only when `--gpu` is passed to `start.sh`

## Docker Image Versions

Images are pinned to specific versions in `docker-compose.yml` to prevent unexpected breakage on updates.

| Image | Pinned Version |
|-------|---------------|
| `qdrant/qdrant` | `v1.17.1` |
| `searxng/searxng` | `2026.4.16-ae0b0e56a` |
| `ollama/ollama` | `0.20.7` |
| `ghcr.io/open-webui/open-webui` | `v0.8.12` |

## Models

`start.sh` downloads both models automatically on first run:

| Model | Purpose | Size |
|-------|---------|------|
| `gemma3:4b` (DEFAULT_MODEL) | Chat / answer generation | ~2-3 GB |
| `nomic-embed-text` (EMBED_MODEL) | Text embedding for RAG | ~300 MB |

> `nomic-embed-text` is embedding-only — do not select it as a chat model in Open WebUI.

## RAG API

Source lives in `services/rag-api/`. Built as a Docker image via `docker-compose.yml`.

| File | Role |
|------|------|
| `services/rag-api/main.py` | FastAPI app — LangServe routes + `/v1/chat/completions` |
| `services/rag-api/chain.py` | LCEL RAG chain (OllamaEmbeddings → Qdrant retriever → ChatOllama) |
| `services/rag-api/ingest.py` | PDF ingestion script |
| `services/rag-api/Dockerfile` | Container definition |
| `services/rag-api/requirements.txt` | Python dependencies |

**LangServe endpoints** (auto-generated):
- `POST /rag/invoke` — single invocation
- `POST /rag/stream` — streaming
- `GET  /rag/playground` — browser-based test UI

**OpenAI-compatible endpoints** (for Open WebUI):
- `GET  /v1/models`
- `POST /v1/chat/completions`

**Open WebUI connection is auto-configured at startup** via environment variables in `docker-compose.yml`:

```yaml
OPENAI_API_BASE_URLS=http://rag-api:8000/v1
OPENAI_API_KEYS=local
```

The `rag` model appears in the Open WebUI model picker automatically — no manual setup required.

> If the default `https://api.openai.com/v1` entry appears in Settings → Connections and causes errors, remove or disable it (it has no valid API key).

## RAG Document Indexing

Place PDF files in `rag-docs/` (gitignored, bind-mounted into `rag-api` at `/data/docs`).

```bash
cp ~/some_document.pdf rag-docs/
./bin/index.sh
```

`index.sh` iterates over all `*.pdf` files in `rag-docs/` and runs `ingest.py` for each.
The system works with an empty `rag-docs/` — queries simply return "I don't know" until documents are indexed.

## SearXNG

SearXNG config is a bind mount at `./services/searxng/settings.yml` (not a named Docker volume).
Key settings required for Open WebUI integration:

```yaml
server:
  limiter: false      # must be off — Open WebUI polls frequently
search:
  formats:
    - html
    - json            # must include json — Open WebUI queries with format=json
```

## CLI Query Tool

`ask.sh` sources `.env` then delegates to `bin/ask.py`.

```bash
./bin/ask.sh -p "Question"
./bin/ask.sh -m gemma3:12b -p "Question"        # Override model
./bin/ask.sh -s "System prompt" -p "Question"   # System prompt
./bin/ask.sh -f some_file.py -p "Question"      # Attach file as context
cat file | ./bin/ask.sh -p "Question"           # Pipe as context
./bin/ask.sh --no-stream -p "Question"          # No streaming
```

`ask.py` reads `OLLAMA_URL` and `DEFAULT_MODEL` from environment variables via `os.environ.get()`.
