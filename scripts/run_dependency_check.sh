#!/usr/bin/env bash
# =============================================================================
# run_dependency_check.sh — Run OWASP Dependency-Check SCA on code/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DC_BIN="$ROOT_DIR/dependency-check/bin/dependency-check.sh"
CODE_DIR="$ROOT_DIR/code"
REPORT_DIR="$ROOT_DIR/reports/dependency-check"
NVD_CACHE="$ROOT_DIR/dependency-check/data"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[DEP-CHECK]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}        $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}     $*"; }
error()   { echo -e "${RED}[ERROR]${NC}    $*" >&2; }

[ -f "$DC_BIN" ] || { error "dependency-check not found: $DC_BIN"; exit 1; }
mkdir -p "$REPORT_DIR"

info "Running OWASP Dependency-Check on: $CODE_DIR"
info "NVD cache directory: $NVD_CACHE"
info "Reports will be saved to: $REPORT_DIR"
warn "First run downloads the NVD database (~200MB) — this may take several minutes."
echo ""

"$DC_BIN" \
  --project "Secure Bank App" \
  --scan "$CODE_DIR" \
  --out "$REPORT_DIR" \
  --format HTML \
  --format JSON \
  --data "$NVD_CACHE" \
  --enableRetired \
  --enableExperimental \
  --log "$REPORT_DIR/dependency-check.log"

echo ""
success "Dependency-Check complete!"
echo -e "  HTML Report: ${GREEN}$REPORT_DIR/dependency-check-report.html${NC}"
echo -e "  JSON Report: ${GREEN}$REPORT_DIR/dependency-check-report.json${NC}"
echo ""
echo "Open the HTML report in a browser to review CVE findings."
echo "Each finding includes: CVE ID, CVSS score, CWE, and affected library."
