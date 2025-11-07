FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
COPY rag-api-requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -r rag-api-requirements.txt

# Copy RAG system code
COPY rag_system.py .
COPY rag_api.py .

# Copy vector store files (if including in image)
# Alternatively, download from GCS on startup
COPY drug_rag_output/ drug_rag_output/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the API
CMD ["python", "rag_api.py"]
