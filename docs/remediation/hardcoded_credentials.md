# Hardcoded Credentials — Remediation Guide

## Classification

| Standard | ID | Severity |
|---|---|---|
| **OWASP Top 10** | A07:2021 — Identification & Authentication Failures | 🔴 Critical |
| **SANS/CWE** | CWE-798: Use of Hard-coded Credentials | Critical |
| **CERT** | MSC03-J / MSC41-J | High |
| **CVSS v3 Base Score** | Up to 9.8 (full system compromise if exposed) | |

---

## What Was Found

In `php login process php.php`, line 7:

```php
// VULNERABLE CODE
$db_pass = "SuperSecretPassword123!"; // hardcoded in source
```

This password is:
- Stored in **version control** forever (even if deleted later, it remains in git history)
- **Visible to all developers** with repo access
- **Static** — cannot be rotated without a code change and redeployment
- Detectable by **Gitleaks** and **SonarQube** automatically

---

## Why This Is Critical

```
Source Code → Git Repository → GitHub/GitLab →
  → Developer laptops, CI servers, artifacts, backups
  → Anyone with repo access has the DB password
  → If the repo is public: the password is PUBLIC
```

Credentials in source code have caused major breaches:
- **Uber (2016)**: AWS keys in GitHub repo → 57M records stolen
- **Toyota (2023)**: Git submodule with hardcoded key → 296K customer records exposed

---

## Remediation: Environment Variables

```php
<?php
// SECURE CODE — Read credentials from environment variables

// ✅ FIX 1: Environment Variables (simplest, best for local dev)
$db_host = getenv('DB_HOST') ?: 'localhost';
$db_user = getenv('DB_USER') ?: 'app_user';
$db_pass = getenv('DB_PASS');    // no fallback — must be set explicitly
$db_name = getenv('DB_NAME') ?: 'bank_db';

if (!$db_pass) {
    error_log("DB_PASS environment variable is not set.");
    http_response_code(500);
    die("Configuration error.");
}

$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
?>
```

**Setting environment variables:**
```bash
# Linux/Mac — add to ~/.bashrc or ~/.bash_profile (local dev)
export DB_HOST=localhost
export DB_USER=app_user
export DB_PASS=SuperSecretPassword123!
export DB_NAME=bank_db

# In production (systemd service file):
[Service]
Environment="DB_PASS=<value from secrets manager>"

# In Docker:
docker run -e DB_PASS=yourpassword myapp

# In Docker Compose:
environment:
  - DB_PASS=${DB_PASS}     # reads from host .env file
```

---

## Remediation: .env File (Development Only)

```bash
# .env  (in project root — NEVER commit this file!)
DB_HOST=localhost
DB_USER=app_user
DB_PASS=SuperSecretPassword123!
DB_NAME=bank_db
```

```php
<?php
// ✅ FIX 2: Load .env file (use phpdotenv library)
// composer require vlucas/phpdotenv
require 'vendor/autoload.php';
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

$db_pass = $_ENV['DB_PASS'];
?>
```

**Critical: Add `.env` to `.gitignore`:**
```gitignore
# .gitignore
.env
.env.local
*.env
```

---

## Remediation: Secrets Manager (Production)

For production environments, use a dedicated secrets manager:

| Platform | Tool | PHP SDK |
|---|---|---|
| **AWS** | AWS Secrets Manager | `aws/aws-sdk-php` |
| **GCP** | Secret Manager | `google/cloud-secret-manager` |
| **Azure** | Key Vault | `azure/azure-sdk-for-php` |
| **HashiCorp** | Vault | `wandenberg/phelpit` |
| **Self-hosted** | Doppler, Infisical | REST API |

```php
<?php
// ✅ FIX 3: AWS Secrets Manager example
use Aws\SecretsManager\SecretsManagerClient;

$client = new SecretsManagerClient(['region' => 'us-east-1']);
$result = $client->getSecretValue(['SecretId' => 'prod/bank-db']);
$secret = json_decode($result['SecretString'], true);

$db_pass = $secret['password'];    // retrieved at runtime, never stored in code
?>
```

---

## Cleaning Git History

If credentials were already committed, **rotation alone is not enough** — they remain in git history:

```bash
# Step 1: Rotate the credential immediately (change the DB password)

# Step 2: Remove the credential from git history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch code/'php login process php.php'" \
  --prune-empty --tag-name-filter cat -- --all

# Step 3: Force-push the cleaned history
git push origin --force --all

# Step 4: Revoke access for anyone who may have cloned the repo
```

> [!WARNING]
> `git filter-branch` rewrites history and requires all collaborators to re-clone the repository. Coordinate this carefully.

---

## Preventive Controls

| Control | Tool | Setting |
|---|---|---|
| **Pre-commit hook** | Gitleaks | `scripts/pre-commit-hook.sh` |
| **CI secrets scan** | Gitleaks Action | `.github/workflows/devsecops.yml` |
| **SAST detection** | SonarQube | Rule `php:S2068` — Hardcoded passwords |
| **Secrets baseline** | Gitleaks `--baseline-path` | Suppress known FPs |

---

## References
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [CWE-798 Detail](https://cwe.mitre.org/data/definitions/798.html)
- [GitHub — Removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
