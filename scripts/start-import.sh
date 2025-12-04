#!/bin/bash
# ===========================================
# Import aller deutschen Gesetze
# Läuft im Hintergrund mit Logging
# ===========================================

LOG_FILE="$HOME/ayunis-legal-mcp/import.log"

echo "Starte Import aller deutschen Gesetze..."
echo "Log-Datei: $LOG_FILE"
echo "Das dauert ca. 4-6 Stunden!"
echo ""

# Import im Hintergrund starten
nohup bash -c '
    echo "=== Import gestartet: $(date) ===" >> '$LOG_FILE'
    
    # Katalog holen
    echo "Hole Katalog..." >> '$LOG_FILE'
    CATALOG=$(curl -s "http://localhost:8888/legal-texts/gesetze-im-internet/catalog")
    if [ $? -ne 0 ]; then
        echo "FEHLER: Katalog konnte nicht abgerufen werden" >> '$LOG_FILE'
        exit 1
    fi
    
    # Codes extrahieren
    CODES=$(echo "$CATALOG" | jq -r ".entries[].code")
    TOTAL=$(echo "$CATALOG" | jq -r ".count")
    
    echo "Starte Import von $TOTAL Gesetzen..." >> '$LOG_FILE'
    
    # Zähler für Fortschritt
    COUNT=0
    SUCCESS=0
    FAILED=0
    
    # Jedes Gesetz einzeln importieren
    for CODE in $CODES; do
        COUNT=$((COUNT + 1))
        echo "[$COUNT/$TOTAL] Importiere: $CODE" >> '$LOG_FILE'
        
        # Import mit Timeout von 5 Minuten pro Gesetz
        RESPONSE=$(curl -s -X POST "http://localhost:8888/legal-texts/gesetze-im-internet/$CODE" --max-time 300)
        
        if [ $? -eq 0 ]; then
            # Prüfe ob Antwort ein Fehler ist
            ERROR=$(echo "$RESPONSE" | jq -r ".detail // empty")
            if [ -z "$ERROR" ]; then
                SUCCESS=$((SUCCESS + 1))
                IMPORTED=$(echo "$RESPONSE" | jq -r ".imported_count")
                echo "  ✓ Erfolg: $IMPORTED Texte importiert" >> '$LOG_FILE'
            else
                FAILED=$((FAILED + 1))
                echo "  ✗ Fehler: $ERROR" >> '$LOG_FILE'
            fi
        else
            FAILED=$((FAILED + 1))
            echo "  ✗ Timeout oder Verbindungsfehler" >> '$LOG_FILE'
        fi
        
        # Status alle 50 Gesetze
        if [ $((COUNT % 50)) -eq 0 ]; then
            echo "=== Zwischenstand: $COUNT/$TOTAL (Erfolg: $SUCCESS, Fehler: $FAILED) ===" >> '$LOG_FILE'
        fi
        
        # Kleine Pause zwischen Imports
        sleep 0.5
    done
    
    echo "" >> '$LOG_FILE'
    echo "=== IMPORT ABGESCHLOSSEN ===" >> '$LOG_FILE'
    echo "Total: $COUNT Gesetze" >> '$LOG_FILE'
    echo "Erfolg: $SUCCESS" >> '$LOG_FILE'
    echo "Fehler: $FAILED" >> '$LOG_FILE'
    echo "=== Import beendet: $(date) ===" >> '$LOG_FILE'
' &

PID=$!
echo "Import läuft im Hintergrund (PID: $PID)"
echo "$PID" > /tmp/import_pid
echo ""
echo "Fortschritt prüfen:"
echo "  tail -f $LOG_FILE"
echo "  grep '✓\|✗' $LOG_FILE | tail -10"
echo ""
echo "Import stoppen:"
echo "  kill $PID"
echo ""
echo "Anzahl importierter Gesetze prüfen:"
echo "  curl http://localhost:8888/legal-texts/codes | jq '.count'"
