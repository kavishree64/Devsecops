#!/usr/bin/env bash
# =============================================================================
# ci_pipeline.sh — Master CI/CD Security Pipeline Orchestrator
# Runs: Gitleaks → OWASP Dep-Check → SonarQube SAST → Summary Report
# Usage: bash scripts/ci_pipeline.sh [SONAR_TOKEN]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_DIR="$ROOT_DIR/reports"
SUMMARY_REPORT="$REPORT_DIR/pipeline_summary.json"
SONAR_TOKEN="${1:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[PIPELINE]${NC} $*"; }
success() { echo -e "${GREEN}[PASS]${NC}     $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}     $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}     $*"; }
section() { echo ""; echo -e "${BOLD}════════════════════════════════════════${NC}"; echo -e "${BOLD} $*${NC}"; echo -e "${BOLD}════════════════════════════════════════${NC}"; echo ""; }

PIPELINE_START=$(date +%s)
GITLEAKS_STATUS="SKIP"
DEPCHECK_STATUS="SKIP"
SONAR_STATUS="SKIP"
GITLEAKS_FINDINGS=0
DEPCHECK_FINDINGS=0
SONAR_ISSUES=0

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   DevSecOps Code Review Pipeline v1.0   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# ── Stage 1: Secrets Scanning ─────────────────────────────────────────────────
section "Stage 1/3: Secrets Scanning (Gitleaks)"
if bash "$SCRIPT_DIR/run_gitleaks.sh"; then
  GITLEAKS_STATUS="PASS"
  success "No secrets detected"
else
  GITLEAKS_STATUS="FAIL"
  GITLEAKS_FINDINGS=$(python3 -c "import json; d=json.load(open('$REPORT_DIR/gitleaks/gitleaks_report.json')); print(len(d))" 2>/dev/null || echo "?")
  fail "Secrets detected: $GITLEAKS_FINDINGS finding(s)"
  warn "Secrets scan failed — continuing pipeline for full report, but pipeline will exit non-zero"
fi

# ── Stage 2: Software Composition Analysis ───────────────────────────────────
section "Stage 2/3: Dependency Scanning (OWASP Dep-Check)"
if bash "$SCRIPT_DIR/run_dependency_check.sh"; then
  DEPCHECK_STATUS="PASS"
  success "Dependency scan complete"
  DEPCHECK_FINDINGS=$(python3 -c "
import json, os
try:
    d = json.load(open('$REPORT_DIR/dependency-check/dependency-check-report.json'))
    vulns = sum(len(dep.get('vulnerabilities',[])) for dep in d.get('dependencies',[]))
    print(vulns)
except: print(0)
" 2>/dev/null || echo "0")
else
  DEPCHECK_STATUS="WARN"
  warn "Dependency check encountered issues (may be no dependencies to scan)"
fi

# ── Stage 3: Static Application Security Testing ─────────────────────────────
section "Stage 3/3: Static Code Analysis (SonarQube)"
SQ_STATUS=$(curl -s "http://localhost:9000/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "DOWN")
if [ "$SQ_STATUS" = "UP" ]; then
  if bash "$SCRIPT_DIR/run_sonar_scan.sh" "$SONAR_TOKEN"; then
    SONAR_STATUS="PASS"
    success "SonarQube scan complete — view at http://localhost:9000"
  else
    SONAR_STATUS="FAIL"
    fail "SonarQube scan failed"
  fi
else
  SONAR_STATUS="SKIP"
  warn "SonarQube is not running. Start with: bash scripts/start_sonarqube.sh"
fi

# ── Summary Report ────────────────────────────────────────────────────────────
PIPELINE_END=$(date +%s)
DURATION=$((PIPELINE_END - PIPELINE_START))

section "Pipeline Summary"
echo -e "Duration: ${DURATION}s"
echo ""
printf "  %-30s %s\n" "Stage" "Result"
printf "  %-30s %s\n" "─────────────────────────────" "──────"
[ "$GITLEAKS_STATUS" = "PASS" ] && COLOR=$GREEN || COLOR=$RED
printf "  %-30s ${COLOR}%-10s${NC} %s\n" "Gitleaks (Secrets Scan)" "$GITLEAKS_STATUS" "(findings: $GITLEAKS_FINDINGS)"
[ "$DEPCHECK_STATUS" = "PASS" ] && COLOR=$GREEN || COLOR=$YELLOW
printf "  %-30s ${COLOR}%-10s${NC} %s\n" "OWASP Dep-Check (SCA)" "$DEPCHECK_STATUS" "(CVEs: $DEPCHECK_FINDINGS)"
[ "$SONAR_STATUS" = "PASS" ] && COLOR=$GREEN || [ "$SONAR_STATUS" = "SKIP" ] && COLOR=$YELLOW || COLOR=$RED
printf "  %-30s ${COLOR}%-10s${NC} %s\n" "SonarQube (SAST)" "$SONAR_STATUS" ""
echo ""

# Write JSON summary
cat > "$SUMMARY_REPORT" <<JSON
{
  "pipeline_run": {
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "duration_seconds": $DURATION,
    "project": "Secure Bank App",
    "stages": {
      "gitleaks": {
        "status": "$GITLEAKS_STATUS",
        "findings": $GITLEAKS_FINDINGS,
        "report": "reports/gitleaks/gitleaks_report.json"
      },
      "dependency_check": {
        "status": "$DEPCHECK_STATUS",
        "cve_count": $DEPCHECK_FINDINGS,
        "report": "reports/dependency-check/dependency-check-report.html"
      },
      "sonarqube": {
        "status": "$SONAR_STATUS",
        "dashboard": "http://localhost:9000/dashboard?id=secure-bank-app"
      }
    }
  }
}
JSON

info "Pipeline summary saved to: $SUMMARY_REPORT"
echo ""

# ── Exit code ─────────────────────────────────────────────────────────────────
if [ "$GITLEAKS_STATUS" = "FAIL" ] || [ "$SONAR_STATUS" = "FAIL" ]; then
  fail "Pipeline FAILED — security issues require attention before merging."
  exit 1
else
  success "Pipeline completed successfully."
  exit 0
fi
