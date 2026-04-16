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

### Start / Stop
```bash
docker compose up -d          # Run in background
docker compose down           # Stop
docker compose logs -f        # Follow logs
```

### Model Management
```bash
# Download model (first time only)
docker exec ollama ollama pull gemma3:4b

# Other model options
docker exec ollama ollama pull gemma3:2b   # Lightweight (RAM 4GB+)
docker exec ollama ollama pull gemma3:12b  # Higher quality (RAM 16GB+)

# List installed models
docker exec ollama ollama list

# Chat via CLI
docker exec -it ollama ollama run gemma3:4b
```

### Access URLs
- Open WebUI: http://localhost:3000
- Ollama API: http://localhost:11434

## GPU Support (NVIDIA)

Pass `--gpu` to the start script. GPU settings are defined in `docker-compose.gpu.yml`
and merged at runtime only when the flag is provided.

```bash
./start.sh          # CPU only
./start.sh --gpu    # With NVIDIA GPU
```

## CLI Query Tool

`ask.sh` wraps `scripts/ask.py` and queries Ollama from the terminal.

```bash
./ask.sh -p "Your question"
./ask.sh -m gemma3:12b -p "Question"
./ask.sh -s "System prompt" -p "Question"
./ask.sh -f some_file.py -p "What does this do?"
cat file | ./ask.sh -p "Question about this content"
./ask.sh --no-stream -p "Question"
```

Core logic lives in `scripts/ask.py`. `ask.sh` is a thin wrapper that resolves
the script path and forwards all arguments to Python.

## Architecture

```
Browser → Open WebUI (3000) → Ollama API (11434) → Gemma3 model
```

Open WebUI and Ollama communicate over Docker's internal network,
connected via the `OLLAMA_BASE_URL` environment variable.
