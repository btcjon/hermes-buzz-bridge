#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-/etc/hermes-buzz/agent.env}"
[[ -r "$ENV_FILE" ]] || { echo "Cannot read $ENV_FILE" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required=(
  BUZZ_RELAY_URL
  BUZZ_PRIVATE_KEY
  BUZZ_ACP_AGENT_COMMAND
  BUZZ_ACP_AGENT_ARGS
  BUZZ_ACP_AGENT_OWNER
)
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || { echo "Missing $name" >&2; exit 1; }
done

[[ "$BUZZ_PRIVATE_KEY" != REPLACE_* ]] || { echo "Replace BUZZ_PRIVATE_KEY placeholder" >&2; exit 1; }
[[ "$BUZZ_ACP_AGENT_OWNER" != REPLACE_* ]] || { echo "Replace BUZZ_ACP_AGENT_OWNER placeholder" >&2; exit 1; }
[[ -x "$BUZZ_ACP_AGENT_COMMAND" ]] || { echo "Hermes executable not found: $BUZZ_ACP_AGENT_COMMAND" >&2; exit 1; }

"$BUZZ_ACP_AGENT_COMMAND" acp --check
command -v buzz-acp >/dev/null
command -v buzz >/dev/null

echo "Configuration prerequisites look valid."
