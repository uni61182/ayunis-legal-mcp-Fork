# ABOUTME: Service for fetching and parsing the Gesetze im Internet catalog
# ABOUTME: Provides catalog of importable legal codes with caching
import re
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Optional

import requests
from lxml import etree

logger = logging.getLogger(__name__)


class CatalogFetchError(Exception):
    """Raised when catalog cannot be fetched from the remote source"""
    pass


class CatalogParseError(Exception):
    """Raised when catalog XML cannot be parsed"""
    pass


@dataclass
class LegalCodeCatalogEntry:
    """Represents a single entry in the catalog"""
    code: str
    title: str
    url: str


class GesetzteImInternetCatalog:
    """Service for fetching and parsing the Gesetze im Internet catalog"""

    CATALOG_URL = "https://www.gesetze-im-internet.de/gii-toc.xml"
    CACHE_TTL_SECONDS = 86400  # 24 hours

    def __init__(self):
        self._cache: Optional[List[LegalCodeCatalogEntry]] = None
        self._cache_timestamp: Optional[datetime] = None

    def get_catalog(self) -> List[LegalCodeCatalogEntry]:
        """Fetch catalog, using cache if available and fresh"""
        if self._is_cache_valid():
            logger.debug("Using cached catalog")
            return self._cache

        logger.info("Fetching fresh catalog")
        self._cache = self._fetch_catalog()
        self._cache_timestamp = datetime.now()
        return self._cache

    def is_valid_code(self, code: str) -> bool:
        """Check if a code exists in the catalog"""
        catalog = self.get_catalog()
        return any(entry.code == code for entry in catalog)

    def _fetch_catalog(self) -> List[LegalCodeCatalogEntry]:
        """Fetch and parse the catalog XML"""
        try:
            logger.info(f"Fetching catalog from {self.CATALOG_URL}")
            response = requests.get(self.CATALOG_URL, timeout=30)
            response.raise_for_status()
            return self._parse_catalog_xml(response.content)
        except requests.RequestException as e:
            logger.error(f"Failed to fetch catalog: {str(e)}")
            raise CatalogFetchError(f"Failed to fetch catalog: {str(e)}") from e
        except Exception as e:
            logger.error(f"Unexpected error fetching catalog: {str(e)}")
            raise CatalogFetchError(f"Unexpected error fetching catalog: {str(e)}") from e

    def _parse_catalog_xml(self, xml_content: bytes) -> List[LegalCodeCatalogEntry]:
        """Parse the catalog XML into LegalCodeCatalogEntry objects"""
        try:
            tree = etree.fromstring(xml_content)
        except etree.XMLSyntaxError as e:
            logger.error(f"Failed to parse catalog XML: {str(e)}")
            raise CatalogParseError(f"Failed to parse catalog XML: {str(e)}") from e

        entries = []
        for item in tree.findall(".//item"):
            title_elem = item.find("title")
            link_elem = item.find("link")

            # Skip malformed entries
            if title_elem is None or link_elem is None:
                logger.warning("Skipping item with missing title or link")
                continue

            title = title_elem.text
            url = link_elem.text

            # Skip if missing data
            if not title or not url:
                logger.warning(f"Skipping item with empty title or url: title={title}, url={url}")
                continue

            code = self._extract_code_from_url(url)
            if code is None:
                logger.warning(f"Could not extract code from URL: {url}")
                continue

            entries.append(LegalCodeCatalogEntry(
                code=code,
                title=title,
                url=url
            ))

        logger.info(f"Parsed {len(entries)} entries from catalog")
        return entries

    def _extract_code_from_url(self, url: str) -> Optional[str]:
        """Extract code from URL like https://www.gesetze-im-internet.de/bgb/xml.zip"""
        pattern = r'https?://www\.gesetze-im-internet\.de/([^/]+)/xml\.zip'
        match = re.match(pattern, url)
        if match:
            return match.group(1)
        return None

    def _is_cache_valid(self) -> bool:
        """Check if cache exists and hasn't expired"""
        if self._cache is None or self._cache_timestamp is None:
            return False

        age = datetime.now() - self._cache_timestamp
        return age.total_seconds() < self.CACHE_TTL_SECONDS
