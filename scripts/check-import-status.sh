#!/bin/bash
# ===========================================
# Import Status Monitor
# Zeigt Fortschritt des laufenden Imports
# ===========================================

LOG_FILE="$HOME/ayunis-legal-mcp/import.log"
PID_FILE="/tmp/import_pid"

echo "=== IMPORT STATUS MONITOR ==="
echo ""

# Prüfe ob Import läuft
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "✅ Import läuft (PID: $PID)"
    else
        echo "❌ Import-Prozess nicht mehr aktiv"
        rm -f "$PID_FILE"
    fi
else
    echo "ℹ️  Kein laufender Import erkannt"
fi

echo ""

# Zeige aktuelle Statistiken
if [ -f "$LOG_FILE" ]; then
    echo "📊 AKTUELLE STATISTIKEN:"
    
    # Letzte Zwischenstandsmeldung
    LAST_STATUS=$(grep "=== Zwischenstand:" "$LOG_FILE" | tail -1)
    if [ -n "$LAST_STATUS" ]; then
        echo "   $LAST_STATUS"
    fi
    
    # Zähle Erfolge und Fehler
    SUCCESS_COUNT=$(grep -c "✓ Erfolg:" "$LOG_FILE" 2>/dev/null || echo "0")
    FAILED_COUNT=$(grep -c "✗ Fehler\|✗ Timeout" "$LOG_FILE" 2>/dev/null || echo "0")
    TOTAL_PROCESSED=$((SUCCESS_COUNT + FAILED_COUNT))
    
    echo "   Verarbeitet: $TOTAL_PROCESSED"
    echo "   Erfolg: $SUCCESS_COUNT"
    echo "   Fehler: $FAILED_COUNT"
    
    echo ""
    
    # Zeige letzte 10 Aktivitäten
    echo "📝 LETZTE AKTIVITÄTEN:"
    grep -E "\[.*\] Importiere:|✓ Erfolg:|✗ (Fehler|Timeout)" "$LOG_FILE" | tail -10 | while read line; do
        echo "   $line"
    done
    
    echo ""
    
    # Database Status
    echo "🗄️  DATABASE STATUS:"
    DB_COUNT=$(curl -s "http://localhost:8888/legal-texts/codes" | jq -r '.count // "N/A"' 2>/dev/null)
    echo "   Importierte Gesetze: $DB_COUNT"
    
    echo ""
    
    # Zeige letzte Log-Einträge
    echo "📄 LETZTE LOG-EINTRÄGE (tail -5):"
    tail -5 "$LOG_FILE" | while read line; do
        echo "   $line"
    done
    
else
    echo "❌ Log-Datei nicht gefunden: $LOG_FILE"
fi

echo ""
echo "🔍 MONITORING COMMANDS:"
echo "   Live-Log:        tail -f $LOG_FILE"
echo "   Nur Erfolge:     grep '✓' $LOG_FILE"
echo "   Nur Fehler:      grep '✗' $LOG_FILE"
echo "   Status-Updates:  grep 'Zwischenstand' $LOG_FILE"
echo ""

if [ -f "$PID_FILE" ] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "⏹️  IMPORT STOPPEN:"
    echo "   kill $(cat $PID_FILE)"
    echo ""
fi