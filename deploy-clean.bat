@echo off
echo Deploying clean repository to VPS...

echo Copying deployment script...
scp deploy-clean.sh root@217.160.190.159:/root/

echo Connecting to VPS and running deployment...
ssh root@217.160.190.159 "chmod +x /root/deploy-clean.sh && /root/deploy-clean.sh"

echo.
echo ✅ Clean deployment completed!
echo.
echo 🌍 Services should be available at:
echo    - Store API: https://legalmcp.duckdns.org
echo    - MCP Server: https://legalmcp.duckdns.org/mcp
echo.
echo 📚 To import all German laws:
echo ssh root@217.160.190.159 "cd /root/ayunis-legal-mcp-clean && docker compose run --rm legal-mcp-store-api python -m app.scrapers.gesetze_im_internet.catalog import-all"
pause