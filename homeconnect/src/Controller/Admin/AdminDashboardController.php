<?php

namespace App\Controller\Admin;

use App\Entity\User;
use App\Entity\Property;
use App\Entity\Rental;
use App\Entity\Report;
use App\Entity\Subscription;
use App\Entity\Commission;
use App\Entity\Partner;
use App\Repository\UserRepository;
use App\Repository\PropertyRepository;
use App\Repository\RentalRepository;
use App\Repository\ReportRepository;
use App\Repository\SubscriptionRepository;
use App\Repository\CommissionRepository;
use App\Repository\PartnerRepository;
use App\Repository\LogRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin', name: 'admin_')]
#[IsGranted('ROLE_ADMIN')]
class AdminDashboardController extends AbstractController
{
    #[Route('/', name: 'dashboard')]
    public function dashboard(
        UserRepository $userRepo,
        PropertyRepository $propertyRepo,
        RentalRepository $rentalRepo,
        ReportRepository $reportRepo,
        SubscriptionRepository $subRepo,
        CommissionRepository $commissionRepo,
        LogRepository $logRepo
    ): Response
    {
        $stats = [
            'total_users' => $userRepo->count([]),
            'proprietaires' => count($userRepo->findWithRole('ROLE_PROPRIETAIRE')),
            'locataires' => count($userRepo->findWithRole('ROLE_LOCATAIRE')),
            'active_properties' => $propertyRepo->countByStatut(Property::STATUS_ACTIVE),
            'pending_properties' => $propertyRepo->countByStatut(Property::STATUS_PENDING),
            'total_rentals' => $rentalRepo->count([]),
            'active_rentals' => $rentalRepo->countByStatus(Rental::STATUS_ONGOING),
            'open_reports' => $reportRepo->countOpen(),
            'critical_reports' => count($reportRepo->findByPriorite(Report::PRIORITY_CRITICAL)),
            'premium_plus_active' => $subRepo->countActivePremiumPlus(),
            'total_commissions' => $commissionRepo->getTotalCommissions(),
            'commissions_this_month' => $this->getCommissionsThisMonth($commissionRepo),
        ];

        $recentLogs = $logRepo->findBy([], ['createdAt' => 'DESC'], 5);

        // Données pour les graphiques (6 derniers mois)
        $chartData = $this->prepareChartData($userRepo, $commissionRepo);

        return $this->render('admin/dashboard/index.html.twig', [
            'stats' => $stats,
            'recentLogs' => $recentLogs,
            'chartData' => $chartData,
        ]);
    }

    private function prepareChartData(UserRepository $userRepo, CommissionRepository $commissionRepo): array
    {
        $months = [];
        $userCounts = [];
        $commissionSums = [];
        
        for ($i = 5; $i >= 0; $i--) {
            $date = new \DateTimeImmutable("-$i months");
            $start = $date->modify('first day of this month')->setTime(0, 0);
            $end = $date->modify('last day of this month')->setTime(23, 59, 59);
            
            $months[] = $date->format('M');
            
            // Compter users créés ce mois
            $userCounts[] = $userRepo->createQueryBuilder('u')
                ->select('COUNT(u.id)')
                ->where('u.createdAt >= :start')
                ->andWhere('u.createdAt <= :end')
                ->setParameter('start', $start)
                ->setParameter('end', $end)
                ->getQuery()
                ->getSingleScalarResult();

            // Somme commissions ce mois
            $commissionSums[] = $commissionRepo->getCommissionsBetween($start, $end);
        }

        return [
            'labels' => $months,
            'users' => $userCounts,
            'commissions' => $commissionSums,
        ];
    }

    private function getCommissionsThisMonth(CommissionRepository $commissionRepo): float
    {
        $now = new \DateTimeImmutable();
        $start = $now->modify('first day of this month')->setTime(0, 0);
        $end = $now->modify('last day of this month')->setTime(23, 59, 59);
        
        return $commissionRepo->getCommissionsBetween($start, $end);
    }
}
