<?php
require 'vendor/autoload.php';
use App\Kernel;
use Symfony\Component\Dotenv\Dotenv;
use App\Entity\User;

$dotenv = new Dotenv();
$dotenv->load(__DIR__.'/.env');

$kernel = new Kernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$kernel->boot();
$container = $kernel->getContainer();
$em = $container->get('doctrine.orm.entity_manager');
$hasher = $container->get('security.user_password_hasher');

$admin = $em->getRepository(User::class)->findOneBy(['email' => 'admin@homeconnect.com']);
if ($admin) {
    $admin->setPassword($hasher->hashPassword($admin, 'admin123'));
    $em->flush();
    echo "Password reset to admin123 for admin@homeconnect.com\n";
} else {
    echo "Admin not found\n";
}
