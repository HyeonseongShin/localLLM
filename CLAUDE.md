# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A local LLM environment built on Docker + Ollama + Gemma3 + Open WebUI + SearXNG.

| Component | Role |
|-----------|------|
| Ollama | LLM runtime and model management (REST API: port 11434) |
| Gemma3 | Google lightweight open-source LLM model |
| Open WebUI | ChatGPT-style web UI (port 3000) |
| SearXNG | Self-hosted web search backend for Open WebUI (port 8088) |

## Commands

### Service Lifecycle
```bash
./start.sh          # Start (CPU)
./start.sh --gpu    # Start with NVIDIA GPU
./stop.sh           # Stop all containers
./reset_data.sh     # Interactively delete volume data
```

### Model Management
```bash
docker exec ollama ollama list                    # List installed models
docker exec ollama ollama pull gemma3:12b         # Download a model
docker exec -it ollama ollama run gemma3:4b       # Chat via CLI
```

### Access URLs
- Open WebUI: http://localhost:3000
- Ollama API: http://localhost:11434
- SearXNG UI: http://localhost:8088

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
| `DEFAULT_MODEL` | `gemma3:4b` | `start.sh`, `ask.sh` |

`docker-compose.yml` reads `.env` automatically. `start.sh` and `ask.sh` source it explicitly before use.

## Architecture

```
Browser → Open WebUI (3000) → Ollama API (11434) → Gemma3 model
               ↓ web search
          SearXNG (8088) → external search engines
               ↑
         ask.sh / ask.py (host → Ollama direct)
```

- Open WebUI ↔ Ollama communicate over Docker's internal network via `OLLAMA_BASE_URL=http://ollama:11434`
- Open WebUI ↔ SearXNG communicate over Docker's internal network via `SEARXNG_QUERY_URL=http://searxng:8080/...`
- `ask.sh` connects to Ollama from the host via `OLLAMA_URL` in `.env`
- GPU config is isolated in `docker-compose.gpu.yml`, merged only when `--gpu` is passed to `start.sh`

## SearXNG

SearXNG config is a bind mount at `./searxng/settings.yml` (not a named Docker volume).
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

`ask.sh` sources `.env` then delegates to `scripts/ask.py`.

```bash
./ask.sh -p "Question"
./ask.sh -m gemma3:12b -p "Question"        # Override model
./ask.sh -s "System prompt" -p "Question"   # System prompt
./ask.sh -f some_file.py -p "Question"      # Attach file as context
cat file | ./ask.sh -p "Question"           # Pipe as context
./ask.sh --no-stream -p "Question"          # No streaming
```

`ask.py` reads `OLLAMA_URL` and `DEFAULT_MODEL` from environment variables via `os.environ.get()`.
