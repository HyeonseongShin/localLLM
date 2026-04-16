# Local LLM

A local LLM environment built on Docker + Ollama + Gemma3 + Open WebUI.
Run AI conversations entirely offline without any internet connection.

## Stack

| Component | Role | Port |
|-----------|------|------|
| Ollama | LLM runtime and model management | 11434 |
| Gemma3 | Google open-source LLM model | - |
| Open WebUI | ChatGPT-style web interface | 3000 |

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
http://localhost:3000
```

On first visit, create a local account (no external server connection).
Then select `gemma3:4b` from the model picker to start chatting.

## Configuration

All settings are stored in `.env`. It is created automatically on first run from `.env.example`.

```bash
# .env
OLLAMA_PORT=11434
OLLAMA_URL=http://localhost:11434
WEBUI_PORT=3000
DEFAULT_MODEL=gemma3:4b
```

Both `docker-compose.yml` and the shell scripts read from this file, so changing a value here applies everywhere.

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
