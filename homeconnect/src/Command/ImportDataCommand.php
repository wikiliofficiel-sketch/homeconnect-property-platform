<?php

namespace App\Command;

use App\Entity\Property;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

#[AsCommand(
    name: 'app:import-data',
    description: 'Import data from a JSON file (exported from Flutter SharedPreferences)',
)]
class ImportDataCommand extends Command
{
    public function __construct(
        private EntityManagerInterface $entityManager,
        private UserPasswordHasherInterface $passwordHasher
    ) {
        parent::__construct();
    }

    protected function configure(): void
    {
        $this->addArgument('file', InputArgument::REQUIRED, 'Path to the JSON file');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        $filePath = $input->getArgument('file');

        if (!file_exists($filePath)) {
            $io->error(sprintf('File "%s" not found.', $filePath));
            return Command::FAILURE;
        }

        $data = json_decode(file_get_contents($filePath), true);
        if (!$data) {
            $io->error('Invalid JSON data.');
            return Command::FAILURE;
        }

        // Import Users
        if (isset($data['users'])) {
            $io->section('Importing Users');
            foreach ($data['users'] as $userData) {
                $user = $this->entityManager->getRepository(User::class)->findOneBy(['email' => $userData['email']]);
                if (!$user) {
                    $user = new User();
                    $user->setEmail($userData['email']);
                    $user->setPrenom($userData['prenom'] ?? '');
                    $user->setNom($userData['nom'] ?? '');
                    $user->setTelephone($userData['telephone'] ?? null);
                    $user->setRoles([isset($userData['role']) ? 'ROLE_' . strtoupper($userData['role']) : 'ROLE_USER']);
                    $user->setPassword($this->passwordHasher->hashPassword($user, $userData['password'] ?? 'password123'));
                    
                    $this->entityManager->persist($user);
                    $io->writeln(sprintf('User "%s" created.', $user->getEmail()));
                }
            }
            $this->entityManager->flush();
        }

        // Import Properties
        if (isset($data['properties'])) {
            $io->section('Importing Properties');
            foreach ($data['properties'] as $propData) {
                $property = new Property();
                $property->setTitle($propData['titre'] ?? 'No Title');
                $property->setDescription($propData['description'] ?? '');
                $property->setAddress($propData['lieu'] ?? '');
                $property->setPricePerMonth((string)($propData['prix'] ?? '0'));
                $property->setRooms((int)($propData['pieces'] ?? 1));
                $property->setBedrooms((int)($propData['nbChambres'] ?? 1));
                $property->setSurface((float)($propData['superficie'] ?? 0));
                
                // Find owner by email (more robust than ID)
                $ownerEmail = $propData['proprietaireEmail'] ?? 'admin@homeconnect.com';
                $owner = $this->entityManager->getRepository(User::class)->findOneBy(['email' => $ownerEmail]);
                if ($owner) {
                    $property->setProprietaire($owner);
                } else {
                    // Fallback to first user or skip
                    $io->warning(sprintf('Owner "%s" not found for property "%s".', $ownerEmail, $property->getTitle()));
                }

                $property->setStatut(Property::STATUS_ACTIVE);
                $property->setImages($propData['additionalImages'] ?? []);
                
                $this->entityManager->persist($property);
                $io->writeln(sprintf('Property "%s" imported.', $property->getTitle()));
            }
            $this->entityManager->flush();
        }

        $io->success('Import completed successfully.');

        return Command::SUCCESS;
    }
}
