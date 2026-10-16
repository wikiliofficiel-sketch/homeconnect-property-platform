<?php
require 'vendor/autoload.php';
use App\Kernel;
use Symfony\Bundle\FrameworkBundle\Console\Application;
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Output\NullOutput;

$kernel = new Kernel('dev', true);
$kernel->boot();
$container = $kernel->getContainer();
$em = $container->get('doctrine.orm.entity_manager');
$userRepo = $em->getRepository(\App\Entity\User::class);

$users = $userRepo->findAll();
foreach ($users as $user) {
    if (empty($user->getRoles()) || $user->getRoles() === ['ROLE_USER']) {
        $user->setRoles(['ROLE_PROPRIETAIRE']);
        echo "Updated " . $user->getEmail() . "\n";
    }
}
$em->flush();
