<?php
require 'vendor/autoload.php';

use App\Kernel;
use Symfony\Component\Dotenv\Dotenv;
use App\Entity\User;

(new Dotenv())->bootEnv('.env');
$kernel = new Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();

$container = $kernel->getContainer();
$passwordHasher = $container->get('security.user_password_hasher');

$user = new User();
$hash = '$2y$13$XKeQgOU2YPn04upMDTpLoOrpVawQM9dNLF7ZTCXB3aDLJ2vOzsSBq';
$user->setPassword($hash);

if ($passwordHasher->isPasswordValid($user, 'password')) {
    echo "Hash is VALID for 'password'\n";
} else {
    echo "Hash is INVALID for 'password'\n";
}
