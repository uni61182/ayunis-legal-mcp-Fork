#!/bin/bash
set -e

echo "🔥 COMPLETE VPS RESET - This will delete EVERYTHING!"
echo "⚠️  This will remove all Docker containers, images, volumes and data"
echo "⚠️  Press Ctrl+C within 10 seconds to abort..."
sleep 10

echo "🛑 Stopping all services..."
systemctl stop legal-mcp.service 2>/dev/null || true
systemctl disable legal-mcp.service 2>/dev/null || true
systemctl stop caddy 2>/dev/null || true
systemctl stop ollama 2>/dev/null || true
systemctl stop docker 2>/dev/null || true

echo "🗑️ Removing all Docker containers, images and volumes..."
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker rmi $(docker images -aq) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network prune -f 2>/dev/null || true
docker system prune -af 2>/dev/null || true

echo "🧹 Removing all project directories..."
cd /root
rm -rf ayunis-legal-mcp* 2>/dev/null || true
rm -rf .docker* 2>/dev/null || true
rm -rf /var/lib/docker/* 2>/dev/null || true

echo "🔧 Removing systemd services..."
rm -f /etc/systemd/system/legal-mcp.service
rm -f /etc/systemd/system/ollama.service
systemctl daemon-reload

echo "🌐 Resetting Caddy..."
rm -f /etc/caddy/Caddyfile
cat > /etc/caddy/Caddyfile << 'EOF'
# Default Caddyfile - empty
EOF

echo "🗃️ Cleaning Ollama data..."
rm -rf /usr/share/ollama/.ollama/* 2>/dev/null || true
rm -rf ~/.ollama/* 2>/dev/null || true

echo "🔄 Restarting Docker service..."
systemctl start docker
systemctl enable docker

echo "🚀 Starting fresh deployment..."
echo "📥 Cloning clean repository..."
git clone https://github.com/uni61182/ayunis-legal-mcp-Fork.git ayunis-legal-mcp
cd ayunis-legal-mcp

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

echo "🐘 Starting PostgreSQL..."
docker compose up -d legal-mcp-postgres
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 15

echo "🔄 Running database migrations..."
docker compose run --rm legal-mcp-store-api alembic upgrade head

echo "🌟 Starting all services..."
docker compose up -d

echo "🤖 Setting up Ollama..."
systemctl start ollama
sleep 10

# Download required models
echo "📚 Downloading Ollama models..."
ollama pull mxbai-embed-large
ollama pull qwen2.5-coder:1.5b

echo "⚡ Setting up MCP systemd service..."
cat > /etc/systemd/system/legal-mcp.service << 'EOF'
[Unit]
Description=Legal MCP Server
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/ayunis-legal-mcp
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

systemctl start caddy
systemctl enable caddy

echo "⏳ Waiting for all services to start..."
sleep 20

echo "🧪 Testing services..."
echo "🐘 PostgreSQL: $(docker compose exec legal-mcp-postgres pg_isready -U legaluser -d legaldb 2>/dev/null || echo 'FAILED')"
echo "🚀 Store API: $(curl -s http://localhost:8888/health | grep -o 'ok' || echo 'FAILED')"
echo "⚡ MCP Server: $(curl -s http://localhost:8889/health || echo 'FAILED')"
echo "🤖 Ollama: $(curl -s http://localhost:11434/api/version | grep -o 'version' || echo 'FAILED')"

echo "📊 Final Status:"
systemctl status legal-mcp.service --no-pager -l | head -10
docker compose ps
echo ""
echo "✅ COMPLETE RESET AND DEPLOYMENT FINISHED!"
echo ""
echo "🌍 Services available at:"
echo "   - Store API: https://legalmcp.duckdns.org"
echo "   - MCP Server: https://legalmcp.duckdns.org/mcp"
echo ""
echo "🚀 Ready for import! Run:"
echo "   docker compose run --rm legal-mcp-store-api python -m app.scrapers.gesetze_im_internet.catalog import-all"