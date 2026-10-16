<?php
require 'd:/magni/homeconnect/vendor/autoload.php';

$secret = '3f8a2c1e9d4b7f6e0a5c8d2b1e4f7a3c';
$token = hash_hmac('sha256', 'authenticate', $secret);
echo "HMAC token: $token\n";

try {
    $kernel = new \App\Kernel('dev', true);
    $kernel->boot();
    $container = $kernel->getContainer();
    $csrf = $container->get('security.csrf.token_manager');
    $realToken = $csrf->getToken('authenticate');
    echo "Real kernel token: $realToken\n";
} catch (\Throwable $e) {
    echo "Kernel error: " . $e->getMessage() . "\n";
}
