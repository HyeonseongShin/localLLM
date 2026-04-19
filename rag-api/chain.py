import os
import logging

from langchain_ollama import ChatOllama, OllamaEmbeddings
from langchain_qdrant import QdrantVectorStore
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

logger = logging.getLogger(__name__)

OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")
QDRANT_URL = os.environ.get("QDRANT_URL", "http://qdrant:6333")
EMBED_MODEL = os.environ.get("EMBED_MODEL", "nomic-embed-text")
LLM_MODEL = os.environ.get("DEFAULT_MODEL", "gemma3:4b")
COLLECTION_NAME = os.environ.get("QDRANT_COLLECTION", "documents")
VECTOR_SIZE = 768  # nomic-embed-text output dimension

PROMPT = ChatPromptTemplate.from_template(
    "Answer the question based on the context below.\n"
    "If the context does not contain relevant information, say you don't know.\n\n"
    "Context:\n{context}\n\n"
    "Question: {question}\n\n"
    "Answer:"
)


def _ensure_collection(client: QdrantClient) -> None:
    existing = {c.name for c in client.get_collections().collections}
    if COLLECTION_NAME not in existing:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE),
        )
        logger.info("Created Qdrant collection: %s", COLLECTION_NAME)


def get_rag_chain():
    logger.info("Connecting to Qdrant at %s", QDRANT_URL)
    client = QdrantClient(url=QDRANT_URL)
    _ensure_collection(client)

    embeddings = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_BASE_URL)
    vectorstore = QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
        embedding=embeddings,
    )
    retriever = vectorstore.as_retriever(search_kwargs={"k": 4}).with_config(
        run_name="qdrant-retriever",
        tags=["retrieval"],
    )
    llm = ChatOllama(model=LLM_MODEL, base_url=OLLAMA_BASE_URL)

    chain = (
        {
            "context": retriever | (lambda docs: "\n\n".join(d.page_content for d in docs)),
            "question": RunnablePassthrough(),
        }
        | PROMPT
        | llm
        | StrOutputParser()
    )
    logger.info("RAG chain ready (llm=%s, embed=%s, collection=%s)", LLM_MODEL, EMBED_MODEL, COLLECTION_NAME)
    return chain.with_config(
        run_name="localllm-rag-chain",
        tags=["rag", f"llm:{LLM_MODEL}", f"embed:{EMBED_MODEL}", f"collection:{COLLECTION_NAME}"],
    )
