#!/bin/bash
# ===========================================
# SSL Setup mit Caddy für MCP Server
# ===========================================

set -e

# Deine Domain hier eintragen:
DOMAIN="${1:-chris611.dns.army}"

echo "SSL Setup für Domain: $DOMAIN"

# Caddy installieren
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy

# Caddy Config erstellen
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN {
    # MCP Server (SSE endpoint)
    reverse_proxy /mcp* localhost:8889
    reverse_proxy /sse* localhost:8889
    
    # Store API (optional, für direkten Zugriff)
    reverse_proxy /legal-texts* localhost:8888
    reverse_proxy /health* localhost:8888
    
    # Automatisches SSL mit Let's Encrypt
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Security Headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
    
    log {
        output file /var/log/caddy/access.log
    }
}
EOF

# Log-Verzeichnis erstellen
sudo mkdir -p /var/log/caddy

# Caddy neustarten
sudo systemctl restart caddy
sudo systemctl enable caddy

echo ""
echo "=========================================="
echo "SSL Setup abgeschlossen!"
echo "=========================================="
echo ""
echo "Dein MCP Server ist jetzt erreichbar unter:"
echo "  https://$DOMAIN/mcp"
echo ""
echo "Für ChatGPT Custom GPT:"
echo "  Server URL: https://$DOMAIN/mcp"
echo ""
echo "Caddy Status: sudo systemctl status caddy"
echo "Caddy Logs:   sudo tail -f /var/log/caddy/access.log"
