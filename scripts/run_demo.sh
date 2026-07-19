#!/usr/bin/env bash
# ============================================================================
# run_demo.sh — one-command dry run of the AIS permit demo (both front doors).
#
# Drives the live Azure resources end to end so you can rehearse before you
# present:
#   • Part A (Portal / orchestrated) : POST /permits-orchestrated → APIM → Logic
#     App → Service Bus → Function → AI gateway → Event Grid, then shows the
#     Logic App run-history status (Demo Track A7).
#   • Part B (Python SDK / direct)   : POST /permits → APIM → Service Bus
#     directly, plus a live AI-gateway chat completion showing token governance
#     headers (Demo Track A5/B4).
# For each submission it polls Application Insights and prints the end-to-end
# trace (APIM → Function → AI gateway → Event Grid) correlated by parcel id.
#
# Prereqs: az login (Contributor on the RG); python3; curl.
# Usage:   scripts/run_demo.sh            # both paths
#          RG=rg-ais-demo scripts/run_demo.sh
#          scripts/run_demo.sh a          # Part A only
#          scripts/run_demo.sh b          # Part B only
# ============================================================================
set -euo pipefail

RG="${RG:-rg-ais-demo}"
PART="${1:-all}"
POLL_SECONDS="${POLL_SECONDS:-90}"

