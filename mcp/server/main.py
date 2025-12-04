"""
ABOUTME: Legal MCP Server providing tools for querying German legal texts
ABOUTME: Integrates with the legal-mcp store API via HTTP transport

A FastMCP server providing tools for querying German legal texts.
This server integrates with the legal-mcp store API to provide
semantic search and retrieval capabilities for legal documents.
"""

from fastmcp import FastMCP
from pydantic import BaseModel, Field
from typing import List, Optional
import httpx
import logging
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration for the legal texts API
API_BASE_URL = os.getenv("LEGAL_API_BASE_URL", "http://legal-mcp-store-api:8000")

# GitHub OAuth Configuration
# Required environment variables for OAuth:
# - MCP_GITHUB_CLIENT_ID: GitHub OAuth App Client ID
# - MCP_GITHUB_CLIENT_SECRET: GitHub OAuth App Client Secret  
# - MCP_BASE_URL: Public URL of your MCP server (e.g., http://your-ip:8001)

def create_auth_provider():
    """Create GitHub OAuth provider if credentials are configured."""
    client_id = os.getenv("MCP_GITHUB_CLIENT_ID")
    client_secret = os.getenv("MCP_GITHUB_CLIENT_SECRET")
    base_url = os.getenv("MCP_BASE_URL")
    
    if all([client_id, client_secret, base_url]):
        from fastmcp.server.auth.providers.github import GitHubProvider
        logger.info(f"GitHub OAuth ENABLED - Base URL: {base_url}")
        return GitHubProvider(
            client_id=client_id,
            client_secret=client_secret,
            base_url=base_url
        )
    else:
        logger.warning("GitHub OAuth NOT configured - server running WITHOUT authentication!")
        logger.warning("Set MCP_GITHUB_CLIENT_ID, MCP_GITHUB_CLIENT_SECRET, and MCP_BASE_URL to enable OAuth")
        return None

# Create auth provider
auth_provider = create_auth_provider()

# Initialize FastMCP server with optional auth
mcp = FastMCP(
    name="Legal MCP Server",
    include_fastmcp_meta=True,
    auth=auth_provider,
)


class LegalTextResult(BaseModel):
    """Result from legal text query"""
    text: str
    code: str
    section: str
    sub_section: str
    similarity_score: Optional[float] = None


@mcp.tool()
async def search_legal_texts(
    query: str = Field(description="The search query text"),
    code: str = Field(description="Legal code identifier (e.g., 'bgb', 'stgb')"),
    limit: int = Field(default=5, description="Maximum number of results", ge=1, le=20),
    cutoff: float = Field(
        default=0.7,
        description="Similarity threshold (0-2, lower is more similar)",
        ge=0.0,
        le=2.0,
    ),
) -> List[LegalTextResult]:
    """
    Perform semantic search on German legal texts.
    
    Searches through legal codes using semantic similarity to find relevant
    sections based on the query text. Lower similarity scores indicate better matches.
    
    Args:
        query: Natural language search query
        code: Legal code to search (bgb=Civil Code, stgb=Criminal Code)
        limit: Maximum number of results to return (1-20)
        cutoff: Maximum similarity distance threshold (0-2)
    
    Returns:
        List of matching legal text sections with similarity scores
    """
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/{code}/search",
                params={
                    "q": query,
                    "limit": limit,
                    "cutoff": cutoff,
                },
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            
            return [
                LegalTextResult(
                    text=result["text"],
                    code=result["code"],
                    section=result["section"],
                    sub_section=result["sub_section"],
                    similarity_score=result.get("similarity_score"),
                )
                for result in data.get("results", [])
            ]
    except httpx.HTTPError as e:
        logger.error(f"HTTP error searching legal texts: {e}")
        raise RuntimeError(f"Failed to search legal texts: {str(e)}")
    except Exception as e:
        logger.error(f"Error searching legal texts: {e}")
        raise RuntimeError(f"Error searching legal texts: {str(e)}")


@mcp.tool()
async def get_legal_section(
    code: str = Field(description="Legal code identifier (e.g., 'bgb', 'stgb')"),
    section: str = Field(description="Section identifier (e.g., '§ 1', 'Art 1')"),
    sub_section: Optional[str] = Field(
        default=None,
        description="Optional sub-section identifier (e.g., '1', '2a')",
    ),
) -> List[LegalTextResult]:
    """
    Retrieve specific legal text sections by code and section number.
    
    Gets the exact text of a specific legal section or sub-section from
    German legal codes.
    
    Args:
        code: Legal code identifier (bgb, stgb, etc.)
        section: Section identifier (e.g., '§ 1')
        sub_section: Optional sub-section identifier
    
    Returns:
        List of legal text sections matching the criteria
    """
    try:
        async with httpx.AsyncClient() as client:
            params = {"section": section}
            if sub_section:
                params["sub_section"] = sub_section
            
            response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/{code}",
                params=params,
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()
            
            return [
                LegalTextResult(
                    text=result["text"],
                    code=result["code"],
                    section=result["section"],
                    sub_section=result["sub_section"],
                )
                for result in data.get("results", [])
            ]
    except httpx.HTTPError as e:
        logger.error(f"HTTP error getting legal section: {e}")
        raise RuntimeError(f"Failed to get legal section: {str(e)}")
    except Exception as e:
        logger.error(f"Error getting legal section: {e}")
        raise RuntimeError(f"Error getting legal section: {str(e)}")


