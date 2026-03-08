#!/usr/bin/env bash
# =============================================================================
# run_gitleaks.sh — Scan the code/ directory for secrets using Gitleaks
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CODE_DIR="$ROOT_DIR/code"
REPORT_DIR="$ROOT_DIR/reports/gitleaks"
REPORT_FILE="$REPORT_DIR/gitleaks_report.json"
GITLEAKS_VERSION="8.24.2"
GITLEAKS_BIN="$ROOT_DIR/gitleaks-bin/gitleaks"
CONFIG_FILE="$CODE_DIR/.gitleaks-project.toml"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[GITLEAKS]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}       $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC}   $*" >&2; }

mkdir -p "$REPORT_DIR" "$ROOT_DIR/gitleaks-bin"

# ── Ensure Gitleaks binary is available ──────────────────────────────────────
if [ ! -f "$GITLEAKS_BIN" ]; then
  warn "Gitleaks binary not found. Downloading pre-built v${GITLEAKS_VERSION}..."
  ARCH="x64"
  OS="linux"
  DOWNLOAD_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${OS}_${ARCH}.tar.gz"
  TMP_TAR="$ROOT_DIR/gitleaks-bin/gitleaks.tar.gz"

  if curl -fsSL "$DOWNLOAD_URL" -o "$TMP_TAR"; then
    tar -xzf "$TMP_TAR" -C "$ROOT_DIR/gitleaks-bin"
    chmod +x "$GITLEAKS_BIN"
    rm -f "$TMP_TAR"
    success "Gitleaks ${GITLEAKS_VERSION} downloaded successfully"
  else
    error "Failed to download Gitleaks from $DOWNLOAD_URL"
    error "Check internet connectivity or manually place the binary at: $GITLEAKS_BIN"
    exit 1
  fi
fi

info "Scanning for secrets in: $CODE_DIR"
info "Report will be saved to: $REPORT_FILE"
echo ""

# ── Run Gitleaks ──────────────────────────────────────────────────────────────
# Exit code 1 = leaks found, 0 = clean. We capture the exit code.
set +e
GITLEAKS_ARGS=(
  dir "$CODE_DIR"
  --report-format json
  --report-path "$REPORT_FILE"
  --verbose
  --exit-code 1
)

# Use project config if it exists
[ -f "$CONFIG_FILE" ] && GITLEAKS_ARGS+=(--config "$CONFIG_FILE")

"$GITLEAKS_BIN" "${GITLEAKS_ARGS[@]}"
EXIT_CODE=$?
set -e

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  success "No secrets detected. Repository is clean."
elif [ $EXIT_CODE -eq 1 ]; then
  echo -e "${RED}[ALERT]${NC} SECRETS DETECTED in source code!"
  echo ""
  FINDING_COUNT=$(python3 -c "import json,sys; d=json.load(open('$REPORT_FILE')); print(len(d))" 2>/dev/null || echo "?")
  echo -e "  Total findings: ${RED}$FINDING_COUNT${NC}"
  echo -e "  Report file:    $REPORT_FILE"
  echo ""
  echo "Top findings:"
  python3 - <<'PYEOF'
import json, os
try:
    report = json.load(open(os.environ.get('REPORT_FILE', '/tmp/empty.json')))
    for i, f in enumerate(report[:5], 1):
        print(f"  {i}. Rule: {f.get('RuleID','?')} | File: {f.get('File','?')} | Line: {f.get('StartLine','?')}")
        print(f"     Secret (redacted): {f.get('Secret','?')[:6]}{'*' * max(0, len(f.get('Secret','')) - 6)}")
except Exception as e:
    print(f"  (Could not parse report: {e})")
PYEOF
  export REPORT_FILE
  echo ""
  echo "Action required: Remove secrets and rotate credentials immediately."
  exit 1
else
  error "Gitleaks encountered an unexpected error (exit code: $EXIT_CODE)"
  exit $EXIT_CODE
fi
