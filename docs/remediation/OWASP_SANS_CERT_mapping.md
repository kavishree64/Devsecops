# Vulnerability Standards Mapping

This document maps each detected vulnerability in the **Secure Bank App** to OWASP Top 10, SANS CWE, CERT, and the specific tool that detects it.

---

## Master Mapping Table

| # | Vulnerability | OWASP Top 10 (2021) | CWE (SANS Top 25) | CERT Rule | Severity | SonarQube Rule | Gitleaks Rule | Dep-Check |
|---|---|---|---|---|---|---|---|---|
| 1 | **SQL Injection** | A03 — Injection | CWE-89 | IDS00-J / IDS07-J | 🔴 Critical | `php:S3649` | — | — |
| 2 | **Reflected XSS** | A03 — Injection (XSS) | CWE-79 | IDS51-J / IDS16-J | 🔴 High | `php:S5131` | — | — |
| 3 | **Hardcoded Password** | A07 — Auth Failures | CWE-798 | MSC03-J / MSC41-J | 🔴 Critical | `php:S2068` | `php-db-password` | — |
| 4 | **Missing Prepared Stmt** | A03 — Injection | CWE-89 | IDS00-J | 🔴 Critical | `php:S3649` | — | — |
| 5 | **Information Disclosure** | A05 — Security Misconfig | CWE-200 | ERR01-J | 🟡 Medium | `php:S2228` | — | — |
| 6 | **No Input Validation** | A03 — Injection | CWE-20 | IDS01-J | 🟡 Medium | `php:S2068` | — | — |
| 7 | **Known Vulnerable Libs** | A06 — Vulnerable Components | CWE-1035 | — | Varies | — | — | ✅ OWASP Dep-Check |

---

## OWASP Top 10 (2021) Coverage

| OWASP Category | Description | Found in Project | Remediation Doc |
|---|---|---|---|
| **A01 — Broken Access Control** | Missing authorization checks | Not detected (no auth system tested) | — |
| **A02 — Cryptographic Failures** | Weak/missing encryption, plaintext passwords | Plaintext password in DB query | `hardcoded_credentials.md` |
| **A03 — Injection** | SQL injection, XSS, command injection | ✅ SQL Injection + XSS detected | `sql_injection.md`, `xss.md` |
| **A04 — Insecure Design** | No threat modelling or secure design | Architectural issues in login flow | — |
| **A05 — Security Misconfiguration** | Default configs, verbose errors | DB errors could be exposed | `hardcoded_credentials.md` |
| **A06 — Vulnerable Components** | Known CVEs in libraries/dependencies | OWASP Dep-Check covers this | Run `scripts/run_dependency_check.sh` |
| **A07 — Auth & Session Failures** | Broken auth, hardcoded credentials | ✅ Hardcoded DB password detected | `hardcoded_credentials.md` |
| **A08 — Software & Data Integrity** | Insecure deserialization, unsigned updates | Not in scope for this app | — |
| **A09 — Logging & Monitoring Failures** | No audit logging | No login attempt logging | — |
| **A10 — SSRF** | Server-side request forgery | Not in scope for this app | — |

---

## SANS CWE Top 25 Coverage

| Rank | CWE | Name | Present | Tool |
|---|---|---|---|---|
| 1 | CWE-787 | Out-of-bounds Write | No | — |
| 2 | CWE-79 | Cross-site Scripting | ✅ Yes | SonarQube |
| 3 | CWE-89 | SQL Injection | ✅ Yes | SonarQube |
| 4 | CWE-416 | Use After Free | No (n/a PHP) | — |
| 5 | CWE-78 | OS Command Injection | Not detected | SonarQube |
| 6 | CWE-20 | Improper Input Validation | ✅ Yes | SonarQube |
| 7 | CWE-125 | Out-of-bounds Read | No (n/a PHP) | — |
| 8 | CWE-22 | Path Traversal | Not tested | SonarQube |
| 9 | CWE-352 | CSRF | Not implemented | SonarQube |
| 10 | CWE-434 | Unrestricted File Upload | Not in scope | — |
| 15 | CWE-798 | Hardcoded Credentials | ✅ Yes | SonarQube + Gitleaks |
| 19 | CWE-200 | Info Exposure | ✅ Yes (email in HTML) | SonarQube |

---

## CERT Secure Coding Rules (Java/General mapping to PHP)

| CERT Rule | Description | Applicable Vuln | PHP Equivalent |
|---|---|---|---|
| **IDS00-J** | Prevent SQL injection | SQL Injection | Use PDO/MySQLi prepared stmts |
| **IDS07-J** | Sanitize untrusted data in SQL | SQL Injection | `bind_param()` |
| **IDS51-J** | Prevent CSS injection | XSS | `htmlspecialchars()` |
| **IDS16-J** | Prevent XSS | XSS | Output encoding |
| **MSC03-J** | Never hardcode sensitive info | Hardcoded Creds | Environment variables |
| **MSC41-J** | Never hardcode passwords in code | Hardcoded Creds | Secrets manager |
| **ERR01-J** | Do not expose exception info | Info Disclosure | `error_log()` not `echo` |

---

## Tool Responsibility Matrix

| Vulnerability Type | SonarQube (SAST) | Gitleaks (Secrets) | OWASP Dep-Check (SCA) |
|---|---|---|---|
| SQL Injection | ✅ Primary | — | — |
| Cross-Site Scripting | ✅ Primary | — | — |
| Hardcoded Secrets | ✅ Secondary | ✅ Primary | — |
| Vulnerable Libraries | — | — | ✅ Primary |
| Secret in Git History | — | ✅ Primary | — |
| Insecure Functions | ✅ Primary | — | — |

---

## Severity Scale

| Severity | CVSS Score | Action |
|---|---|---|
| 🔴 Critical | 9.0 – 10.0 | Fix immediately before any release |
| 🔴 High | 7.0 – 8.9 | Fix in current sprint |
| 🟡 Medium | 4.0 – 6.9 | Fix in next sprint |
| 🟢 Low | 0.1 – 3.9 | Fix during routine maintenance |
| ⚪ Info | 0.0 | Review and document risk acceptance |
