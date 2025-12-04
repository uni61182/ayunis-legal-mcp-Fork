#!/bin/bash
# ===========================================
# Import ohne Embeddings (temporär)
# ===========================================

echo "=== IMPORT OHNE EMBEDDINGS (TEMPORÄR) ==="
echo ""

# 1. Import stoppen
echo "🛑 Stoppe aktuellen Import..."
pkill -f "start-import.sh" 2>/dev/null || true
pkill -f "curl.*legal-texts" 2>/dev/null || true
sleep 3

# 2. Store-API mit Dummy-Embedding-Config neu starten
echo "⚙️  Konfiguriere Store-API ohne Ollama..."

# Backup der aktuellen .env
cp .env .env.backup

# Temporäre .env mit Dummy Ollama
cat > .env << 'EOF'
# PostgreSQL Database
POSTGRES_USER=legaluser
POSTGRES_PASSWORD=legalpass
POSTGRES_DB=legaldb
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Store API Configuration
DATABASE_URL=postgresql+asyncpg://legaluser:legalpass@postgres:5432/legaldb

# Ollama Configuration (Disabled für Text-only Import)
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_TIMEOUT=120
OLLAMA_AUTH_TOKEN=

# Logging
LOG_LEVEL=INFO
EOF

echo "🔄 Store-API neustarting mit neuer Config..."
docker compose restart store-api
sleep 10

# 3. Test ohne Embedding
echo "🧪 Teste Import eines Gesetzes ohne Embedding..."
TEST_RESULT=$(curl -s -X POST "http://localhost:8888/legal-texts/gesetze-im-internet/bgb" | jq -r '.imported_count // .detail')

if [[ "$TEST_RESULT" =~ ^[0-9]+$ ]]; then
    echo "✅ Test erfolgreich: $TEST_RESULT Texte importiert"
    
    echo "🚀 Starte Vollimport ohne Embeddings..."
    bash scripts/start-import.sh
    
    echo ""
    echo "⚠️  HINWEIS:"
    echo "   - Import läuft ohne Embeddings (schneller)"
    echo "   - Semantic Search funktioniert noch nicht"
    echo "   - Embeddings können später nachgeneriert werden"
    echo ""
    echo "📊 Monitoring:"
    echo "   tail -f /root/ayunis-legal-mcp/import.log"
    echo ""
    echo "🔧 Embeddings später hinzufügen:"
    echo "   1. Ollama reparieren"
    echo "   2. Original .env wiederherstellen: mv .env.backup .env"
    echo "   3. Store-API neu starten: docker compose restart store-api"
    echo "   4. Embedding-Regeneration starten"
    
else
    echo "❌ Test fehlgeschlagen: $TEST_RESULT"
    echo "🔄 Stelle Original-Config wieder her..."
    mv .env.backup .env
    docker compose restart store-api
fi