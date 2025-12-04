#!/bin/bash
set -e

echo "🚀 Deploying clean ayunis-legal-mcp to VPS..."

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Clean up any existing deployment
echo "🧹 Cleaning up existing deployment..."
cd /root
if [ -d "ayunis-legal-mcp-clean" ]; then
    rm -rf ayunis-legal-mcp-clean
fi

# Stop and remove existing containers
echo "🛑 Stopping existing containers..."
docker compose down --remove-orphans 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Clone clean repository
echo "📥 Cloning clean repository..."
git clone https://github.com/uni61182/ayunis-legal-mcp-Fork.git ayunis-legal-mcp-clean
cd ayunis-legal-mcp-clean

# Create production .env file
echo "⚙️ Creating production .env file..."
cat > .env << 'EOF'
# Database Configuration
POSTGRES_DB=legaldb
POSTGRES_USER=legaluser
POSTGRES_PASSWORD=legalpass
POSTGRES_HOST=legal-mcp-postgres

# Store API Configuration
STORE_API_HOST=legal-mcp-store-api
STORE_API_PORT=8000

# MCP Configuration
MCP_TRANSPORT=http
MCP_PORT=8889

# Ollama Configuration
OLLAMA_HOST=http://localhost:11434
OLLAMA_BASE_URL=http://localhost:11434

# Legal API Configuration  
LEGAL_API_BASE_URL=http://localhost:8888

# Production URLs
DOMAIN=legalmcp.duckdns.org
STORE_URL=https://legalmcp.duckdns.org
MCP_URL=https://legalmcp.duckdns.org/mcp
EOF

# Start PostgreSQL first
echo "🐘 Starting PostgreSQL..."
docker compose up -d legal-mcp-postgres
sleep 10

# Run database migrations
echo "🔄 Running database migrations..."
docker compose run --rm legal-mcp-store-api alembic upgrade head

# Start all services
echo "🌟 Starting all services..."
docker compose up -d

# Check if Ollama is running, start if needed
if ! curl -s http://localhost:11434/api/version > /dev/null; then
    echo "🤖 Starting Ollama service..."
    systemctl restart ollama
    sleep 10
fi

# Pull required models if not present
echo "📚 Ensuring Ollama models are available..."
ollama pull qwen2.5-coder:1.5b
ollama pull mxbai-embed-large

# Setup MCP systemd service
echo "⚡ Setting up MCP systemd service..."
cat > /etc/systemd/system/legal-mcp.service << 'EOF'
[Unit]
Description=Legal MCP Server
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/ayunis-legal-mcp-clean
Environment=MCP_TRANSPORT=http
Environment=MCP_PORT=8889
Environment=LEGAL_API_BASE_URL=http://localhost:8888
ExecStart=/usr/local/bin/python3 -m mcp.server.main
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable legal-mcp.service
systemctl start legal-mcp.service

# Setup Caddy reverse proxy
echo "🌐 Setting up Caddy reverse proxy..."
cat > /etc/caddy/Caddyfile << 'EOF'
legalmcp.duckdns.org {
    reverse_proxy /mcp* localhost:8889
    reverse_proxy localhost:8888
    
    header {
        Access-Control-Allow-Origin *
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
    
    log {
        output file /var/log/caddy/legalmcp.log
    }
}
EOF

systemctl restart caddy

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Test all endpoints
echo "🧪 Testing services..."
echo "Store API Health: $(curl -s http://localhost:8888/health || echo 'FAILED')"
echo "MCP Server Health: $(curl -s http://localhost:8889/health || echo 'FAILED')"
echo "Ollama Health: $(curl -s http://localhost:11434/api/version || echo 'FAILED')"

# Show service status
echo "📊 Service Status:"
systemctl status legal-mcp.service --no-pager -l
docker compose ps

echo ""
echo "✅ Deployment completed!"
echo "🌍 Services available at:"
echo "   - Store API: https://legalmcp.duckdns.org"
echo "   - MCP Server: https://legalmcp.duckdns.org/mcp"
echo "   - Local Store API: http://localhost:8888"
echo "   - Local MCP: http://localhost:8889"
echo ""
echo "🚀 Ready for import! Run:"
echo "   docker compose run --rm legal-mcp-store-api python -m app.scrapers.gesetze_im_internet.catalog import-all"