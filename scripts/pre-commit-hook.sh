#!/usr/bin/env bash
# =============================================================================
# pre-commit-hook.sh — Git pre-commit hook to block secrets before commit
#
# INSTALLATION:
#   cp scripts/pre-commit-hook.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# SKIP (emergency bypass):
#   SKIP=gitleaks git commit -m "message"
# =============================================================================
set -euo pipefail

[ "${SKIP:-}" = "gitleaks" ] && exit 0

ROOT_DIR="$(git rev-parse --show-toplevel)"
GITLEAKS_BIN="$ROOT_DIR/gitleaks-bin/gitleaks"
STAGED_TMP="$(mktemp -d)"
trap "rm -rf $STAGED_TMP" EXIT

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}[pre-commit]${NC} Running Gitleaks secrets scan on staged files..."

# ── Ensure binary exists ──────────────────────────────────────────────────────
if [ ! -f "$GITLEAKS_BIN" ]; then
  echo -e "${YELLOW}[pre-commit]${NC} Gitleaks binary not found. Run: bash scripts/run_gitleaks.sh to auto-install."
  echo -e "${YELLOW}[pre-commit]${NC} Bypassing scan (binary unavailable)."
  exit 0
fi

# ── Export staged files to a temp directory ───────────────────────────────────
git diff --cached --name-only --diff-filter=ACM | while IFS= read -r file; do
  mkdir -p "$STAGED_TMP/$(dirname "$file")"
  git show ":$file" > "$STAGED_TMP/$file" 2>/dev/null || true
done

# ── Run Gitleaks on staged files ──────────────────────────────────────────────
REPORT_FILE="$STAGED_TMP/gitleaks.json"
set +e
"$GITLEAKS_BIN" dir "$STAGED_TMP" \
  --report-format json \
  --report-path "$REPORT_FILE" \
  --exit-code 1 \
  --no-banner 2>/dev/null
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}[pre-commit]${NC} No secrets detected. Commit allowed. ✓"
  exit 0
else
  COUNT=$(python3 -c "import json; d=json.load(open('$REPORT_FILE')); print(len(d))" 2>/dev/null || echo "?")
  echo ""
  echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  COMMIT BLOCKED — Secrets Detected ($COUNT)  ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
  echo ""
  python3 - "$REPORT_FILE" <<'PYEOF'
import json, sys
findings = json.load(open(sys.argv[1]))
for f in findings:
    print(f"  ▶ Rule:   {f.get('RuleID','?')}")
    print(f"    File:   {f.get('File','?')}")
    print(f"    Line:   {f.get('StartLine','?')}")
    secret = f.get('Secret','')
    redacted = secret[:4] + '*' * max(0, len(secret) - 4) if secret else '?'
    print(f"    Secret: {redacted}")
    print()
PYEOF
  echo -e "Remove the secrets, then commit again."
  echo -e "To bypass (emergency only): ${YELLOW}SKIP=gitleaks git commit ...${NC}"
  exit 1
fi
