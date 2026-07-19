"""AIS Demo — shared application package.

A governed, event-driven permit-intake integration flow that demonstrates
Azure Integration Services (API Management, Logic Apps, Service Bus, Event Grid,
Azure Functions) plus AI validation (Document Intelligence + an AOAI model
fronted by the APIM AI gateway).

The package is generic and use-case agnostic: swap the schemas and the
``USE_CASE_PROFILE`` to adapt the same flow to any intake scenario.
"""

__version__ = "0.1.0"
