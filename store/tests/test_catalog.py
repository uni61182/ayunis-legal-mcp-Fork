# ABOUTME: Unit tests for the Gesetze im Internet catalog service
# ABOUTME: Tests catalog fetching, parsing, caching, and validation
import pytest
from unittest.mock import Mock, patch
from datetime import datetime, timedelta
from app.scrapers.gesetze_im_internet.catalog import (
    GesetzteImInternetCatalog,
    LegalCodeCatalogEntry,
    CatalogFetchError,
    CatalogParseError,
)


class TestExtractCodeFromUrl:
    """Test URL code extraction"""

    def test_extract_code_from_url_valid(self):
        """Extract code from valid HTTPS URL"""
        catalog = GesetzteImInternetCatalog()
        url = "https://www.gesetze-im-internet.de/bgb/xml.zip"
        assert catalog._extract_code_from_url(url) == "bgb"

    def test_extract_code_from_url_with_numbers(self):
        """Extract code from URL containing numbers"""
        catalog = GesetzteImInternetCatalog()
        url = "https://www.gesetze-im-internet.de/alttzg_1996/xml.zip"
        assert catalog._extract_code_from_url(url) == "alttzg_1996"

    def test_extract_code_from_url_invalid(self):
        """Handle malformed URLs"""
        catalog = GesetzteImInternetCatalog()
        url = "https://example.com/invalid"
        assert catalog._extract_code_from_url(url) is None


class TestParseCatalogXml:
    """Test XML parsing"""

    def test_parse_catalog_xml_valid(self):
        """Parse valid XML structure"""
        catalog = GesetzteImInternetCatalog()
        xml_content = """<?xml version="1.0" encoding="UTF-8"?>
<items>
  <item>
    <title>Bürgerliches Gesetzbuch</title>
    <link>https://www.gesetze-im-internet.de/bgb/xml.zip</link>
  </item>
  <item>
    <title>Strafgesetzbuch</title>
    <link>https://www.gesetze-im-internet.de/stgb/xml.zip</link>
  </item>
</items>""".encode('utf-8')

        entries = catalog._parse_catalog_xml(xml_content)

        assert len(entries) == 2
        assert entries[0].code == "bgb"
        assert entries[0].title == "Bürgerliches Gesetzbuch"
        assert entries[0].url == "https://www.gesetze-im-internet.de/bgb/xml.zip"
        assert entries[1].code == "stgb"
        assert entries[1].title == "Strafgesetzbuch"

    def test_parse_catalog_xml_empty(self):
        """Handle empty XML"""
        catalog = GesetzteImInternetCatalog()
        xml_content = b"""<?xml version="1.0" encoding="UTF-8"?>
<items>
</items>"""

        entries = catalog._parse_catalog_xml(xml_content)
        assert len(entries) == 0

    def test_parse_catalog_xml_invalid(self):
        """Handle invalid XML"""
        catalog = GesetzteImInternetCatalog()
        xml_content = b"not valid xml"

        with pytest.raises(CatalogParseError):
            catalog._parse_catalog_xml(xml_content)

    def test_parse_catalog_xml_skip_malformed_entries(self):
        """Skip entries with missing required fields"""
        catalog = GesetzteImInternetCatalog()
        xml_content = """<?xml version="1.0" encoding="UTF-8"?>
<items>
  <item>
    <title>Bürgerliches Gesetzbuch</title>
    <link>https://www.gesetze-im-internet.de/bgb/xml.zip</link>
  </item>
  <item>
    <title>Missing Link</title>
  </item>
  <item>
    <link>https://www.gesetze-im-internet.de/stgb/xml.zip</link>
  </item>
</items>""".encode('utf-8')

        entries = catalog._parse_catalog_xml(xml_content)

        # Should only include the valid entry
        assert len(entries) == 1
        assert entries[0].code == "bgb"


class TestCaching:
    """Test caching behavior"""

    def test_cache_reuse(self):
        """Verify cache is reused within TTL"""
        catalog = GesetzteImInternetCatalog()

        mock_entries = [
            LegalCodeCatalogEntry(
                code="bgb",
                title="Bürgerliches Gesetzbuch",
                url="https://www.gesetze-im-internet.de/bgb/xml.zip"
            )
        ]

        with patch.object(catalog, '_fetch_catalog', return_value=mock_entries) as mock_fetch:
            # First call should fetch
            entries1 = catalog.get_catalog()
            assert mock_fetch.call_count == 1

            # Second call should use cache
            entries2 = catalog.get_catalog()
            assert mock_fetch.call_count == 1

            # Should return same data
            assert entries1 == entries2

    def test_cache_invalidation(self):
        """Verify cache expires after TTL"""
        catalog = GesetzteImInternetCatalog()

        mock_entries = [
            LegalCodeCatalogEntry(
                code="bgb",
                title="Bürgerliches Gesetzbuch",
                url="https://www.gesetze-im-internet.de/bgb/xml.zip"
            )
        ]

        with patch.object(catalog, '_fetch_catalog', return_value=mock_entries) as mock_fetch:
            # Set initial cache with old timestamp
            old_time = datetime.now() - timedelta(seconds=catalog.CACHE_TTL_SECONDS + 1)
            catalog._cache = mock_entries
            catalog._cache_timestamp = old_time

            # Call should fetch fresh data
            catalog.get_catalog()
            assert mock_fetch.call_count == 1


class TestIsValidCode:
    """Test code validation"""

    def test_is_valid_code_exists(self):
        """Validate existing code returns True"""
        catalog = GesetzteImInternetCatalog()

        mock_entries = [
            LegalCodeCatalogEntry(
                code="bgb",
                title="Bürgerliches Gesetzbuch",
                url="https://www.gesetze-im-internet.de/bgb/xml.zip"
            ),
            LegalCodeCatalogEntry(
                code="stgb",
                title="Strafgesetzbuch",
                url="https://www.gesetze-im-internet.de/stgb/xml.zip"
            )
        ]

        with patch.object(catalog, 'get_catalog', return_value=mock_entries):
            assert catalog.is_valid_code("bgb") is True
            assert catalog.is_valid_code("stgb") is True

    def test_is_valid_code_not_exists(self):
        """Validate non-existing code returns False"""
        catalog = GesetzteImInternetCatalog()

        mock_entries = [
            LegalCodeCatalogEntry(
                code="bgb",
                title="Bürgerliches Gesetzbuch",
                url="https://www.gesetze-im-internet.de/bgb/xml.zip"
            )
        ]

        with patch.object(catalog, 'get_catalog', return_value=mock_entries):
            assert catalog.is_valid_code("nonexistent") is False


class TestFetchCatalog:
    """Test catalog fetching"""

    def test_fetch_catalog_network_error(self):
        """Handle network failures gracefully"""
        catalog = GesetzteImInternetCatalog()

        with patch('requests.get') as mock_get:
            mock_get.side_effect = Exception("Network error")

            with pytest.raises(CatalogFetchError):
                catalog._fetch_catalog()
