<?php
$host = '127.0.0.1';
$db   = 'homeconnect';
$user = 'root';
$pass = '';
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
     $pdo = new PDO($dsn, $user, $pass, $options);
     
     $email = 'admin@homeconnect.com';
     $newHash = '$2y$13$LDHEPnpjAhICfwf/Cg5Dh.rmPrvVU6oTyrNltCfMWlXBeZeEjtzb.'; // hash for 'admin123'
     
     $stmt = $pdo->prepare("UPDATE user SET password = ? WHERE email = ?");
     $stmt->execute([$newHash, $email]);
     
     if ($stmt->rowCount() > 0) {
         echo "Successfully updated password for $email to 'admin123'\n";
     } else {
         echo "No changes made. Either user $email doesn't exist or already has this password.\n";
     }
     
} catch (\PDOException $e) {
     throw new \PDOException($e->getMessage(), (int)$e->getCode());
}
