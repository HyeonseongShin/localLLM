#!/usr/bin/env python3
"""
Script to index PDF documents into Qdrant.

Usage:
  # Place a PDF in docs/ then run (container path: /data/docs/)
  docker exec rag-api python ingest.py /data/docs/document.pdf

  # Index all PDFs in docs/ at once
  for f in docs/*.pdf; do
    docker exec rag-api python ingest.py "/data/docs/$(basename $f)"
  done
"""

import logging
import os
import sys

from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")
QDRANT_URL = os.environ.get("QDRANT_URL", "http://qdrant:6333")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
COLLECTION_NAME = os.environ.get("QDRANT_COLLECTION", "documents")
VECTOR_SIZE = 768  # nomic-embed-text output dimension

CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200


def ingest(file_path: str) -> None:
    logger.info("Loading: %s", file_path)
    loader = PyPDFLoader(file_path)
    documents = loader.load()
    logger.info("Loaded %d page(s)", len(documents))

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
    )
    chunks = splitter.split_documents(documents)
    logger.info("Split into %d chunks", len(chunks))

    client = QdrantClient(url=QDRANT_URL)

    existing = {c.name for c in client.get_collections().collections}
    if COLLECTION_NAME not in existing:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
        )
        logger.info("Created collection: %s", COLLECTION_NAME)

    logger.info("Embedding with %s — this may take a while...", EMBED_MODEL)
    embeddings = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_BASE_URL)

    QdrantVectorStore.from_documents(
        documents=chunks,
        embedding=embeddings,
        url=QDRANT_URL,
        collection_name=COLLECTION_NAME,
    )
    logger.info("Done. Ingested %d chunks into '%s'.", len(chunks), COLLECTION_NAME)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ingest.py <file.pdf>", file=sys.stderr)
        sys.exit(1)
    ingest(sys.argv[1])
