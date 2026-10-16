<?php

use App\Entity\User;
use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

require __DIR__.'/vendor/autoload.php';

(new Dotenv())->bootEnv(__DIR__.'/.env');

$kernel = new App\Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();

$container = $kernel->getContainer();
$entityManager = $container->get('doctrine')->getManager();
$passwordHasher = $container->get(UserPasswordHasherInterface::class);

$user = $entityManager->getRepository(User::class)->findOneBy(['email' => 'admin@homeconnect.com']);

if ($user) {
    $hashedPassword = $passwordHasher->hashPassword($user, 'admin123');
    $user->setPassword($hashedPassword);
    $entityManager->flush();
    echo "Password updated successfully for admin@homeconnect.com\n";
    echo "New hash: " . $hashedPassword . "\n";
} else {
    echo "User admin@homeconnect.com not found\n";
}
