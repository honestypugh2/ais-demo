"""Document Intelligence extraction (Demo Track step B3).

Extracts structured fields from a submitted permit packet. In live mode it uses
``azure-ai-documentintelligence`` (v4.0, API 2024-11-30) with the
``prebuilt-layout`` model and the ``keyValuePairs`` add-on feature — layout only
returns key-value pairs when that feature is requested. In simulated mode it
returns deterministic synthetic fields.
"""

from ais_demo.config import get_settings
from ais_demo.config.settings import Settings
from ais_demo.core.logging import get_logger
from ais_demo.schemas import ExtractedPermit

logger = get_logger(__name__)


def extract_fields(permit: dict) -> ExtractedPermit:
    """Return structured fields from the packet referenced by ``permit``."""
    settings = get_settings()
    # Live extraction needs a document to analyze. If no ``documentUrl`` is
    # supplied (e.g. a quick demo submit), fall back to simulated extraction
    # so the message is processed instead of dead-lettered.
    if settings.simulated_mode or not settings.docintel_endpoint or not permit.get("documentUrl"):
        return _extract_simulated(permit)
    return _extract_live(permit, settings)


def _extract_simulated(permit: dict) -> ExtractedPermit:
    logger.info("Document Intelligence (simulated) extracting fields")
    return ExtractedPermit(
        applicantName=permit.get("name", "[Applicant Name]"),
        serviceAddress="1200 Main St, Anytown",
        parcelId=permit.get("parcel", "Lot 7 / Block 3"),
        serviceType=permit.get("type", "Building"),
        signaturePresent=True,
    )


def _extract_live(permit: dict, settings: Settings) -> ExtractedPermit:
    from azure.ai.documentintelligence import DocumentIntelligenceClient
    from azure.ai.documentintelligence.models import (
        AnalyzeDocumentRequest,
        DocumentAnalysisFeature,
    )
    from azure.identity import DefaultAzureCredential

    logger.info("Document Intelligence analyzing document with %s", settings.docintel_model)
    client = DocumentIntelligenceClient(
        endpoint=settings.docintel_endpoint, credential=DefaultAzureCredential()
    )
    poller = client.begin_analyze_document(
        settings.docintel_model,
        AnalyzeDocumentRequest(url_source=permit["documentUrl"]),
        features=[DocumentAnalysisFeature.KEY_VALUE_PAIRS],
    )
    result = poller.result()

    fields = {
        kv.key.content: kv.value.content
        for kv in (result.key_value_pairs or [])
        if kv.key and kv.value
    }
    signature_present = any(
        "signature" in (line.content or "").lower()
        for page in (result.pages or [])
        for line in (page.lines or [])
    )
    return ExtractedPermit(
        applicantName=fields.get("Property Owner Name"),
        serviceAddress=fields.get("Service Address"),
        parcelId=fields.get("Lot/Block Number"),
        serviceType=fields.get("Service Type") or permit.get("type"),
        signaturePresent=signature_present,
    )
