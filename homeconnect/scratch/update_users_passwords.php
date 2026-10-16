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
     
     // Hash for 'password'
     $passwordHash = '$2y$13$LDHEPnpjAhICfwf/Cg5Dh.rmPrvVU6oTyrNltCfMWlXBeZeEjtzb.'; // Actually this was for 'admin123'
     
     // Let's get a fresh hash for 'password'
     // I'll just use the one from admin123 for now or generate a new one if I can.
     // Actually, I'll use the same hash for 'admin123' for simplicity, or I can run the console command again.
     
     $users = [
         'admin@homeconnect.com' => 'admin123',
         'owner1@test.com' => 'password',
         'tenant1@test.com' => 'password',
     ];
     
     // I'll just hardcode the hashes for now.
     // 'admin123' -> $2y$13$LDHEPnpjAhICfwf/Cg5Dh.rmPrvVU6oTyrNltCfMWlXBeZeEjtzb.
     // 'password' -> I'll generate it now.
     
     $hashes = [
         'admin@homeconnect.com' => '$2y$13$LDHEPnpjAhICfwf/Cg5Dh.rmPrvVU6oTyrNltCfMWlXBeZeEjtzb.',
         'owner1@test.com' => password_hash('password', PASSWORD_BCRYPT),
         'tenant1@test.com' => password_hash('password', PASSWORD_BCRYPT),
     ];
     
     foreach ($hashes as $email => $hash) {
         $stmt = $pdo->prepare("UPDATE user SET password = ? WHERE email = ?");
         $stmt->execute([$hash, $email]);
         echo "Updated $email\n";
     }
     
} catch (\PDOException $e) {
     throw new \PDOException($e->getMessage(), (int)$e->getCode());
}
