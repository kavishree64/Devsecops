# DevSecOps Code Review Framework

A **modular, automated security scanning pipeline** integrating secrets detection, software composition analysis (SCA), and static application security testing (SAST) — built around SonarQube, OWASP Dependency-Check, and Gitleaks.

[![Security Pipeline](https://img.shields.io/badge/Pipeline-Gitleaks%20%7C%20OWASP%20%7C%20SonarQube-blue)](#)
[![OWASP](https://img.shields.io/badge/OWASP-Top%2010%20Mapped-orange)](#)
[![Standards](https://img.shields.io/badge/Standards-SANS%20CWE%20%7C%20CERT-green)](#)

---

## 🗂 Project Structure

```
Devsecops/
├── code/              ← Target application (vulnerable PHP demo)
├── scripts/           ← Automation scripts (scan, report, CI)
├── docs/
│   ├── ARCHITECTURE.md          ← System design & pipeline diagram
│   ├── rbac_setup.md            ← SonarQube auth & RBAC guide
│   ├── performance_tuning.md    ← Optimization strategies
│   ├── remediation/             ← Fix guides per vulnerability type
│   └── reports/dashboard.html  ← Security findings dashboard
├── reports/           ← Generated scan outputs
├── .github/workflows/ ← GitHub Actions CI pipeline
├── sonarqube-*/       ← SonarQube server
├── sonar-scanner-*/   ← Scanner CLI
└── dependency-check/  ← OWASP Dep-Check CLI
```

---

## 🚀 Quick Start

### Prerequisites
- Java 17+ (`java -version`)
- Bash
- Internet access (first run — downloads Gitleaks binary & NVD database)

### Step 1: Start SonarQube
```bash
bash scripts/start_sonarqube.sh
# SonarQube will be available at: http://localhost:9000
# Default credentials: admin / admin  ← Change immediately!
```

### Step 2: Run the Full Security Pipeline
```bash
# Run all 3 scanners (Gitleaks + Dep-Check + SonarQube)
bash scripts/ci_pipeline.sh [SONAR_TOKEN]
```

### Step 3: View Results
```bash
# Open the HTML security dashboard:
xdg-open docs/reports/dashboard.html

# Or visit SonarQube directly:
xdg-open http://localhost:9000/dashboard?id=secure-bank-app
```

---

## 🛠 Individual Scan Commands

| Script | What it Does |
|---|---|
| `bash scripts/start_sonarqube.sh` | Start SonarQube server (first-time setup) |
| `bash scripts/run_gitleaks.sh` | Scan `code/` for hardcoded secrets |
| `bash scripts/run_dependency_check.sh` | Scan for known CVEs in dependencies |
| `bash scripts/run_sonar_scan.sh` | Run SAST scan and upload to SonarQube |
| `bash scripts/ci_pipeline.sh` | Full pipeline — all 3 tools in sequence |
| `bash scripts/generate_report.sh` | Merge all scan outputs into summary JSON |

---

## 🪝 Git Pre-Commit Hook

Block secrets from ever being committed:

```bash
# Install the hook in any repo
cp scripts/pre-commit-hook.sh /path/to/your-repo/.git/hooks/pre-commit
chmod +x /path/to/your-repo/.git/hooks/pre-commit
```

To bypass in an emergency:
```bash
SKIP=gitleaks git commit -m "emergency fix"
```

---

## 🔬 What Gets Scanned

The **target application** (`code/`) is an intentionally vulnerable PHP banking login page containing:

| Vulnerability | Severity | Standard | Scanner |
|---|---|---|---|
| SQL Injection | 🔴 Critical | CWE-89 / OWASP A03 | SonarQube |
| Reflected XSS | 🔴 High | CWE-79 / OWASP A03 | SonarQube |
| Hardcoded Password | 🔴 Critical | CWE-798 / OWASP A07 | Gitleaks + SonarQube |
| Information Disclosure | 🟡 Medium | CWE-200 / OWASP A05 | SonarQube |

---

## 🔐 Authentication & RBAC

Three roles are defined for SonarQube:

| Role | Permissions |
|---|---|
| `admins` | Full system + project control |
| `developers` | Browse results, run scans, manage issues |
| `reviewers` | Read-only view of findings |

→ See **[docs/rbac_setup.md](docs/rbac_setup.md)** for full setup instructions.

---

## 📖 Documentation

| Document | Description |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Pipeline diagram, component overview, data flow |
| [rbac_setup.md](docs/rbac_setup.md) | SonarQube RBAC, tokens, quality gates |
| [performance_tuning.md](docs/performance_tuning.md) | JVM tuning, caching, parallel scans |
| [sql_injection.md](docs/remediation/sql_injection.md) | SQL injection fix guide + examples |
| [xss.md](docs/remediation/xss.md) | XSS fix guide + CSP headers |
| [hardcoded_credentials.md](docs/remediation/hardcoded_credentials.md) | Secrets management guide |
| [OWASP_SANS_CERT_mapping.md](docs/remediation/OWASP_SANS_CERT_mapping.md) | Standards cross-reference table |

---

## ⚙️ CI/CD Integration

The **GitHub Actions workflow** (`.github/workflows/devsecops.yml`) runs automatically on push/PR:

```
Push / PR
    ↓
Stage 1: Gitleaks (secrets scan)          ← Runs in parallel with Dep-Check
Stage 2: OWASP Dep-Check (SCA)            ←
    ↓
Stage 3: SonarQube SAST
    ↓
Quality Gate: Pass → Merge | Fail → Block
```

### Required GitHub Secrets
| Secret | Value |
|---|---|
| `SONAR_TOKEN` | SonarQube user token (from Admin → Users → Tokens) |
| `SONAR_HOST_URL` | `http://localhost:9000` or your hosted SonarQube URL |

---

## 🧰 Tool Versions

| Tool | Version | Role |
|---|---|---|
| SonarQube | 26.3.0.120487 | SAST Platform |
| SonarQube Scanner CLI | 5.0.1.3006 | Analysis runner |
| OWASP Dependency-Check | 12.2.0 | SCA / CVE scanning |
| Gitleaks | v8.24.2 | Secrets scanning |
| Java | OpenJDK 21 | Runtime |

---

## 📜 Standards Compliance

| Standard | Coverage |
|---|---|
| OWASP Top 10 (2021) | A03, A05, A06, A07 mapped and detected |
| SANS CWE Top 25 | CWE-79, CWE-89, CWE-200, CWE-798 |
| CERT Secure Coding | IDS00, IDS51, MSC03, MSC41 |

---

## ⚡ Performance

| Scan | Cold Run | With Cache |
|---|---|---|
| Gitleaks | < 5s | < 2s |
| OWASP Dep-Check | 5–15 min | 30–60s |
| SonarQube SAST | 1–3 min | 30–90s (branch scan) |
| **Full pipeline** | ~20 min | **~3–5 min** |

→ See **[docs/performance_tuning.md](docs/performance_tuning.md)** for optimization strategies.
