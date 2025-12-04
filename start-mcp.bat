@echo off
title Legal MCP Server Starter
echo ============================================
echo   Legal MCP Server + Cloudflare Tunnel
echo ============================================
echo.

REM Prüfe ob Docker läuft
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker ist nicht gestartet!
    echo Bitte starte Docker Desktop und versuche es erneut.
    pause
    exit /b 1
)

REM Prüfe ob Store-API läuft
echo [1/4] Pruefe Store-API...
curl -s http://localhost:8888/health >nul 2>&1
if errorlevel 1 (
    echo       Store-API nicht erreichbar, starte Docker Compose...
    cd /d D:\ayunis-legal-mcp
    docker-compose up -d
    echo       Warte 10 Sekunden auf Start...
    timeout /t 10 /nobreak >nul
) else (
    echo       Store-API laeuft bereits auf Port 8888
)

REM Prüfe ob Ollama läuft
echo [2/4] Pruefe Ollama...
curl -s http://localhost:11434/api/version >nul 2>&1
if errorlevel 1 (
    echo       Ollama nicht erreichbar, starte Ollama...
    start "" ollama serve
    timeout /t 5 /nobreak >nul
) else (
    echo       Ollama laeuft bereits auf Port 11434
)

REM Stoppe alte Python-Prozesse
echo [3/4] Stoppe alte MCP-Server Prozesse...
taskkill /f /im python.exe >nul 2>&1

REM Starte MCP Server im Hintergrund
echo [4/4] Starte MCP Server auf Port 8889...
cd /d D:\ayunis-legal-mcp\mcp
set LEGAL_API_BASE_URL=http://localhost:8888
set MCP_TRANSPORT=http
set MCP_PORT=8889

start "MCP Server" cmd /c "D:\ayunis-legal-mcp\.venv\Scripts\python.exe -m server.main"
timeout /t 3 /nobreak >nul

REM Prüfe ob MCP Server läuft
curl -s http://localhost:8889 >nul 2>&1
if errorlevel 1 (
    echo [WARNUNG] MCP Server antwortet noch nicht, warte...
    timeout /t 5 /nobreak >nul
)

echo.
echo ============================================
echo   Starte Cloudflare Tunnel...
echo ============================================
echo.
echo Die Tunnel-URL erscheint gleich unten.
echo Kopiere die URL (https://....trycloudflare.com)
echo und verwende sie in ChatGPT.
echo.
echo Druecke Ctrl+C um alles zu beenden.
echo ============================================
echo.

cloudflared tunnel --url http://localhost:8889
