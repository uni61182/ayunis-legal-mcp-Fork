#!/bin/bash
# ===========================================
# Ollama Service reparieren und Import neu starten
# ===========================================

echo "=== OLLAMA SERVICE REPARATUR ==="
echo ""

# 1. Import stoppen
echo "🛑 Stoppe aktuellen Import..."
pkill -f "start-import.sh" 2>/dev/null || true
sleep 3

# 2. Ollama Status prüfen
echo "🔍 Prüfe Ollama Status..."
if pgrep -f "ollama serve" > /dev/null; then
    echo "✅ Ollama läuft bereits"
else
    echo "❌ Ollama läuft nicht - starte Service..."
    
    # Ollama Service starten
    sudo systemctl start ollama || {
        echo "⚠️  Systemd Service nicht verfügbar, starte manuell..."
        nohup ollama serve > /tmp/ollama.log 2>&1 &
        sleep 5
    }
fi

# 3. Ollama Connectivity testen
echo "🔍 Teste Ollama Verbindung..."
for i in {1..10}; do
    if curl -s http://localhost:11434/api/version >/dev/null; then
        echo "✅ Ollama erreichbar"
        break
    else
        echo "⏳ Warte auf Ollama... ($i/10)"
        sleep 2
    fi
done

# 4. Embedding-Model prüfen
echo "🔍 Prüfe Embedding-Model..."
MODEL_CHECK=$(curl -s http://localhost:11434/api/tags | jq -r '.models[].name' | grep "qwen2.5-coder:1.5b" || echo "")

if [ -z "$MODEL_CHECK" ]; then
    echo "❌ Embedding-Model nicht gefunden!"
    echo "🔽 Lade qwen2.5-coder:1.5b herunter..."
    ollama pull qwen2.5-coder:1.5b
else
    echo "✅ Embedding-Model verfügbar: $MODEL_CHECK"
fi

# 5. Store-API Konfiguration prüfen
echo "🔍 Prüfe Store-API Konfiguration..."
docker compose logs store-api | tail -10

# 6. Test-Embedding
echo "🧪 Teste Embedding-Generierung..."
EMBEDDING_TEST=$(curl -s -X POST http://localhost:8888/legal-texts/gesetze-im-internet/bgb | jq -r '.detail // "SUCCESS"')
if [ "$EMBEDDING_TEST" != "SUCCESS" ]; then
    echo "⚠️  Embedding-Test: $EMBEDDING_TEST"
else
    echo "✅ Embedding-Test erfolgreich"
fi

echo ""
echo "🚀 Starte Import neu..."
bash scripts/start-import.sh

echo ""
echo "✅ Ollama-Service repariert!"
echo ""
echo "📊 Monitoring:"
echo "  systemctl status ollama"
echo "  curl http://localhost:11434/api/version"
echo "  tail -f /root/ayunis-legal-mcp/import.log"