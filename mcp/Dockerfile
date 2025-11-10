# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY ./mcp/server ./server

# Note: client_example.py is intentionally excluded (not required for server operation)

# Expose port for MCP server
EXPOSE 8001

# Run the MCP server
CMD ["python", "-m", "server.main"]

