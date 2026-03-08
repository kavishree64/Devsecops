# SonarQube RBAC Setup Guide

This document covers setting up **Role-Based Access Control (RBAC)** in SonarQube for the Secure Bank App project. It defines three roles: **Admin**, **Developer**, and **Reviewer**.

---

## Prerequisites

- SonarQube running at `http://localhost:9000`
- Logged in as `admin` (default password: `admin` — change immediately on first login)

---

## Step 1: Change Default Admin Password

> [!CAUTION]
> SonarQube ships with `admin/admin`. Change this immediately before any other configuration.

1. Log in at `http://localhost:9000` with `admin / admin`
2. You will be prompted to change the password on first login
3. Choose a strong password (min 12 chars, mixed case, numbers, symbols)

Or via API:
```bash
curl -u admin:admin -X POST "http://localhost:9000/api/users/change_password" \
  -d "login=admin&previousPassword=admin&password=NewStr0ngP@ss!"
```

---

## Step 2: Disable Anonymous Access

1. Go to **Administration → Security → General**
2. Set **"Force user authentication"** to `ON`
3. Click **Save**

```bash
# Via API:
curl -u admin:NewStr0ngP@ss! -X POST \
  "http://localhost:9000/api/settings/set?key=sonar.forceAuthentication&value=true"
```

---

## Step 3: Create User Groups

Navigate to **Administration → Security → Groups**

| Group Name | Description | Permissions |
|---|---|---|
| `admins` | Full system control | Browse, Admin Project, Quality Gate Admin, Global Admin |
| `developers` | Write code, view results | Browse, Execute Analysis |
| `reviewers` | Read-only view + comments | Browse |

```bash
# Create groups via API:
BASE_URL="http://localhost:9000"
AUTH="-u admin:NewStr0ngP@ss!"

curl $AUTH -X POST "$BASE_URL/api/user_groups/create" -d "name=developers&description=Developer team"
curl $AUTH -X POST "$BASE_URL/api/user_groups/create" -d "name=reviewers&description=Code reviewer team"
```

---

## Step 4: Create Users and Assign Groups

Navigate to **Administration → Security → Users → Create User**

| Username | Full Name | Role |
|---|---|---|
| `dev.alice` | Alice Dev | developers |
| `dev.bob` | Bob Dev | developers |
| `review.carol` | Carol Reviewer | reviewers |

```bash
# Create a user via API:
curl $AUTH -X POST "$BASE_URL/api/users/create" \
  -d "login=dev.alice&name=Alice Dev&password=AliceTemp123!&email=alice@company.com"

# Add to group:
curl $AUTH -X POST "$BASE_URL/api/user_groups/add_user" \
  -d "login=dev.alice&name=developers"
```

---

## Step 5: Assign Project-Level Permissions

Navigate to **Project Settings → Permissions** (for project `secure-bank-app`)

| Group | Permission | Description |
|---|---|---|
| `admins` | Admin | Full project control |
| `admins` | Execute Analysis | Run scans |
| `admins` | Issue Admin | Manage false positives |
| `developers` | Browse | View results and issues |
| `developers` | Execute Analysis | Trigger scans from CI |
| `developers` | Issue Admin | Mark issues as false positive |
| `reviewers` | Browse | View results only |

```bash
# Assign permissions via API:
PROJECT_KEY="secure-bank-app"

curl $AUTH -X POST "$BASE_URL/api/permissions/add_group" \
  -d "projectKey=$PROJECT_KEY&groupName=developers&permission=codeviewer"

curl $AUTH -X POST "$BASE_URL/api/permissions/add_group" \
  -d "projectKey=$PROJECT_KEY&groupName=developers&permission=scan"

curl $AUTH -X POST "$BASE_URL/api/permissions/add_group" \
  -d "projectKey=$PROJECT_KEY&groupName=reviewers&permission=codeviewer"
```

---

## Step 6: Generate Scanner Tokens (CI/CD Integration)

Each CI run should use a **dedicated user token**, not admin credentials.

1. Log in as `admin`
2. Go to **Administration → Security → Users → dev.alice → Tokens**
3. Click **Generate Tokens** → Name: `ci-scanner-token` → Type: `Project Analysis Token`
4. Copy the token immediately (it won't be shown again!)

```bash
# Via API:
curl $AUTH -X POST "$BASE_URL/api/user_tokens/generate" \
  -d "login=dev.alice&name=ci-scanner-token&type=PROJECT_ANALYSIS_TOKEN&projectKey=secure-bank-app"
```

**Use the token in scans:**
```bash
# Option 1: Pass as argument
bash scripts/run_sonar_scan.sh "sqa_<your_token_here>"

# Option 2: Set as environment variable (recommended for CI)
export SONAR_TOKEN="sqa_<your_token_here>"
bash scripts/run_sonar_scan.sh
```

---

## Step 7: Quality Gate Configuration

1. Go to **Administration → Quality Gates**
2. Create a gate named `DevSecOps Gate`
3. Add conditions:

| Metric | Condition | Threshold |
|---|---|---|
| Security Rating | Worse than | **A** |
| Vulnerabilities | Greater than | **0** |
| Security Hotspots Reviewed | Less than | **100%** |
| Bugs | Greater than | **5** |

4. Set this gate as **default** → click **Set as Default**
5. Assign to project: **Project Settings → Quality Gate → DevSecOps Gate**

---

## RBAC Permission Reference

| Permission | Admin | Developer | Reviewer |
|---|---|---|---|
| Browse project | ✅ | ✅ | ✅ |
| See source code | ✅ | ✅ | ❌ |
| Execute analysis (CI) | ✅ | ✅ | ❌ |
| Administer issues | ✅ | ✅ | ❌ |
| Administer project | ✅ | ❌ | ❌ |
| Global Admin | ✅ | ❌ | ❌ |
| Quality Gate Admin | ✅ | ❌ | ❌ |

---

## Collaboration Features

### Issue Comments
- Any user with **Browse** permission can comment on issues
- Navigate to an issue → Click **Add Comment**
- Use `@mention` to notify teammates

### Issue Assignment
Users with **Issue Admin** permission can:
- Assign issues to developers
- Mark issues as **Won't Fix** or **False Positive** with justification
- Transition issue status (Open → Confirmed → Resolved)

### Custom Rules
Administrators can add organization-specific rules:
1. Go to **Administration → Rules**
2. Click **Create** to define a custom pattern rule
3. Attach it to a Quality Profile for activation
