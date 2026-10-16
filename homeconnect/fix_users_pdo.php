<?php
try {
    $pdo = new PDO('mysql:host=127.0.0.1;dbname=homeconnect', 'root', '');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $sql = "UPDATE user SET roles = '[\"ROLE_PROPRIETAIRE\"]' WHERE roles = '[]' OR roles IS NULL OR roles = ''";
    $count = $pdo->exec($sql);
    echo "Updated $count users.\n";
    
    // Specifically update the common test emails just in case
    $emails = ['magnificat@gmail.com', 'houessoumagnificat@gmail.com', 'magni@gmail.com'];
    foreach ($emails as $email) {
        $sql = "UPDATE user SET roles = '[\"ROLE_PROPRIETAIRE\"]' WHERE email = " . $pdo->quote($email);
        $pdo->exec($sql);
    }
    echo "Done.\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
