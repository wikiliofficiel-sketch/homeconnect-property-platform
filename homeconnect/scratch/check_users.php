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

$users = $entityManager->getRepository(User::class)->findAll();

echo "ID | Email | Roles | Has Password?\n";
echo "---|-------|-------|--------------\n";
foreach ($users as $user) {
    $roles = implode(', ', $user->getRoles());
    $hasPassword = $user->getPassword() ? 'Yes' : 'No';
    echo "{$user->getId()} | {$user->getEmail()} | $roles | $hasPassword\n";
}
