#!/bin/bash
# ===========================================
# Datenbank-Migration und Import-Neustart
# ===========================================

echo "=== DATENBANK-REPARATUR ==="
echo ""

# 1. Import stoppen
echo "🛑 Stoppe laufenden Import..."
pkill -f "start-import.sh" 2>/dev/null || true
sleep 2

# 2. Docker Container prüfen
echo "🔍 Prüfe Docker Container..."
docker ps

echo ""
echo "📊 Führe Datenbank-Migration aus..."

# 3. Migration ausführen
cd /root/ayunis-legal-mcp
docker compose exec -T store-api alembic upgrade head

if [ $? -eq 0 ]; then
    echo "✅ Migration erfolgreich"
else
    echo "❌ Migration fehlgeschlagen"
    echo "Versuche Container-Neustart..."
    docker compose restart store-api
    sleep 10
    docker compose exec -T store-api alembic upgrade head
fi

echo ""
echo "🔍 Prüfe Tabellen..."
docker compose exec -T postgres psql -U legaluser -d legaldb -c "\dt"

echo ""
echo "🚀 Starte Import neu..."
bash scripts/start-import.sh

echo ""
echo "✅ Reparatur abgeschlossen!"
echo "Überwachung:"
echo "  bash scripts/check-import-status.sh"
echo "  tail -f /root/ayunis-legal-mcp/import.log"