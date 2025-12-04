from app.models import Scraper, LegalText
from typing import List
import requests
import zipfile
import io
from .xml_parser import GermanLegalXMLParser


class GesetzteImInternetScraper(Scraper):
    """Scraper for legal texts from Gesetzte im Internet"""

    def scrape(self, code: str) -> List[LegalText]:
        """Scrape a legal text from a code"""
        url = f"https://www.gesetze-im-internet.de/{code}/xml.zip"
        response = requests.get(url)
        response.raise_for_status()
        xml_data = self._extract_xml_from_zip(response.content)
        parser = GermanLegalXMLParser()
        result = parser.parse_bytes(xml_data)
        extracted_legal_texts: List[LegalText] = []
        print(len(result.norms))
        
        # Track if we found any full text content
        has_full_text = False
        
        for norm in result.norms:
            if (
                norm.textdaten
                and norm.textdaten.text
                and norm.textdaten.text.formatted_text
            ):
                for p in norm.textdaten.text.formatted_text.paragraphs:
                    if norm.metadaten.enbez:
                        has_full_text = True
                        extracted_legal_texts.append(
                            LegalText(
                                text=p,
                                # code=norm.metadaten.jurabk[0],
                                # we use the code from the url (e.g. rag_1) instead of the jurabk (e.g. RAG 1)
                                # so we know what to query later
                                code=code,
                                section=norm.metadaten.enbez,
                                sub_section=self._extract_sub_section(p),
                            )
                        )
        
        # If no full text found, create a metadata-only entry with PDF link
        if not has_full_text and result.norms:
            first_norm = result.norms[0]
            title = first_norm.metadaten.langue or first_norm.metadaten.kurzue or code.upper()
            jurabk = first_norm.metadaten.jurabk[0] if first_norm.metadaten.jurabk else code.upper()
            
            # Build info text with PDF link
            pdf_url = f"https://www.gesetze-im-internet.de/{code}/{code}.pdf"
            html_url = f"https://www.gesetze-im-internet.de/{code}/index.html"
            
            # Extract Fundstelle info if available
            fundstelle_info = ""
            if first_norm.metadaten.fundstelle:
                fs = first_norm.metadaten.fundstelle[0]
                fundstelle_info = f" (Fundstelle: {fs.periodikum} {fs.zitstelle})"
            
            # Get footnotes/additional info if available
            fussnoten_text = ""
            if first_norm.textdaten and first_norm.textdaten.fussnoten:
                if first_norm.textdaten.fussnoten.formatted_text:
                    fussnoten_text = " ".join(first_norm.textdaten.fussnoten.formatted_text.paragraphs)
            
            metadata_text = f"""[METADATA-ONLY] {title}{fundstelle_info}

Dieses Gesetz/Abkommen ist nicht als Volltext verfügbar. 
Es handelt sich vermutlich um ein internationales Abkommen, einen Vertrag oder eine ältere Norm.

Offizieller Name: {title}
Abkürzung: {jurabk}

Volltext verfügbar unter:
- PDF: {pdf_url}
- HTML: {html_url}

{fussnoten_text}"""
            
            extracted_legal_texts.append(
                LegalText(
                    text=metadata_text.strip(),
                    code=code,
                    section="Metadaten",
                    sub_section="",
                )
            )
        
        return extracted_legal_texts

    def _extract_xml_from_zip(self, zip_file: bytes) -> bytes:
        with zipfile.ZipFile(io.BytesIO(zip_file), "r") as zip_ref:
            first_file = zip_ref.namelist()[0]
            with zip_ref.open(first_file) as file:
                return file.read()

    def _extract_sub_section(self, section: str) -> str:
        # if section number is present, the str begins with (n)
        if section.startswith("("):
            return section.split("(")[1].split(")")[0]
        # If no subsection number found, return empty string instead of full text
        return ""
