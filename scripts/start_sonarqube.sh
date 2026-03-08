#!/usr/bin/env bash
# =============================================================================
# start_sonarqube.sh — Start SonarQube server and wait until it is ready
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SQ_HOME="$ROOT_DIR/sonarqube-26.3.0.120487"
SQ_BIN="$SQ_HOME/bin/linux-x86-64/sonar.sh"
SQ_URL="http://localhost:9000"
MAX_WAIT=120   # seconds to wait for SonarQube to come up

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Pre-flight checks ──────────────────────────────────────────────────────────
if [ ! -f "$SQ_BIN" ]; then
  error "SonarQube binary not found at $SQ_BIN"
  exit 1
fi

java -version >/dev/null 2>&1 || { error "Java not found. Install Java 17+ first."; exit 1; }

# ── vm.max_map_count (required by Elasticsearch) ───────────────────────────────
CURRENT_MAP=$(cat /proc/sys/vm/max_map_count)
REQUIRED_MAP=262144
if [ "$CURRENT_MAP" -lt "$REQUIRED_MAP" ]; then
  warn "vm.max_map_count is $CURRENT_MAP (need $REQUIRED_MAP). Applying fix..."
  if sudo sysctl -w vm.max_map_count=$REQUIRED_MAP >/dev/null 2>&1; then
    success "vm.max_map_count set to $REQUIRED_MAP (temporary — resets on reboot)"
    echo "To make it permanent, add:  vm.max_map_count=262144  to /etc/sysctl.conf"
  else
    warn "Could not set vm.max_map_count automatically. Run manually:"
    warn "  sudo sysctl -w vm.max_map_count=262144"
  fi
fi

# ── Start SonarQube ────────────────────────────────────────────────────────────
info "Starting SonarQube from $SQ_BIN ..."
"$SQ_BIN" start

# ── Wait for server ready ──────────────────────────────────────────────────────
info "Waiting for SonarQube to become ready (max ${MAX_WAIT}s)..."
elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
  STATUS=$(curl -s "$SQ_URL/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
  if [ "$STATUS" = "UP" ]; then
    success "SonarQube is UP at $SQ_URL"
    echo ""
    echo -e "  ${GREEN}Dashboard:${NC}  $SQ_URL"
    echo -e "  ${GREEN}Credentials:${NC} admin / admin  (change immediately!)"
    echo ""
    exit 0
  fi
  sleep 5
  elapsed=$((elapsed + 5))
  echo -n "."
done

error "SonarQube did not become ready within ${MAX_WAIT}s."
echo "Check logs at: $SQ_HOME/logs/sonar.log"
exit 1
