<?php

namespace App\Command;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[AsCommand(name: 'app:fix-admin')]
class FixAdminCommand extends Command
{
    public function __construct(
        private EntityManagerInterface $entityManager,
        private UserPasswordHasherInterface $passwordHasher
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $user = $this->entityManager->getRepository(User::class)->findOneBy(['email' => 'admin@homeconnect.com']);

        if (!$user) {
            $user = new User();
            $user->setEmail('admin@homeconnect.com');
            $user->setPrenom('Admin');
            $user->setNom('Super');
            $user->setRoles(['ROLE_ADMIN']);
            $this->entityManager->persist($user);
        }

        $user->setPassword($this->passwordHasher->hashPassword($user, 'admin123'));
        $this->entityManager->flush();

        $output->writeln('Admin password fixed to: admin123');
        return Command::SUCCESS;
    }
}
