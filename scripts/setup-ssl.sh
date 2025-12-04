#!/bin/bash
# ===========================================
# SSL Setup mit Caddy für MCP Server
# Funktioniert mit jeder Domain inkl. DuckDNS!
# ===========================================

set -e

# Deine Domain hier eintragen:
# Beispiele:
#   - DuckDNS:     ayunis-legal.duckdns.org
#   - Eigene:      legal.deine-domain.de
#   - IONOS:       dein-name.ionos.space
DOMAIN="${1:-}"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    echo ""
    echo "Beispiele:"
    echo "  $0 ayunis-legal.duckdns.org"
    echo "  $0 legal.meine-domain.de"
    echo ""
    echo "Noch keine Domain? Kostenlos bei https://www.duckdns.org"
    exit 1
fi

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
