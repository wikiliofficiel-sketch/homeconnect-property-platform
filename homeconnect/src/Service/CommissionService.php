<?php

namespace App\Service;

use App\Entity\Commission;
use App\Entity\Rental;
use App\Entity\Subscription;
use App\Repository\SubscriptionRepository;
use Doctrine\ORM\EntityManagerInterface;

class CommissionService
{
    private const RATE_FREE    = 5.0;
    private const RATE_PREMIUM = 3.0;

    public function __construct(
        private EntityManagerInterface $em,
        private SubscriptionRepository $subRepo,
        private LogService $logService
    ) {}

    /**
     * Génère une commission pour une location.
     * Taux : 5% plan gratuit, 3% plans Starter/Pro.
     */
    public function generateForRental(Rental $rental): Commission
    {
        $proprietaire = $rental->getProperty()->getProprietaire();
        $subscription  = $this->subRepo->findOneBy(['proprietaire' => $proprietaire]);

        $rate = self::RATE_FREE;
        if ($subscription && \in_array($subscription->getPlan(), [Subscription::PLAN_STARTER, Subscription::PLAN_PRO])) {
            $rate = self::RATE_PREMIUM;
        }

        $montantLocation  = (float) $rental->getMonthlyPrice();
        $montantCommission = round($montantLocation * $rate / 100, 2);

        $commission = new Commission();
        $commission->setRental($rental);
        $commission->setMontantLocation($montantLocation);
        $commission->setPourcentageCommission($rate);
        $commission->setMontantCommission($montantCommission);

        $this->em->persist($commission);
        $this->em->flush();

        $this->logService->commissionGenerated(
            $rental->getProperty()->getTitle(),
            $montantCommission,
            $rate
        );

        return $commission;
    }
}
