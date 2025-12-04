-- Create the application database
CREATE DATABASE legal_mcp_db;

-- Connect to it and create the extension
\c legal_mcp_db

-- Create the vector extension
CREATE EXTENSION IF NOT EXISTS vector;