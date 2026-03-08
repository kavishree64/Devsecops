<?php
// login_process.php

// VULNERABILITY: Hardcoded sensitive credentials
$db_host = "localhost";
$db_user = "root";
$db_pass = "SuperSecretPassword123!"; // SonarQube will flag this as a "Secret"

$conn = mysqli_connect($db_host, $db_user, $db_pass, "bank_db");

$user = $_POST['username'];
$pass = $_POST['password'];

// VULNERABILITY: SQL Injection (OWASP Top 10 #1)
// The input is NOT sanitized or prepared. An attacker can use ' OR '1'='1
$query = "SELECT * FROM users WHERE username = '$user' AND password = '$pass'";
$result = mysqli_query($conn, $query);

if (mysqli_num_rows($result) > 0) {
    // VULNERABILITY: Reflected XSS (Cross-Site Scripting)
    // Printing user input directly back to the screen without encoding
    echo "<h1>Welcome back, " . $user . "!</h1>";
    echo "<p>Your current balance is $1,250,000.00</p>";
} else {
    echo "Invalid login.";
}
?>
