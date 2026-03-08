# Performance Tuning Guide

This document covers performance optimization strategies for the DevSecOps code review framework to minimize impact on CI/CD build times.

---

## 1. SonarQube JVM Tuning

Edit `sonarqube-26.3.0.120487/conf/sonar.properties`:

```properties
# Web Server — handles API and UI requests
sonar.web.javaOpts=-Xmx1g -Xms512m -XX:+HeapDumpOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom

# Compute Engine — processes background analysis tasks  
sonar.ce.javaOpts=-Xmx2g -Xms512m -XX:+HeapDumpOnOutOfMemoryError

# Elasticsearch — search index
# Set to 50% of available RAM (capped at 31GB)
sonar.search.javaOpts=-Xmx1g -Xms1g -XX:MaxDirectMemorySize=512m -XX:+HeapDumpOnOutOfMemoryError
```

| Component | Min RAM | Recommended RAM |
|---|---|---|
| Web Server | 128 MB | 512 MB – 1 GB |
| Compute Engine | 512 MB | 1 – 2 GB |
| Elasticsearch | 512 MB | 1 – 2 GB |
| **Total (SonarQube)** | **1.5 GB** | **4 – 6 GB** |

---

## 2. Source Exclusions

Reduce scan time by excluding non-essential files in `sonar-project.properties`:

```properties
# Exclude files that don't need security analysis
sonar.exclusions=\
  **/vendor/**,\
  **/node_modules/**,\
  **/*.min.js,\
  **/*.min.css,\
  **/dist/**,\
  **/build/**,\
  **/*.zip,\
  **/*.jar,\
  **/*.class,\
  **/migrations/**

# Exclude test files from coverage (but still analyze for bugs)
sonar.coverage.exclusions=**/*Test*.php, **/*Spec*.php, **/tests/**

# Skip test files from duplication detection 
sonar.cpd.exclusions=**/tests/**, **/test/**
```

---

## 3. OWASP Dependency-Check Caching

The NVD database (~200 MB) is downloaded on every first run. Use the `--data` flag to cache it:

```bash
# The run_dependency_check.sh script already caches to:
# dependency-check/data/

# In CI (GitHub Actions), use the cache action:
- name: Cache NVD database
  uses: actions/cache@v4
  with:
    path: ~/.dependency-check/data
    key: nvd-${{ hashFiles('**/package-lock.json', '**/composer.lock') }}
    restore-keys: nvd-
```

**Expected time savings:**
- First run (no cache): ~5–15 minutes (NVD download)
- Subsequent runs (with cache): ~30–60 seconds

### Update NVD data manually (avoid stale CVE data):
```bash
# Run this weekly or before major releases:
dependency-check/bin/dependency-check.sh --updateonly --data dependency-check/data
```

---

## 4. Gitleaks Optimizations

```bash
# Scan only changed files (in CI, use --log-opts for git range):
gitleaks git --log-opts="origin/main..HEAD"

# Increase performance with parallel processing:
gitleaks dir code/ --no-banner

# Use baseline to skip already-known findings:
gitleaks dir code/ --baseline-path reports/gitleaks/baseline.json
```

**Create a baseline** (suppress known FPs from recurring):
```bash
# Generate baseline once:
gitleaks dir code/ --report-format json --report-path reports/gitleaks/baseline.json

# Future scans only report NEW findings:
gitleaks dir code/ --baseline-path reports/gitleaks/baseline.json
```

---

## 5. SonarQube Incremental Analysis (Branch Analysis)

Enable branch analysis for PR decoration (reduces full scan to diff-only):

```bash
# In CI, for a pull request:
sonar-scanner \
  -Dsonar.projectKey=secure-bank-app \
  -Dsonar.pullrequest.key=$PR_NUMBER \
  -Dsonar.pullrequest.branch=$SOURCE_BRANCH \
  -Dsonar.pullrequest.base=main
```

SonarQube then only analyzes **changed lines**, making PR scans much faster.

---

## 6. Parallelizing in CI

Run Gitleaks and Dep-Check in parallel (they're independent):

```yaml
# GitHub Actions — matrix/parallel jobs
jobs:
  secrets-scan:
    # Gitleaks — runs independently
  dependency-check:
    # Dep-Check — runs independently  
  sonarqube-sast:
    needs: secrets-scan   # Only blocks on Gitleaks (secrets are critical)
```

**Total pipeline time comparison:**
| Configuration | Time |
|---|---|
| Sequential (all 3 tools) | ~15–25 min |
| Parallel (Gitleaks + Dep-Check, then Sonar) | ~8–12 min |
| With NVD cache + branch analysis | ~3–5 min |

---

## 7. Quality Gate Tuning

Adjust quality gate thresholds to avoid spurious failures that slow down iteration:

```
Recommended for development branches:
  - New Vulnerabilities = 0 (strict on new code)
  - Existing Tech Debt = Warning only (don't block)

Recommended for main/release branches:
  - All Vulnerabilities = 0
  - Security Rating = A
  - Coverage >= 80%
```

---

## 8. vm.max_map_count (Permanent Fix)

Instead of setting on each start, make it permanent:

```bash
# Add to /etc/sysctl.conf
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p    # apply without reboot
```

---

## Quick Reference — Tuning Cheat Sheet

| Goal | Action |
|---|---|
| Faster startup | Add `-Djava.security.egd=file:/dev/./urandom` to web JVM opts |
| Less memory | Reduce heap sizes (min: 128m web, 512m CE, 512m ES) |
| Skip vendor code | Add `**/vendor/**` to `sonar.exclusions` |
| Cache NVD data | Use `--data` flag or CI cache action |
| Faster PR scans | Enable branch analysis with PR key |
| Avoid known FPs | Use Gitleaks `--baseline-path` |
| Parallel scanning | Run Gitleaks + Dep-Check as parallel CI jobs |
