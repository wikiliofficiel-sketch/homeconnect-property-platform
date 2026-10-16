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

$emails = ['tenant1@test.com', 'owner1@test.com'];

foreach ($emails as $email) {
    $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $email]);
    if ($user) {
        $user->setPassword($passwordHasher->hashPassword($user, 'password'));
        echo "Password for $email reset to 'password'\n";
    } else {
        echo "User $email not found\n";
    }
}

$entityManager->flush();
