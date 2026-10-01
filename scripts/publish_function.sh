#!/usr/bin/env bash
# Publish the Service Bus-triggered Function (functionapp/) to Azure.
#
# functionapp/requirements.txt installs the shared ais_demo package with
# `-e ..`, which a remote build can't reach. This script stages the Function
# host together with a copy of src/ais_demo and pinned requirements exported
# from uv.lock, then publishes the staged folder with a remote build.
#
# Usage: scripts/publish_function.sh <function-app-name>
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:?Usage: $0 <function-app-name>}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp functionapp/function_app.py functionapp/host.json "$STAGE/"
cp -r src/ais_demo "$STAGE/ais_demo"
find "$STAGE" -name '__pycache__' -type d -prune -exec rm -rf {} +

{
  grep -v -E '^\s*(#|-e |$)' functionapp/requirements.txt
  uv export --frozen --no-dev --no-emit-project --no-hashes --format requirements-txt \
    | grep -v -E '^\s*#'
} > "$STAGE/requirements.txt"

cat > "$STAGE/.funcignore" <<'EOF'
.venv
__pycache__
local.settings.json
EOF

echo "==> Publishing $APP from $STAGE"
(cd "$STAGE" && func azure functionapp publish "$APP" --python --build remote)
