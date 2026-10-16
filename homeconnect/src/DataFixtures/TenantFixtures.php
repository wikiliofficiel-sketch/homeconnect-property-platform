<?php

namespace App\DataFixtures;

use App\Entity\User;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

class TenantFixtures
{
    public function __construct(private UserPasswordHasherInterface $passwordHasher)
    {
    }

    public function load(ObjectManager $manager): void
    {
        // Create test tenant user
        $tenant = new User();
        $tenant->setEmail('tenant@test.com');
        $tenant->setPrenom('Jean');
        $tenant->setNom('Locataire');
        $tenant->setPassword($this->passwordHasher->hashPassword($tenant, 'password123'));
        $tenant->setRoles(['ROLE_LOCATAIRE']);
        $manager->persist($tenant);

        // Create test owner user
        $owner = new User();
        $owner->setEmail('owner@test.com');
        $owner->setPrenom('Pierre');
        $owner->setNom('Propriétaire');
        $owner->setPassword($this->passwordHasher->hashPassword($owner, 'password123'));
        $owner->setRoles(['ROLE_PROPRIETAIRE']);
        $manager->persist($owner);

        $manager->flush();
    }
}
