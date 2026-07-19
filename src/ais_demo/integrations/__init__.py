"""Integration connectors for Azure Integration Services + AI.

Every connector has a *simulated* path (used when ``SIMULATED_MODE=true``) and a
*live* path that calls the real Azure SDK. This lets the demo run fully offline
for rehearsal, then switch to real services with a single environment flag.
"""
