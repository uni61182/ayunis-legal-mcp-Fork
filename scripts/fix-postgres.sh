#!/bin/bash
# ===========================================
# PostgreSQL Setup reparieren
# ===========================================

echo "=== POSTGRESQL SETUP REPARATUR ==="
echo ""

# 1. Container Status prüfen
echo "📊 Container Status:"
docker compose ps

echo ""
echo "🔍 Prüfe PostgreSQL Verbindung..."

# 2. Als postgres superuser connecten und User erstellen
docker compose exec -T postgres psql -U postgres -d postgres -c "
-- User erstellen falls nicht vorhanden
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'legaluser') THEN
    CREATE USER legaluser WITH PASSWORD 'legalpass';
  END IF;
END
\$\$;

-- Database erstellen falls nicht vorhanden  
SELECT 'CREATE DATABASE legaldb OWNER legaluser' 
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'legaldb')\gexec

-- Berechtigung geben
GRANT ALL PRIVILEGES ON DATABASE legaldb TO legaluser;
"

echo ""
echo "🔍 Prüfe pgvector Extension..."

# 3. pgvector Extension aktivieren
docker compose exec -T postgres psql -U postgres -d legaldb -c "
CREATE EXTENSION IF NOT EXISTS vector;
GRANT ALL ON SCHEMA public TO legaluser;
"

echo ""
echo "🔍 Teste Verbindung als legaluser..."

# 4. Test Verbindung
docker compose exec -T postgres psql -U legaluser -d legaldb -c "\dt"

echo ""
echo "📊 Migration nochmals ausführen..."

# 5. Migration sicherheitshalber nochmal
docker compose exec -T store-api alembic upgrade head

echo ""
echo "🔍 Finale Tabellen-Prüfung:"
docker compose exec -T postgres psql -U legaluser -d legaldb -c "\dt"

echo ""
echo "✅ PostgreSQL Setup abgeschlossen!"
echo ""
echo "🚀 Import starten:"
echo "  bash scripts/start-import.sh"