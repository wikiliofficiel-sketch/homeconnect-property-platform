<?php

namespace App\Command;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[AsCommand(
    name: 'app:reset-admin',
    description: 'Resets the admin password to admin123',
)]
class ResetAdminPasswordCommand extends Command
{
    public function __construct(
        private EntityManagerInterface $entityManager,
        private UserPasswordHasherInterface $passwordHasher
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addOption('email', null, \Symfony\Component\Console\Input\InputOption::VALUE_REQUIRED, 'L\'email de l\'utilisateur à réinitialiser', 'admin@homeconnect.com');
        $this->addOption('password', null, \Symfony\Component\Console\Input\InputOption::VALUE_REQUIRED, 'Le nouveau mot de passe', 'admin123');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $email = $input->getOption('email');
        $password = $input->getOption('password');
        $user = $this->entityManager->getRepository(User::class)->findOneBy(['email' => $email]);

        if (!$user) {
            $output->writeln("User $email not found. Creating new admin user...");
            $user = new User();
            $user->setEmail($email);
            $user->setPrenom('Admin');
            $user->setNom('HomeConnect');
            $user->setRoles(['ROLE_ADMIN']);
            $user->setCreatedAt(new \DateTimeImmutable());
            $this->entityManager->persist($user);
        }

        $password = 'admin123';
        $hashedPassword = $this->passwordHasher->hashPassword($user, $password);
        $user->setPassword($hashedPassword);

        $this->entityManager->flush();

        $output->writeln("Password for $email has been reset to '$password'.");
        $output->writeln("Hashed password stored: $hashedPassword");

        return Command::SUCCESS;
    }
}
