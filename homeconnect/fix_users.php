<?php
require 'vendor/autoload.php';
use App\Kernel;

$kernel = new Kernel('dev', true);
$kernel->boot();
$container = $kernel->getContainer();
$em = $container->get('doctrine.orm.entity_manager');

$emails = ['magnificat@gmail.com', 'houessoumagnificat@gmail.com', 'magni@gmail.com'];
foreach ($emails as $email) {
    $user = $em->getRepository(\App\Entity\User::class)->findOneBy(['email' => $email]);
    if ($user) {
        $user->setRoles(['ROLE_PROPRIETAIRE']);
        echo "Updated $email\n";
    }
}
$em->flush();
