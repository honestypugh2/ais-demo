"""Seed the Service Bus queue with sample permits (live or simulated).

Usage:
    uv run python scripts/seed_permits.py [count]
"""

import sys

from ais_demo.core.correlation import new_correlation_id
from ais_demo.integrations import service_bus

SAMPLES = [
    {"name": "[Applicant Name 1]", "type": "Building", "parcel": "AIS-2026-00417"},
    {"name": "[Applicant Name 2]", "type": "Electrical", "parcel": "AIS-2026-00521"},
    {"name": "[Applicant Name 3]", "type": "Plumbing", "parcel": "AIS-2026-00622"},
]


def main() -> None:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else len(SAMPLES)
    for sample in SAMPLES[:count]:
        cid = new_correlation_id()
        service_bus.publish_permit(sample, correlation_id=cid, message_id=sample["parcel"])
        print(f"enqueued {sample['parcel']} (correlationId={cid})")


if __name__ == "__main__":
    main()
