<?php

namespace App\DataFixtures;

use App\Entity\User;
use App\Entity\Property;
use App\Entity\Application;
use App\Entity\Message;
use App\Entity\Subscription;
use Doctrine\Bundle\FixturesBundle\Fixture;
use Doctrine\Persistence\ObjectManager;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;

class AppFixtures extends Fixture
{
    private UserPasswordHasherInterface $passwordHasher;

    public function __construct(UserPasswordHasherInterface $passwordHasher)
    {
        $this->passwordHasher = $passwordHasher;
    }

    public function load(ObjectManager $manager): void
    {
        // 1. ADMIN
        $admin = new User();
        $admin->setEmail('admin@homeconnect.com')
            ->setPrenom('Admin')
            ->setNom('ImmoBénin')
            ->setRoles(['ROLE_ADMIN'])
            ->setPassword($this->passwordHasher->hashPassword($admin, 'admin123'))
            ->setCreatedAt(new \DateTimeImmutable());
        $manager->persist($admin);

        // 2. PROPRIÉTAIRES
        $owners = [];
        for ($i = 1; $i <= 2; $i++) {
            $owner = new User();
            $owner->setEmail("owner$i@test.com")
                ->setPrenom("Jean")
                ->setNom("Proprio$i")
                ->setRoles(['ROLE_PROPRIETAIRE'])
                ->setPassword($this->passwordHasher->hashPassword($owner, 'password'))
                ->setKycStatus('approved')
                ->setCreatedAt(new \DateTimeImmutable());
            $manager->persist($owner);
            $owners[] = $owner;
        }

        // 3. LOCATAIRES
        $tenants = [];
        for ($i = 1; $i <= 3; $i++) {
            $tenant = new User();
            $tenant->setEmail("tenant$i@test.com")
                ->setPrenom("Marc")
                ->setNom("Locataire$i")
                ->setRoles(['ROLE_LOCATAIRE'])
                ->setPassword($this->passwordHasher->hashPassword($tenant, 'password'))
                ->setKycStatus($i == 1 ? 'approved' : 'pending')
                ->setCreatedAt(new \DateTimeImmutable());
            $manager->persist($tenant);
            $tenants[] = $tenant;
        }

        // 4. BIENS (PROPERTIES)
        $properties = [];
        $villes = ['Cotonou', 'Abomey-Calavi', 'Porto-Novo'];
        for ($i = 1; $i <= 5; $i++) {
            $prop = new Property();
            $prop->setTitle("Villa " . ($i % 2 == 0 ? "Fidjrossè" : "Calavi"))
                ->setDescription("Une magnifique propriété située à " . $villes[$i % 3])
                ->setPricePerMonth(50000 + ($i * 10000))
                ->setCity($villes[$i % 3])
                ->setAddress("Rue " . ($i * 10))
                ->setZipCode("00229")
                ->setRooms(2 + ($i % 3))
                ->setBedrooms(1 + ($i % 2))
                ->setSurface(45.5 * $i)
                ->setStatut(Property::STATUS_ACTIVE)
                ->setProprietaire($owners[$i % 2])
                ->setCreatedAt(new \DateTimeImmutable());
            $manager->persist($prop);
            $properties[] = $prop;
        }

        // 5. APPLICATIONS
        foreach ($tenants as $t) {
            $app = new Application();
            $app->setLocataire($t)
                ->setProperty($properties[array_rand($properties)])
                ->setStatut('pending')
                ->setDateDebut(new \DateTime('+1 month'))
                ->setDateFin(new \DateTime('+1 year'))
                ->setCreatedAt(new \DateTime());
            $manager->persist($app);
        }

        // 6. MESSAGES
        $msg = new Message();
        $msg->setSender($tenants[0])
            ->setReceiver($owners[0])
            ->setContent("Bonjour, je suis très intéressé par votre villa.")
            ->setCreatedAt(new \DateTimeImmutable('-2 hours'));
        $manager->persist($msg);

        $msg2 = new Message();
        $msg2->setSender($owners[0])
            ->setReceiver($tenants[0])
            ->setContent("Bonjour Marc, avec plaisir. Quand seriez-vous disponible pour une visite ?")
            ->setCreatedAt(new \DateTimeImmutable('-1 hour'));
        $manager->persist($msg2);

        // 7. ABONNEMENT
        $sub = new Subscription();
        $sub->setProprietaire($tenants[0])
            ->setPlan('premium_plus')
            ->setStatut('active')
            ->setDateDebut(new \DateTimeImmutable('-1 month'))
            ->setDateExpiration(new \DateTimeImmutable('+11 months'));
        $manager->persist($sub);

        $manager->flush();
    }
}
