<?php

namespace App\Controller\Admin;

use App\Repository\LogRepository;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/logs', name: 'admin_logs_')]
#[IsGranted('ROLE_ADMIN')]
class AdminLogsController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(LogRepository $logRepo, Request $request): Response
    {
        $action    = $request->query->get('action', '');
        $dateFrom  = $request->query->get('date_from', '');
        $dateTo    = $request->query->get('date_to', '');

        $qb = $logRepo->createQueryBuilder('l')
            ->leftJoin('l.user', 'u')
            ->addSelect('u')
            ->orderBy('l.createdAt', 'DESC');

        if ($action) {
            $qb->andWhere('l.action = :action')->setParameter('action', $action);
        }
        if ($dateFrom) {
            $qb->andWhere('l.createdAt >= :from')
               ->setParameter('from', new \DateTimeImmutable($dateFrom . ' 00:00:00'));
        }
        if ($dateTo) {
            $qb->andWhere('l.createdAt <= :to')
               ->setParameter('to', new \DateTimeImmutable($dateTo . ' 23:59:59'));
        }

        $logs = $qb->setMaxResults(500)->getQuery()->getResult();

        // Toutes les actions distinctes pour le filtre
        $actions = array_unique(array_map(fn($l) => $l->getAction(), $logRepo->findAll()));
        sort($actions);

        return $this->render('admin/logs/index.html.twig', [
            'logs'       => $logs,
            'actions'    => $actions,
            'filter'     => compact('action', 'dateFrom', 'dateTo'),
        ]);
    }
}