@mcp.tool()
async def get_available_codes() -> List[str]:
    """
    Get all available legal codes in the database.

    Returns a list of legal code identifiers that have been imported
    and are available for querying and searching.

    Returns:
        List of available legal code identifiers (e.g., ['bgb', 'stgb', 'gg'])
    """
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/codes",
                timeout=30.0,
            )
            response.raise_for_status()
            data = response.json()

            return data.get("codes", [])
    except httpx.HTTPError as e:
        logger.error(f"HTTP error getting available codes: {e}")
        raise RuntimeError(f"Failed to get available codes: {str(e)}")
    except Exception as e:
        logger.error(f"Error getting available codes: {e}")
        raise RuntimeError(f"Error getting available codes: {str(e)}")


@mcp.tool()
async def search_all_legal_texts(
    query: str = Field(description="The search query text (e.g., 'E-Auto', 'Elektrofahrzeug', 'Mietrecht')"),
    limit: int = Field(default=10, description="Maximum number of results per legal code", ge=1, le=20),
    cutoff: float = Field(
        default=0.7,
        description="Similarity threshold (0-2, lower is more similar)",
        ge=0.0,
        le=2.0,
    ),
) -> List[LegalTextResult]:
    """
    Search across ALL available legal codes at once.
    
    This tool searches through all imported German legal codes simultaneously
    and returns the most relevant sections from any law. Useful for finding
    all regulations about a topic across different laws.
    
    Args:
        query: Natural language search query (e.g., 'Elektroauto', 'Kündigungsschutz')
        limit: Maximum results per legal code (1-20)
        cutoff: Maximum similarity distance threshold (0-2)
    
    Returns:
        List of matching legal text sections from all codes, sorted by relevance
    """
    try:
        all_results = []
        
        async with httpx.AsyncClient() as client:
            # First get all available codes
            codes_response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/codes",
                timeout=30.0,
            )
            codes_response.raise_for_status()
            codes = codes_response.json().get("codes", [])
            
            # Search each code
            for code in codes:
                try:
                    response = await client.get(
                        f"{API_BASE_URL}/legal-texts/gesetze-im-internet/{code}/search",
                        params={
                            "q": query,
                            "limit": limit,
                            "cutoff": cutoff,
                        },
                        timeout=30.0,
                    )
                    response.raise_for_status()
                    data = response.json()
                    
                    for result in data.get("results", []):
                        all_results.append(
                            LegalTextResult(
                                text=result["text"],
                                code=result["code"],
                                section=result["section"],
                                sub_section=result["sub_section"],
                                similarity_score=result.get("similarity_score"),
                            )
                        )
                except httpx.HTTPError as e:
                    logger.warning(f"Error searching code {code}: {e}")
                    continue
            
            # Sort by similarity score (lower is better)
            all_results.sort(key=lambda x: x.similarity_score or 999)
            
            return all_results
            
    except httpx.HTTPError as e:
        logger.error(f"HTTP error searching all legal texts: {e}")
        raise RuntimeError(f"Failed to search all legal texts: {str(e)}")
    except Exception as e:
        logger.error(f"Error searching all legal texts: {e}")
        raise RuntimeError(f"Error searching all legal texts: {str(e)}")


class LegalCodeInfo(BaseModel):
    """Information about a legal code including external links"""
    code: str
    title: str
    is_imported: bool
    has_full_text: bool
    section_count: int
    pdf_url: Optional[str] = None
    html_url: Optional[str] = None
    message: Optional[str] = None


