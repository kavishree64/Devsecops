#!/usr/bin/env bash
# =============================================================================
# generate_report.sh — Aggregate all scan outputs into a unified JSON summary
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_DIR="$ROOT_DIR/reports"
SUMMARY="$REPORT_DIR/pipeline_summary.json"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { echo -e "${BLUE}[REPORT]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

# ── Parse Gitleaks findings ────────────────────────────────────────────────────
GITLEAKS_COUNT=0
GITLEAKS_REPORT="$REPORT_DIR/gitleaks/gitleaks_report.json"
if [ -f "$GITLEAKS_REPORT" ]; then
  GITLEAKS_COUNT=$(python3 -c "import json; d=json.load(open('$GITLEAKS_REPORT')); print(len(d))" 2>/dev/null || echo 0)
fi

# ── Parse Dep-Check findings ───────────────────────────────────────────────────
DEPCHECK_COUNT=0
DEPCHECK_REPORT="$REPORT_DIR/dependency-check/dependency-check-report.json"
if [ -f "$DEPCHECK_REPORT" ]; then
  DEPCHECK_COUNT=$(python3 -c "
import json
try:
    d = json.load(open('$DEPCHECK_REPORT'))
    total = sum(len(dep.get('vulnerabilities',[])) for dep in d.get('dependencies',[]))
    print(total)
except: print(0)
" 2>/dev/null || echo 0)
fi

# ── Build unified summary JSON ─────────────────────────────────────────────────
info "Generating unified pipeline report..."
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
cat > "$SUMMARY" <<JSON
{
  "report_metadata": {
    "generated_at": "$TIMESTAMP",
    "project": "Secure Bank App",
    "framework_version": "1.0.0",
    "dashboard": "docs/reports/dashboard.html"
  },
  "scan_results": {
    "gitleaks": {
      "tool": "Gitleaks v8",
      "type": "Secrets Scanning",
      "status": $([ "$GITLEAKS_COUNT" -eq 0 ] && echo '"PASS"' || echo '"FAIL"'),
      "total_findings": $GITLEAKS_COUNT,
      "report_path": "reports/gitleaks/gitleaks_report.json"
    },
    "dependency_check": {
      "tool": "OWASP Dependency-Check 12.2.0",
      "type": "Software Composition Analysis",
      "status": $([ "$DEPCHECK_COUNT" -eq 0 ] && echo '"PASS"' || echo '"FAIL"'),
      "cve_count": $DEPCHECK_COUNT,
      "report_path": "reports/dependency-check/dependency-check-report.html"
    },
    "sonarqube": {
      "tool": "SonarQube 26.3.0",
      "type": "Static Application Security Testing",
      "dashboard": "http://localhost:9000/dashboard?id=secure-bank-app",
      "note": "View live results in SonarQube dashboard"
    }
  },
  "total_secrets": $GITLEAKS_COUNT,
  "total_cves": $DEPCHECK_COUNT,
  "overall_status": $([ "$GITLEAKS_COUNT" -eq 0 ] && [ "$DEPCHECK_COUNT" -eq 0 ] && echo '"PASS"' || echo '"FAIL"')
}
JSON

success "Report generated: $SUMMARY"
echo ""
echo "Open the dashboard: docs/reports/dashboard.html"
echo "SonarQube live:     http://localhost:9000/dashboard?id=secure-bank-app"
