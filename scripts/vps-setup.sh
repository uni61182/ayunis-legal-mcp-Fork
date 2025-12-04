#!/bin/bash
# ===========================================
# VPS Setup Script für German Legal MCP Server
# IONOS VPS Linux L (6 vCores, 8GB RAM, Ubuntu)
# ===========================================

set -e

echo "=========================================="
echo "German Legal MCP Server - VPS Setup"
echo "=========================================="

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. System Updates
echo -e "${YELLOW}[1/8] System Updates...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git python3 python3-pip python3-venv

# 2. Docker installieren
echo -e "${YELLOW}[2/8] Docker installieren...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installiert. Bitte neu einloggen für Docker-Rechte!${NC}"
fi

# Docker Compose Plugin
sudo apt install -y docker-compose-plugin

# 3. Ollama installieren
echo -e "${YELLOW}[3/8] Ollama installieren...${NC}"
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Ollama als Service starten
sudo systemctl enable ollama
sudo systemctl start ollama

# Warten bis Ollama bereit ist
echo "Warte auf Ollama..."
sleep 5

# Embedding-Modell herunterladen
echo -e "${YELLOW}[4/8] Embedding-Modell herunterladen (~2.5GB)...${NC}"
ollama pull ryanshillington/Qwen3-Embedding-4B:latest

# 4. Repository klonen
echo -e "${YELLOW}[5/8] Repository klonen...${NC}"
cd ~
if [ ! -d "ayunis-legal-mcp" ]; then
    git clone https://github.com/uni61182/ayunis-legal-mcp-Fork.git ayunis-legal-mcp
fi
cd ayunis-legal-mcp

# 5. Python Environment
echo -e "${YELLOW}[6/8] Python Environment einrichten...${NC}"
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 6. Docker Services starten
echo -e "${YELLOW}[7/8] Docker Services starten...${NC}"
docker compose up -d

# Warten auf PostgreSQL
echo "Warte auf PostgreSQL..."
sleep 15

# Datenbank-Migration
docker compose exec -T store-api alembic upgrade head

# 7. Systemd Service für MCP Server erstellen
echo -e "${YELLOW}[8/8] MCP Server Service einrichten...${NC}"
sudo tee /etc/systemd/system/legal-mcp.service > /dev/null <<EOF
[Unit]
Description=German Legal MCP Server
After=network.target docker.service ollama.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/ayunis-legal-mcp/mcp
Environment="LEGAL_API_BASE_URL=http://localhost:8888"
Environment="MCP_TRANSPORT=http"
Environment="MCP_PORT=8889"
ExecStart=$HOME/ayunis-legal-mcp/.venv/bin/python -m server.main
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable legal-mcp
sudo systemctl start legal-mcp

echo ""
echo -e "${GREEN}=========================================="
echo "Setup abgeschlossen!"
echo "==========================================${NC}"
echo ""
echo "Services Status:"
echo "  - PostgreSQL:  docker compose ps"
echo "  - Store-API:   docker compose ps"
echo "  - Ollama:      sudo systemctl status ollama"
echo "  - MCP Server:  sudo systemctl status legal-mcp"
echo ""
echo "Nächste Schritte:"
echo "  1. Gesetze importieren (dauert 4-6 Stunden):"
echo "     curl -X POST http://localhost:8888/legal-texts/gesetze-im-internet/import-all"
echo ""
echo "  2. SSL/HTTPS einrichten mit Caddy (siehe setup-ssl.sh)"
echo ""
