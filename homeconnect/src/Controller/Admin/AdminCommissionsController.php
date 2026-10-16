<?php

namespace App\Controller\Admin;

use App\Repository\CommissionRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/commissions', name: 'admin_commissions_')]
#[IsGranted('ROLE_ADMIN')]
class AdminCommissionsController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(CommissionRepository $commissionRepo): Response
    {
        $commissions = $commissionRepo->findAll();
        
        $stats = [
            'total' => $commissionRepo->getTotalCommissions(),
            'this_month' => $this->getCommissionsThisMonth($commissionRepo),
            'this_year' => $this->getCommissionsThisYear($commissionRepo),
        ];

        return $this->render('admin/commissions/index.html.twig', [
            'commissions' => $commissions,
            'stats' => $stats,
        ]);
    }

    private function getCommissionsThisMonth(CommissionRepository $commissionRepo): float
    {
        $now = new \DateTimeImmutable();
        $start = $now->modify('first day of this month')->setTime(0, 0);
        $end = $now->modify('last day of this month')->setTime(23, 59, 59);
        
        return $commissionRepo->getCommissionsBetween($start, $end);
    }

    private function getCommissionsThisYear(CommissionRepository $commissionRepo): float
    {
        $now = new \DateTimeImmutable();
        $start = $now->modify('first day of january')->setTime(0, 0);
        $end = $now->modify('last day of december')->setTime(23, 59, 59);
        
        return $commissionRepo->getCommissionsBetween($start, $end);
    }
}