@mcp.tool()
async def get_legal_code_info(
    code: str = Field(description="Legal code identifier (e.g., 'bgb', 'adr', 'dba_are')"),
) -> LegalCodeInfo:
    """
    Get detailed information about a legal code, including PDF links for codes
    that are not fully imported (international treaties, agreements, etc.).
    
    Use this tool when:
    - A search returns no results for a specific law
    - You need to check if a law is available
    - You want the official PDF/HTML link to read the full text
    
    For laws that only have metadata (no full text), this returns the PDF URL
    so ChatGPT can read the PDF directly from gesetze-im-internet.de.
    
    Args:
        code: Legal code identifier (e.g., 'bgb', 'adr', 'dba_usa')
    
    Returns:
        Information about the legal code including URLs to official sources
    """
    try:
        async with httpx.AsyncClient() as client:
            # Check if code is in our database
            codes_response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/codes",
                timeout=30.0,
            )
            codes_response.raise_for_status()
            imported_codes = codes_response.json().get("codes", [])
            is_imported = code.lower() in [c.lower() for c in imported_codes]
            
            # Get section count if imported
            section_count = 0
            if is_imported:
                try:
                    sections_response = await client.get(
                        f"{API_BASE_URL}/legal-texts/gesetze-im-internet/{code}",
                        params={"limit": 1},
                        timeout=30.0,
                    )
                    if sections_response.status_code == 200:
                        # Try to get total count
                        count_response = await client.get(
                            f"{API_BASE_URL}/legal-texts/gesetze-im-internet/{code}/count",
                            timeout=30.0,
                        )
                        if count_response.status_code == 200:
                            section_count = count_response.json().get("count", 0)
                except:
                    pass
            
            # Get catalog info for title
            catalog_response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/catalog",
                timeout=30.0,
            )
            catalog_response.raise_for_status()
            catalog = catalog_response.json()
            
            title = code.upper()
            for entry in catalog.get("entries", []):
                if entry["code"].lower() == code.lower():
                    title = entry.get("title", code.upper())
                    break
            
            # Build URLs to official sources
            base_url = f"https://www.gesetze-im-internet.de/{code.lower()}"
            pdf_url = f"{base_url}/{code.lower()}.pdf"
            html_url = f"{base_url}/index.html"
            
            has_full_text = is_imported and section_count > 0
            
            if has_full_text:
                message = f"Vollständig importiert mit {section_count} Abschnitten. Nutze search_legal_texts oder get_legal_section für Abfragen."
            elif is_imported:
                message = f"Importiert, aber nur Metadaten vorhanden. Lies das PDF für den vollständigen Text: {pdf_url}"
            else:
                message = f"Nicht importiert. Dies ist vermutlich ein internationales Abkommen oder Vertrag. Lies das PDF direkt: {pdf_url}"
            
            return LegalCodeInfo(
                code=code,
                title=title,
                is_imported=is_imported,
                has_full_text=has_full_text,
                section_count=section_count,
                pdf_url=pdf_url,
                html_url=html_url,
                message=message,
            )
            
    except httpx.HTTPError as e:
        logger.error(f"HTTP error getting legal code info: {e}")
        raise RuntimeError(f"Failed to get legal code info: {str(e)}")
    except Exception as e:
        logger.error(f"Error getting legal code info: {e}")
        raise RuntimeError(f"Error getting legal code info: {str(e)}")


@mcp.tool()
async def get_catalog_entries(
    search: Optional[str] = Field(default=None, description="Optional search term to filter by title or code"),
    limit: int = Field(default=50, description="Maximum number of entries to return", ge=1, le=500),
) -> List[dict]:
    """
    Get the catalog of all available German legal codes from gesetze-im-internet.de.
    
    This returns ALL 6852 legal codes (or filtered subset) with their titles,
    regardless of whether they are imported in the database or not.
    
    Use this to:
    - Find the correct code identifier for a law
    - Search for laws by name/title
    - Discover available legal texts
    
    Args:
        search: Optional text to filter entries (searches in title and code)
        limit: Maximum entries to return
    
    Returns:
        List of catalog entries with code, title, and import status
    """
    try:
        async with httpx.AsyncClient() as client:
            # Get catalog
            catalog_response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/catalog",
                timeout=30.0,
            )
            catalog_response.raise_for_status()
            catalog = catalog_response.json()
            
            # Get imported codes
            codes_response = await client.get(
                f"{API_BASE_URL}/legal-texts/gesetze-im-internet/codes",
                timeout=30.0,
            )
            codes_response.raise_for_status()
            imported_codes = [c.lower() for c in codes_response.json().get("codes", [])]
            
            entries = catalog.get("entries", [])
            
            # Filter if search term provided
            if search:
                search_lower = search.lower()
                entries = [
                    e for e in entries 
                    if search_lower in e.get("title", "").lower() 
                    or search_lower in e.get("code", "").lower()
                ]
            
            # Add import status and limit
            result = []
            for entry in entries[:limit]:
                result.append({
                    "code": entry["code"],
                    "title": entry.get("title", ""),
                    "is_imported": entry["code"].lower() in imported_codes,
                    "pdf_url": f"https://www.gesetze-im-internet.de/{entry['code'].lower()}/{entry['code'].lower()}.pdf",
                })
            
            return result
            
    except httpx.HTTPError as e:
        logger.error(f"HTTP error getting catalog: {e}")
        raise RuntimeError(f"Failed to get catalog: {str(e)}")
    except Exception as e:
        logger.error(f"Error getting catalog: {e}")
        raise RuntimeError(f"Error getting catalog: {str(e)}")


# For running with the FastMCP CLI or directly
if __name__ == "__main__":
    # Check for transport mode via environment or argument
    transport_mode = os.getenv("MCP_TRANSPORT", "stdio")
    
    if transport_mode == "http":
        # HTTP transport for remote/network accessibility
        port = int(os.getenv("MCP_PORT", "8889"))
        logger.info(f"Starting MCP server on http://0.0.0.0:{port}")
        if auth_provider:
            logger.info("GitHub OAuth authentication is ENABLED")
        mcp.run(transport="http", host="0.0.0.0", port=port)
    else:
        # stdio transport for ChatGPT Desktop and Claude Desktop
        logger.info("Starting MCP server with stdio transport")
        mcp.run(transport="stdio")
        # stdio transport for ChatGPT Desktop and Claude Desktop
        mcp.run(transport="stdio")
