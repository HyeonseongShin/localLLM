#!/usr/bin/env python3

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
DEFAULT_MODEL = os.environ.get("DEFAULT_MODEL", "gemma3:4b")


def stream_chat(model, messages):
    payload = {"model": model, "messages": messages, "stream": True}
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as response:
        for line in response:
            chunk = json.loads(line.decode())
            if not chunk.get("done"):
                print(chunk["message"]["content"], end="", flush=True)
    print()


def chat(model, messages):
    payload = {"model": model, "messages": messages, "stream": False}
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode())
        print(result["message"]["content"])


def build_prompt(args):
    parts = []

    # Attach file content as context
    if args.file:
        try:
            with open(args.file, "r") as f:
                content = f.read()
            parts.append(f"[File: {args.file}]\n```\n{content}\n```")
        except FileNotFoundError:
            print(f"[ERROR] File not found: {args.file}", file=sys.stderr)
            sys.exit(1)

    # Read from stdin if piped (e.g. cat error.log | ask.sh -p "...")
    if not sys.stdin.isatty():
        stdin_content = sys.stdin.read().strip()
        if stdin_content:
            parts.append(stdin_content)

    if args.prompt:
        parts.append(args.prompt)

    if not parts:
        return None

    return "\n\n".join(parts)


def main():
    parser = argparse.ArgumentParser(
        description="Query a local Ollama LLM from the command line.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""
examples:
  ask.sh -p "Explain Docker volumes"
  ask.sh -m gemma3:12b -p "Write a Python quicksort"
  ask.sh -s "You are a Linux expert" -p "Best practice for secrets?"
  ask.sh -f docker-compose.yml -p "What does this do?"
  cat error.log | ask.sh -p "What is wrong?"
  ask.sh --no-stream -p "Give me a long explanation"
        """,
    )
    parser.add_argument("-p", "--prompt", help="Prompt to send")
    parser.add_argument(
        "-m", "--model", default=DEFAULT_MODEL,
        help=f"Model to use (default: {DEFAULT_MODEL})"
    )
    parser.add_argument("-s", "--system", help="System prompt")
    parser.add_argument("-f", "--file", help="Attach a file as context")
    parser.add_argument(
        "--no-stream", action="store_true",
        help="Wait for the full response instead of streaming"
    )

    args = parser.parse_args()

    prompt = build_prompt(args)
    if not prompt:
        parser.print_help()
        sys.exit(1)

    messages = []
    if args.system:
        messages.append({"role": "system", "content": args.system})
    messages.append({"role": "user", "content": prompt})

    try:
        if args.no_stream:
            chat(args.model, messages)
        else:
            stream_chat(args.model, messages)
    except urllib.error.URLError:
        print("[ERROR] Cannot connect to Ollama. Is it running?", file=sys.stderr)
        print("  Start with: ./start.sh", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
