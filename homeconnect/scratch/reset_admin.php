<?php
require 'vendor/autoload.php';

use App\Kernel;
use Symfony\Component\Dotenv\Dotenv;
use App\Entity\User;

(new Dotenv())->bootEnv('.env');
$kernel = new Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();

$container = $kernel->getContainer();
$entityManager = $container->get('doctrine.orm.entity_manager');
$passwordHasher = $container->get('security.user_password_hasher');

$email = 'admin@homeconnect.com';
$user = $entityManager->getRepository(User::class)->findOneBy(['email' => $email]);

if ($user) {
    $hashedPassword = $passwordHasher->hashPassword($user, 'admin123');
    $user->setPassword($hashedPassword);
    $entityManager->flush();
    echo "Password for $email has been reset to 'admin123'\n";
} else {
    echo "User $email not found\n";
}
