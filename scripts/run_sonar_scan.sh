#!/usr/bin/env bash
# =============================================================================
# run_sonar_scan.sh — Run SonarQube Scanner against the code/ directory
# Usage: bash scripts/run_sonar_scan.sh [SONAR_TOKEN]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SCANNER_BIN="$ROOT_DIR/sonar-scanner-5.0.1.3006-linux/bin/sonar-scanner"
CODE_DIR="$ROOT_DIR/code"
SQ_URL="http://localhost:9000"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[SONAR-SCAN]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}         $*"; }
error()   { echo -e "${RED}[ERROR]${NC}      $*" >&2; }

# ── Token / credentials ────────────────────────────────────────────────────────
SONAR_TOKEN="${1:-${SONAR_TOKEN:-}}"
if [ -z "$SONAR_TOKEN" ]; then
  warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
  warn "No SONAR_TOKEN provided. Using default admin:admin credentials."
  warn "Generate a token at: $SQ_URL/account/security"
  AUTH="-Dsonar.login=admin -Dsonar.password=admin"
else
  AUTH="-Dsonar.token=$SONAR_TOKEN"
fi

# ── Pre-flight ─────────────────────────────────────────────────────────────────
[ -f "$SCANNER_BIN" ] || { error "Scanner not found: $SCANNER_BIN"; exit 1; }
[ -d "$CODE_DIR" ]    || { error "Source directory not found: $CODE_DIR"; exit 1; }

SQ_STATUS=$(curl -s "$SQ_URL/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "DOWN")
if [ "$SQ_STATUS" != "UP" ]; then
  error "SonarQube is not running (status: $SQ_STATUS). Start it first:"
  echo "  bash scripts/start_sonarqube.sh"
  exit 1
fi

info "Running SonarQube Scanner on: $CODE_DIR"
info "Dashboard will be at: $SQ_URL/dashboard?id=secure-bank-app"
echo ""

# ── Run Scanner ────────────────────────────────────────────────────────────────
"$SCANNER_BIN" \
  -Dsonar.projectKey=secure-bank-app \
  -Dsonar.projectName="Secure Bank App" \
  -Dsonar.projectVersion=1.0 \
  -Dsonar.sources="$CODE_DIR" \
  -Dsonar.host.url="$SQ_URL" \
  $AUTH \
  -Dsonar.sourceEncoding=UTF-8 \
  -Dsonar.php.version=7 \
  -Dsonar.exclusions="**/*.zip,**/*.jar,**/node_modules/**" \
  -Dsonar.issue.ignore.multicriteria=e1 \
  -Dsonar.issue.ignore.multicriteria.e1.ruleKey=php:S1135 \
  -Dsonar.issue.ignore.multicriteria.e1.resourceKey="**/*.php"

echo ""
success "Scan complete! View results at:"
echo -e "  ${GREEN}$SQ_URL/dashboard?id=secure-bank-app${NC}"
echo ""
echo "Security findings will be under: Issues > Security"
echo "OWASP/CWE tags are visible in each issue detail view."
