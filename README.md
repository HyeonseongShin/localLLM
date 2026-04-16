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

The script automatically:
1. Starts Docker containers (with or without GPU)
2. Waits for Ollama to be ready
3. Downloads the Gemma3 model on first run (~2–3 GB)
4. Prints the access URL

### Access

Once the service is running, open your browser at:

```
http://localhost:3000
```

On first visit, create a local account (no external server connection).
Then select `gemma3:4b` from the model picker to start chatting.

## Model Options

| Model | RAM Required | Notes |
|-------|-------------|-------|
| `gemma3:2b` | 4 GB+ | Fast, good for simple conversations |
| `gemma3:4b` | 8 GB+ | Balanced — default |
| `gemma3:12b` | 16 GB+ | Higher quality |
| `gemma3:27b` | 32 GB+ | Best quality |

To change the default model, edit the `MODEL` variable in `start.sh`.

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

All options:

| Option | Description |
|--------|-------------|
| `-p` | Prompt to send (required) |
| `-m` | Model to use (default: `gemma3:4b`) |
| `-s` | System prompt |
| `-f` | Attach a file as context |
| `--no-stream` | Print full response at once instead of streaming |

## Manual Commands

```bash
# Start / stop services
docker compose up -d
docker compose down

# Follow logs
docker compose logs -f

# Pull an additional model
docker exec ollama ollama pull gemma3:12b

# Chat via CLI
docker exec -it ollama ollama run gemma3:4b

# List installed models
docker exec ollama ollama list
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
