<?php

namespace App\Repository;

use App\Entity\Property;
use App\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;

/**
 * @extends ServiceEntityRepository<Property>
 *
 * @method Property|null find($id, $lockMode = null, $lockVersion = null)
 * @method Property|null findOneBy(array $criteria, array $orderBy = null)
 * @method Property[]    findAll()
 * @method Property[]    findBy(array $criteria, array $orderBy = null, $limit = null, $offset = null)
 */
class PropertyRepository extends ServiceEntityRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, Property::class);
    }

    /**
     * Trouve toutes les propriétés disponibles
     */
    public function findAvailable(): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.isAvailable = :val')
            ->setParameter('val', true)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Trouve les propriétés d'un propriétaire
     */
    public function findByProprietaire(User $proprietaire): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.proprietaire = :proprietaire')
            ->setParameter('proprietaire', $proprietaire)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Recherche par ville
     */
    public function findByCity(string $city): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.city LIKE :city')
            ->andWhere('p.isAvailable = :val')
            ->setParameter('city', '%' . $city . '%')
            ->setParameter('val', true)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Recherche par prix maximum
     */
    public function findByMaxPrice(float $maxPrice): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.pricePerMonth <= :price')
            ->andWhere('p.isAvailable = :val')
            ->setParameter('price', $maxPrice)
            ->setParameter('val', true)
            ->orderBy('p.pricePerMonth', 'ASC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Recherche par nombre de chambres
     */
    public function findByBedrooms(int $bedrooms): array
    {
        return $this->createQueryBuilder('p')
            ->andWhere('p.bedrooms >= :bedrooms')
            ->andWhere('p.isAvailable = :val')
            ->setParameter('bedrooms', $bedrooms)
            ->setParameter('val', true)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    /**
     * Recherche avancée
     */
    public function searchProperties(array $criteria = []): array
    {
        $qb = $this->createQueryBuilder('p')
            ->andWhere('p.isAvailable = :val')
            ->setParameter('val', true);

        if (!empty($criteria['city'])) {
            $qb->andWhere('p.city LIKE :city')
                ->setParameter('city', '%' . $criteria['city'] . '%');
        }

        if (!empty($criteria['maxPrice'])) {
            $qb->andWhere('p.pricePerMonth <= :price')
                ->setParameter('price', $criteria['maxPrice']);
        }

        if (!empty($criteria['minBedrooms'])) {
            $qb->andWhere('p.bedrooms >= :bedrooms')
                ->setParameter('bedrooms', $criteria['minBedrooms']);
        }

        if (isset($criteria['furnished'])) {
            $qb->andWhere('p.furnished = :furnished')
                ->setParameter('furnished', $criteria['furnished']);
        }

        if (isset($criteria['hasParking'])) {
            $qb->andWhere('p.hasParking = :parking')
                ->setParameter('parking', $criteria['hasParking']);
        }

        return $qb->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();
    }

    public function countByStatut(string $statut): int
    {
        return $this->createQueryBuilder('p')
            ->select('COUNT(p.id)')
            ->andWhere('p.statut = :statut')
            ->setParameter('statut', $statut)
            ->getQuery()
            ->getSingleScalarResult();
    }

    /**
     * Compte les biens publiés (non supprimés) d'un propriétaire — utilisé pour vérifier la limite d'abonnement.
     */
    public function countActiveByOwner(User $owner): int
    {
        return (int) $this->createQueryBuilder('p')
            ->select('COUNT(p.id)')
            ->andWhere('p.proprietaire = :owner')
            ->andWhere('p.statut != :deleted')
            ->setParameter('owner', $owner)
            ->setParameter('deleted', \App\Entity\Property::STATUS_DELETED)
            ->getQuery()
            ->getSingleScalarResult();
    }
}
