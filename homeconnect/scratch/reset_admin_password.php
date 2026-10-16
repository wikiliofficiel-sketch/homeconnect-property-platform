<?php

use App\Entity\User;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

require __DIR__.'/../vendor/autoload.php';

$kernel = new App\Kernel('dev', true);
$kernel->boot();

$container = $kernel->getContainer();
$entityManager = $container->get('doctrine')->getManager();
$passwordHasher = $container->get(UserPasswordHasherInterface::class);

$user = $entityManager->getRepository(User::class)->findOneBy(['email' => 'admin@homeconnect.com']);

if ($user) {
    $user->setPassword($passwordHasher->hashPassword($user, 'admin123'));
    $entityManager->flush();
    echo "Password updated for admin@homeconnect.com\n";
} else {
    echo "Admin user not found\n";
}
