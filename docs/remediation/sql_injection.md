# SQL Injection — Remediation Guide

## Classification

| Standard | ID | Severity |
|---|---|---|
| **OWASP Top 10** | A03:2021 — Injection | 🔴 Critical |
| **SANS/CWE** | CWE-89: SQL Injection | Critical |
| **CERT** | IDS00-J / IDS07-J | High |
| **CVSS v3 Base Score** | Up to 10.0 (full database compromise) | |

---

## What Was Found

In `php login process php.php`, lines 11–16:

```php
// VULNERABLE CODE
$user = $_POST['username'];   // ← raw, unsanitised user input
$pass = $_POST['password'];

$query = "SELECT * FROM users WHERE username = '$user' AND password = '$pass'";
$result = mysqli_query($conn, $query);
```

The user's input is concatenated directly into the SQL string. An attacker can manipulate the SQL logic by entering:

```
Username:  ' OR '1'='1' --
Password:  anything
```

This transforms the query into:

```sql
SELECT * FROM users WHERE username = '' OR '1'='1' -- ' AND password = 'anything'
```

The `--` comments out the password check, and `'1'='1'` is always true → **authentication bypassed**.

---

## Attack Scenarios

| Attack | Payload | Impact |
|---|---|---|
| **Auth Bypass** | `' OR '1'='1' --` | Login without credentials |
| **Data Extraction** | `' UNION SELECT table_name,2,3 FROM information_schema.tables --` | Dump all table names |
| **Data Deletion** | `'; DROP TABLE users; --` | Destroy the database |
| **Blind Injection** | `' AND SLEEP(5) --` | Confirm injection point |

---

## Remediation: Use Prepared Statements

Replace the vulnerable code with **parameterized queries (prepared statements)**:

```php
<?php
// SECURE CODE — Using MySQLi Prepared Statements

$db_host = getenv('DB_HOST') ?: 'localhost';
$db_user = getenv('DB_USER') ?: 'app_user';
$db_pass = getenv('DB_PASS');          // read from environment — never hardcode
$db_name = getenv('DB_NAME') ?: 'bank_db';

$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    // Never expose error details to the user
    error_log("DB connection failed: " . $conn->connect_error);
    http_response_code(500);
    die("Internal server error.");
}

$user = $_POST['username'] ?? '';
$pass = $_POST['password'] ?? '';

// ✅ FIX: Prepared statement with bound parameters
//    The SQL structure is fixed; user input is ONLY ever treated as data, never code.
$stmt = $conn->prepare("SELECT id, username FROM users WHERE username = ? AND password = ?");
$stmt->bind_param("ss", $user, $pass);    // "ss" = two string parameters
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    // ✅ Never echo raw user input back. Use the DB value instead.
    echo "<h1>Welcome back, " . htmlspecialchars($row['username'], ENT_QUOTES, 'UTF-8') . "!</h1>";
} else {
    echo "Invalid credentials.";    // generic message — don't reveal which field was wrong
}

$stmt->close();
$conn->close();
?>
```

---

## Why Prepared Statements Work

Prepared statements **separate SQL code from data**:
1. The database compiles the query template (fixed structure)
2. User input is passed as a separate parameter — the DB treats it as a literal string, never as SQL code
3. Even `' OR '1'='1' --` is treated as the literal username string, not SQL syntax

---

## Additional Defences

| Defence | Implementation |
|---|---|
| **Input Validation** | Validate that `username` matches expected format (e.g., `[a-zA-Z0-9_]{3,50}`) |
| **Least Privilege DB Account** | App DB user should only have SELECT on needed tables, no DROP/CREATE |
| **WAF** | A Web Application Firewall can detect and block common injection patterns |
| **Password Hashing** | Never store plaintext passwords — use `password_hash()` / `password_verify()` in PHP |
| **Error Handling** | Use `error_log()` not `echo` for errors; never expose DB structure in user-facing messages |

---

## References
- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [PHP Manual — MySQLi Prepared Statements](https://www.php.net/manual/en/mysqli.prepare.php)
- [CWE-89 Detail](https://cwe.mitre.org/data/definitions/89.html)
