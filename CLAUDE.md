# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A local LLM environment built on Docker + Ollama + Gemma3 + Open WebUI.

| Component | Role |
|-----------|------|
| Ollama | LLM runtime and model management (REST API: port 11434) |
| Gemma3 | Google lightweight open-source LLM model |
| Open WebUI | ChatGPT-style web UI (port 3000) |

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

## Configuration

All settings live in `.env` (gitignored). Created automatically from `.env.example` on first `./start.sh`.

| Variable | Default | Used by |
|----------|---------|---------|
| `OLLAMA_URL` | `http://localhost:11434` | `start.sh`, `ask.sh` |
| `OLLAMA_PORT` | `11434` | `docker-compose.yml`, `start.sh` |
| `WEBUI_PORT` | `3000` | `docker-compose.yml`, `start.sh` |
| `DEFAULT_MODEL` | `gemma3:4b` | `start.sh`, `ask.sh` |

`docker-compose.yml` reads `.env` automatically. `start.sh` and `ask.sh` source it explicitly before use.

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

## Architecture

```
Browser → Open WebUI (3000) → Ollama API (11434) → Gemma3 model
                                     ↑
                               ask.sh / ask.py
```

- Open WebUI ↔ Ollama communicate over Docker's internal network via `OLLAMA_BASE_URL=http://ollama:11434`
- `ask.sh` connects to Ollama from the host via `OLLAMA_URL` in `.env`
- GPU config is isolated in `docker-compose.gpu.yml`, merged only when `--gpu` is passed to `start.sh`
