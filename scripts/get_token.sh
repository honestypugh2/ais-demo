#!/usr/bin/env bash
# ============================================================================
# get_token.sh — fetch an Entra ID access token (OAuth2 client-credentials).
#
# Demonstrates JWT-protected APIM access (Demo Track step A14): mint a token,
# call the Permits API with it, then show the 401 when the token is missing or
# tampered. All values are generic — no customer specifics.
#
# Reads from the environment (or a local .env in the repo root):
#   TENANT_ID, CLIENT_ID, CLIENT_SECRET, API_SCOPE (default api://ais-demo-permits/.default)
#
# Usage:
#   TOKEN=$(./scripts/get_token.sh)
#   curl -H "Authorization: Bearer $TOKEN" \
#        -H "Ocp-Apim-Subscription-Key: $APIM_SUBSCRIPTION_KEY" \
#        "$APIM_BASE$PERMITS_API_PATH"
# ============================================================================
set -euo pipefail

# Load .env if present (without overriding already-exported vars).
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${TENANT_ID:?set TENANT_ID (Entra tenant GUID)}"
: "${CLIENT_ID:?set CLIENT_ID (app registration client id)}"
: "${CLIENT_SECRET:?set CLIENT_SECRET (app registration secret)}"
SCOPE="${API_SCOPE:-api://ais-demo-permits/.default}"

curl -sf -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}" \
  --data-urlencode "scope=${SCOPE}" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])'
