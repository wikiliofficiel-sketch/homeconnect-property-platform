<?php
require __DIR__.'/vendor/autoload.php';
use App\Entity\User;
use Symfony\Component\Dotenv\Dotenv;
use Doctrine\ORM\EntityManagerInterface;

$dotenv = new Dotenv();
$dotenv->load(__DIR__.'/ .env.test');

$kernel = new App\Kernel($_SERVER['APP_ENV'] ?? 'test', true);
$kernel->boot();
/** @var EntityManagerInterface $em */
$em = $kernel->getContainer()->get('doctrine')->getManager();

$email = 'admin@homeconnect.com';
$user = $em->getRepository(User::class)->findOneBy(['email' => $email]);

if ($user) {
    // reset password and ensure admin role
    $hashed = password_hash('admin123', PASSWORD_BCRYPT);
    $user->setPassword($hashed);
    $roles = $user->getRoles();
    if (!in_array('ROLE_ADMIN', $roles, true)) {
        $roles[] = 'ROLE_ADMIN';
        $user->setRoles($roles);
    }
    $em->flush();
    echo "Admin user password reset and role ensured.\n";
} else {
    $user = new User();
    $user->setEmail($email);
    $user->setRoles(['ROLE_ADMIN']);
    $hashed = password_hash('admin123', PASSWORD_BCRYPT);
    $user->setPassword($hashed);
    $em->persist($user);
    $em->flush();
    echo "Admin user created.\n";
}
?>
