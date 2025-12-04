# ChatGPT Integration für Legal MCP

## Übersicht

ChatGPT unterstützt das Model Context Protocol (MCP) **nicht direkt**. MCP wurde von Anthropic entwickelt und funktioniert nur mit:
- Claude Desktop
- Andere MCP-kompatible Clients (z.B. Cursor, Continue.dev)

Für ChatGPT gibt es zwei Alternativen:

## Option 1: Custom GPT mit Actions (Empfohlen)

### Voraussetzungen
1. ChatGPT Plus oder Team Subscription
2. Deine Store API muss **öffentlich erreichbar** sein (z.B. via ngrok, Cloudflare Tunnel, oder Server mit öffentlicher IP)

### Schritt-für-Schritt Anleitung

#### 1. API öffentlich zugänglich machen

**Option A: Mit ngrok (für Tests)**
```bash
# ngrok installieren: https://ngrok.com/download
# Tunnel starten
ngrok http 8000
```
Du erhältst eine URL wie `https://abc123.ngrok.io`

**Option B: Mit Cloudflare Tunnel (kostenlos, produktionsreif)**
```bash
# cloudflared installieren
# Tunnel erstellen
cloudflared tunnel --url http://localhost:8000
```

**Option C: Server mit öffentlicher IP**
- Stelle sicher, dass Port 8000 erreichbar ist
- Nutze HTTPS (z.B. mit Caddy oder nginx als Reverse Proxy)

#### 2. Custom GPT erstellen

1. Gehe zu [ChatGPT](https://chat.openai.com)
2. Klicke auf "Explore GPTs" → "Create a GPT"
3. Konfiguriere das GPT:

**Name:** Legal MCP - Deutsche Gesetzessuche

**Description:** 
Durchsucht deutsche Gesetzestexte (BGB, StGB, GG, etc.) mit semantischer Suche

**Instructions:**
```
Du bist ein Experte für deutsches Recht und hast Zugriff auf eine Datenbank deutscher Gesetzestexte.

Verwende die verfügbaren Actions um:
1. Verfügbare Gesetzbücher aufzulisten (getAvailableCodes)
2. Spezifische Paragraphen abzurufen (getLegalTexts)
3. Semantisch in Gesetzestexten zu suchen (searchLegalTexts)

Bei Fragen zu deutschem Recht:
- Suche zuerst nach relevanten Paragraphen
- Zitiere immer die genaue Quelle (z.B. "§ 433 BGB")
- Erkläre den Gesetzestext in verständlicher Sprache
- Weise darauf hin, dass du keine Rechtsberatung bietest

Verfügbare Gesetzbücher (Beispiele):
- bgb: Bürgerliches Gesetzbuch
- stgb: Strafgesetzbuch
- gg: Grundgesetz
```

#### 3. Actions hinzufügen

1. Im GPT Builder auf "Configure" → "Actions" → "Create new action"
2. Kopiere den Inhalt von `_docs/chatgpt-openapi-schema.yaml`
3. Ersetze `https://YOUR-PUBLIC-URL:8000` mit deiner öffentlichen URL
4. Klicke "Import from URL/Text"

#### 4. Testen

Teste das GPT mit Fragen wie:
- "Welche Gesetzbücher sind verfügbar?"
- "Zeige mir § 433 BGB"
- "Suche nach Paragraphen zum Thema Kaufvertrag im BGB"

---

## Option 2: Claude Desktop mit MCP (Nativ unterstützt)

Wenn du Claude Desktop nutzen kannst, funktioniert der MCP-Server direkt.

### Claude Desktop Konfiguration

Füge zu deiner `claude_desktop_config.json` hinzu:

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`
**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "legal-mcp": {
      "command": "python",
      "args": ["-m", "server.main"],
      "cwd": "D:\\ayunis-legal-mcp\\mcp",
      "env": {
        "LEGAL_API_BASE_URL": "http://localhost:8000"
      }
    }
  }
}
```

### Alternative: HTTP Transport (wenn Store API läuft)

```json
{
  "mcpServers": {
    "legal-mcp": {
      "url": "http://localhost:8001"
    }
  }
}
```

**Hinweis:** Stelle sicher, dass die Docker-Container laufen:
```bash
docker-compose up -d
```

---

## Option 3: API direkt nutzen (ohne GPT)

Du kannst die Store API auch direkt per REST aufrufen:

```bash
# Verfügbare Codes
curl http://localhost:8000/legal-texts/gesetze-im-internet/codes

# Spezifischen Paragraph abrufen
curl "http://localhost:8000/legal-texts/gesetze-im-internet/bgb?section=%C2%A7%20433"

# Semantische Suche
curl "http://localhost:8000/legal-texts/gesetze-im-internet/bgb/search?q=Kaufvertrag&limit=5"
```

---

## Troubleshooting

### API nicht erreichbar
```bash
# Docker-Status prüfen
docker-compose ps

# Logs prüfen
docker-compose logs store-api
```

### ChatGPT Action Fehler
1. Prüfe ob die URL öffentlich erreichbar ist
2. Stelle sicher dass CORS erlaubt ist (bereits in FastAPI konfiguriert)
3. Teste die API erst manuell mit curl

### Keine Ergebnisse bei der Suche
1. Stelle sicher dass Gesetzbücher importiert sind:
   ```bash
   legal-mcp list codes
   ```
2. Falls leer, importiere Gesetzbücher:
   ```bash
   legal-mcp import --code bgb
   ```
