# Local LLM

A local LLM environment built on Docker + Ollama + Gemma3 + Open WebUI + SearXNG.
Run AI conversations entirely on your own machine, with optional web search via SearXNG.

## Stack

| Component | Role | Port |
|-----------|------|------|
| Ollama | LLM runtime and model management | 11434 |
| Gemma3 | Google open-source LLM model | - |
| Open WebUI | ChatGPT-style web interface | 3000 |
| SearXNG | Self-hosted web search engine (used by Open WebUI) | 8088 |

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

### Run

```bash
# CPU only
./start.sh

# With NVIDIA GPU
./start.sh --gpu
```

`start.sh` automatically:
1. Creates `.env` from `.env.example` if it does not exist
2. Starts Docker containers (with or without GPU)
3. Waits for Ollama to be ready
4. Downloads the Gemma3 model on first run (~2–3 GB)
5. Prints the access URL

### Stop

```bash
./stop.sh
```

### Access

Once the service is running, open your browser at:

```
http://localhost:3000   — Open WebUI
http://localhost:8088   — SearXNG (optional, direct access)
```

On first visit, create a local account (no external server connection).
Then select `gemma3:4b` from the model picker to start chatting.

## Configuration

All settings are stored in `.env`. It is created automatically on first run from `.env.example`.

```bash
# .env (key variables)
OLLAMA_PORT=11434
OLLAMA_URL=http://localhost:11434
SEARXNG_PORT=8088
WEBUI_PORT=3000
WEBUI_NAME="Local AI"
DEFAULT_MODEL=gemma3:4b
```

Both `docker-compose.yml` and the shell scripts read from this file, so changing a value here applies everywhere.

### Open WebUI settings

The following variables are injected into Open WebUI at startup:

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBUI_NAME` | `Local AI` | Title shown in the browser tab and header |
| `WEBUI_AUTH` | `true` | Enable login (set `false` to skip login) |
| `ENABLE_SIGNUP` | `true` | Allow new account registration |
| `DEFAULT_USER_ROLE` | `user` | Role assigned to new users |
| `ENABLE_MESSAGE_RATING` | `true` | Show thumbs up/down on responses |
| `ENABLE_COMMUNITY_SHARING` | `false` | Disable sharing to Open WebUI community |
| `ENABLE_RAG_WEB_SEARCH` | `true` | Enable web search feature |

## Web Search (SearXNG)

Open WebUI uses SearXNG as its web search backend. SearXNG runs as a local container — no external search API key is needed.

**How it works:**

```
Open WebUI → searxng:8080 (internal Docker network) → external search engines
```

**Enable web search in a chat:**

Click the globe icon (🌐) in the chat input bar to toggle web search for that conversation.

**SearXNG configuration** is stored in `searxng/settings.yml` (bind-mounted into the container). The file is version-controlled, so changes persist across `./stop.sh` / `./start.sh` cycles.

> For production use, replace `secret_key` in `searxng/settings.yml` with a random string:
> ```bash
> python3 -c "import secrets; print(secrets.token_hex(32))"
> ```

## CLI Query Tool

Query Ollama directly from the terminal with `ask.sh`.

```bash
# Basic question
./ask.sh -p "Explain Docker volumes in one sentence"

# Choose a different model
./ask.sh -m gemma3:12b -p "Write a Python quicksort"

# Set a system prompt
./ask.sh -s "You are a Linux expert" -p "Best practice for secret management?"

# Attach a file as context
./ask.sh -f docker-compose.yml -p "What does this do?"

# Pipe content as context
cat error.log | ./ask.sh -p "What is wrong here?"

# Get the full response at once (no streaming)
./ask.sh --no-stream -p "Give me a detailed explanation of DNS"
```

| Option | Description |
|--------|-------------|
| `-p` | Prompt to send (required) |
| `-m` | Model to use (default: `gemma3:4b`) |
| `-s` | System prompt |
| `-f` | Attach a file as context |
| `--no-stream` | Print full response at once instead of streaming |

## Model Options

| Model | RAM Required | Notes |
|-------|-------------|-------|
| `gemma3:2b` | 4 GB+ | Fast, good for simple conversations |
| `gemma3:4b` | 8 GB+ | Balanced — default |
| `gemma3:12b` | 16 GB+ | Higher quality |
| `gemma3:27b` | 32 GB+ | Best quality |

To change the default model, update `DEFAULT_MODEL` in `.env`.

### Adding More Models

Pull any additional model while Ollama is running:

```bash
docker exec ollama ollama pull qwen2.5:7b
docker exec ollama ollama pull llama3.2:3b
```

Newly downloaded models appear automatically in the Open WebUI model picker — no restart needed.

### Using Multiple Models Simultaneously

Open WebUI supports side-by-side comparison. In a chat, click the model name at the top and press `+` to add a second model. The same prompt is sent to both and responses are shown in parallel.

Recommended two-model combination for 32 GB RAM:

| Model | Strength |
|-------|----------|
| `gemma3:4b` | General conversation |
| `qwen2.5:7b` | Korean language, coding |

## Data Management

### Reset data

```bash
./reset_data.sh
```

Prompts you to choose what to delete:

```
1) Open WebUI only  (accounts, chat history)
2) Models only      (downloaded Ollama models)
3) Everything       (WebUI + models)
```

> SearXNG has no persistent volume — its config lives in `searxng/settings.yml` and is not affected by reset.

### Inspect volumes

```bash
# List volumes
docker volume ls

# Browse Ollama model files
docker exec -it ollama sh
ls /root/.ollama/models

# Browse Open WebUI data
docker exec -it open-webui sh
ls /app/backend/data

# Inspect a volume without running containers
docker run --rm -v locallm_ollama_data:/data alpine ls /data

# List installed models
docker exec ollama ollama list
```

## Manual Commands

```bash
# Follow logs
docker compose logs -f

# Pull an additional model
docker exec ollama ollama pull gemma3:12b

# Chat via CLI
docker exec -it ollama ollama run gemma3:4b
```

## GPU Acceleration (NVIDIA)

Install [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on the host, then pass the `--gpu` flag at startup:

```bash
./start.sh --gpu
```

GPU settings are defined in `docker-compose.gpu.yml` and merged at runtime only when `--gpu` is specified.

## Accessing from Windows (WSL2)

If running inside WSL2, try `http://localhost:3000` in your Windows browser first.
On most modern Windows builds, port forwarding is automatic.

If that does not work, run the following in an **elevated PowerShell**:

```powershell
# Find your WSL2 IP
wsl hostname -I

# Forward port 3000 to WSL2
netsh interface portproxy add v4tov4 `
  listenport=3000 listenaddress=0.0.0.0 `
  connectport=3000 connectaddress=<WSL_IP>

# Allow through firewall
netsh advfirewall firewall add rule `
  name="WSL2 Open WebUI" protocol=TCP `
  dir=in action=allow localport=3000
```
