#!/bin/bash
# ===========================================
# Import aller deutschen Gesetze
# Läuft im Hintergrund mit Logging
# ===========================================

LOG_FILE="$HOME/ayunis-legal-mcp/import.log"

echo "Starte Import aller 6852 Gesetze..."
echo "Log-Datei: $LOG_FILE"
echo "Das dauert ca. 4-6 Stunden!"
echo ""

# Import im Hintergrund starten
nohup bash -c '
    echo "=== Import gestartet: $(date) ===" >> '$LOG_FILE'
    
    curl -X POST "http://localhost:8888/legal-texts/gesetze-im-internet/import-all" \
        --max-time 86400 \
        >> '$LOG_FILE' 2>&1
    
    echo "" >> '$LOG_FILE'
    echo "=== Import beendet: $(date) ===" >> '$LOG_FILE'
' &

echo "Import läuft im Hintergrund (PID: $!)"
echo ""
echo "Fortschritt prüfen:"
echo "  tail -f $LOG_FILE"
echo ""
echo "Anzahl importierter Gesetze prüfen:"
echo "  curl http://localhost:8888/legal-texts/codes | jq '.count'"