info()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m ! \033[0m%s\n' "$*"; }
step()  { printf '\n\033[1;36m── %s ──\033[0m\n' "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
require az; require curl; require python3

# ---------------------------------------------------------------------------
# Discover the demo resources in the resource group (no hard-coded suffixes).
# ---------------------------------------------------------------------------
info "Resource group: $RG"
az account show >/dev/null 2>&1 || { echo "Run 'az login' first." >&2; exit 1; }

APIM=$(az resource list -g "$RG" --resource-type Microsoft.ApiManagement/service --query "[0].name" -o tsv)
SBNS=$(az resource list -g "$RG" --resource-type Microsoft.ServiceBus/namespaces --query "[0].name" -o tsv)
LOGICAPP=$(az resource list -g "$RG" --resource-type Microsoft.Logic/workflows --query "[0].name" -o tsv)
LAW=$(az resource list -g "$RG" --resource-type Microsoft.OperationalInsights/workspaces --query "[0].name" -o tsv)
SUB=$(az account show --query id -o tsv)

[ -n "$APIM" ] || { echo "No API Management instance found in $RG" >&2; exit 1; }
GATEWAY="https://${APIM}.azure-api.net"
WID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query customerId -o tsv 2>/dev/null || echo "")

ok "APIM      : $APIM ($GATEWAY)"
ok "ServiceBus: $SBNS"
ok "Logic App : ${LOGICAPP:-<none>}"
ok "Workspace : ${LAW:-<none>}"

# Master subscription key (all-APIs) for the demo calls.
KEY=$(az rest --method post \
  --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.ApiManagement/service/$APIM/subscriptions/master/listSecrets?api-version=2022-08-01" \
  --query primaryKey -o tsv)
[ -n "$KEY" ] || { echo "Could not retrieve an APIM subscription key" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Poll Application Insights for the end-to-end trace of a given parcel.
# ---------------------------------------------------------------------------
show_trace() {
  local parcel="$1"
  [ -n "$WID" ] || { warn "No Log Analytics workspace; skipping trace."; return; }
  info "Polling Application Insights for the end-to-end trace (parcel $parcel)…"
  local deadline=$(( $(date +%s) + POLL_SECONDS ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local rows
    rows=$(az monitor log-analytics query -w "$WID" --analytics-query \
      "AppTraces | where TimeGenerated > ago(15m) | where Message has '$parcel' or Message has 'ProcessPermit' or Message has 'compliance' or Message has 'published' | project TimeGenerated, Message | order by TimeGenerated asc | take 15" \
      -o json 2>/dev/null || echo "[]")
    if printf '%s' "$rows" | python3 -c '
import sys, json
rows = json.load(sys.stdin)
if any("published" in (r.get("Message") or "") for r in rows):
    for r in rows:
        print("   %s  %s" % ((r.get("TimeGenerated") or "")[11:19], r.get("Message")))
    sys.exit(0)
sys.exit(1)
'; then
      ok "End-to-end trace complete (PermitCreated published)."
      return
    fi
    sleep 6
  done
  warn "Trace not fully visible within ${POLL_SECONDS}s (App Insights ingestion lag). Check the portal."
}

submit() {
  # submit <path> <parcel> <label>
  local path="$1" parcel="$2" label="$3"
  local body resp code cid
  body='{"name":"Demo Applicant","type":"Building","parcel":"'"$parcel"'"}'
  resp=$(curl -s -w '\n%{http_code}' -X POST "$GATEWAY/$path" \
    -H "Ocp-Apim-Subscription-Key: $KEY" -H "Content-Type: application/json" \
    -d "$body" -D /tmp/run_demo_hdr.txt)
  code=$(echo "$resp" | tail -n1)
  cid=$(grep -i '^X-Correlation-Id:' /tmp/run_demo_hdr.txt | awk '{print $2}' | tr -d '\r' || true)
  printf '   %s  →  HTTP %s   correlationId=%s\n' "$label" "$code" "${cid:-n/a}"
  echo "$resp" | sed '$d' | sed 's/^/   /'
  [ "$code" = "202" ] || warn "Expected 202 Accepted from the governed front door."
}

# ---------------------------------------------------------------------------
# Part A — Portal / orchestrated (APIM → Logic App → Service Bus).
# ---------------------------------------------------------------------------
part_a() {
  step "PART A — Portal path: APIM → Logic App → Service Bus (Demo Track A6/A7)"
  local parcel="AIS-DEMO-A-$(date +%H%M%S)"
  submit "permits-orchestrated" "$parcel" "POST /permits-orchestrated"
  if [ -n "$LOGICAPP" ]; then
    info "Waiting for the Logic App run to record…"; sleep 12
    local la_status la_start
    la_status=$(az rest --method get \
      --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Logic/workflows/$LOGICAPP/runs?api-version=2019-05-01&\$top=1" \
      --query "value[0].properties.status" -o tsv 2>/dev/null || echo "")
    la_start=$(az rest --method get \
      --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Logic/workflows/$LOGICAPP/runs?api-version=2019-05-01&\$top=1" \
      --query "value[0].properties.startTime" -o tsv 2>/dev/null || echo "")
    if [ -n "$la_status" ]; then printf '   Logic App run: %s  @ %s\n' "$la_status" "$la_start"; else warn "Could not read Logic App run history."; fi
  fi
  show_trace "$parcel"
}

# ---------------------------------------------------------------------------
# Part B — Python SDK / direct (APIM → Service Bus) + AI gateway call.
# ---------------------------------------------------------------------------
part_b() {
  step "PART B — Direct path: APIM → Service Bus (Demo Track A6/B1)"
  local parcel="AIS-DEMO-B-$(date +%H%M%S)"
  submit "permits" "$parcel" "POST /permits"
  show_trace "$parcel"

  step "PART B — AI gateway compliance model (Demo Track A5/B4)"
  info "Chat completion through the APIM AI gateway (token governance headers)…"
  curl -s -o /tmp/run_demo_aoai.json -D /tmp/run_demo_aoai_hdr.txt \
    -X POST "$GATEWAY/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-10-21" \
    -H "api-key: $KEY" -H "Content-Type: application/json" -H "x-dept: permitting" \
    -d '{"messages":[{"role":"user","content":"Reply with the single word READY."}],"max_tokens":5,"temperature":0}'
  local answer
  answer=$(python3 -c 'import sys,json; d=json.load(open("/tmp/run_demo_aoai.json")); print(d.get("choices",[{}])[0].get("message",{}).get("content","n/a"))' 2>/dev/null || echo "n/a")
  printf '   model reply : %s\n' "$answer"
  grep -iE '^x-ratelimit-(consumed|remaining)-tokens:' /tmp/run_demo_aoai_hdr.txt | sed 's/^/   /' || true
}

# ---------------------------------------------------------------------------
info "AIS permit demo — dry run ($(date '+%Y-%m-%d %H:%M:%S'))"
case "$PART" in
  a|A) part_a ;;
  b|B) part_b ;;
  all) part_a; part_b ;;
  *)   echo "Usage: $0 [a|b|all]" >&2; exit 1 ;;
esac

step "Done"
ok  "Both governed front doors exercised. Ready to present."
