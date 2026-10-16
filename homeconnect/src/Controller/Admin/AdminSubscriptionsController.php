<?php

namespace App\Controller\Admin;

use App\Entity\Subscription;
use App\Repository\SubscriptionRepository;
use App\Service\LogService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/subscriptions', name: 'admin_subscriptions_')]
#[IsGranted('ROLE_ADMIN')]
class AdminSubscriptionsController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(SubscriptionRepository $subRepo, Request $request): Response
    {
        $plan = $request->query->get('plan', '');

        $query = $subRepo->createQueryBuilder('s')
            ->leftJoin('s.proprietaire', 'u')
            ->addSelect('u');

        if ($plan && in_array($plan, [Subscription::PLAN_FREE, Subscription::PLAN_STARTER, Subscription::PLAN_PRO])) {
            $query->andWhere('s.plan = :plan')
                  ->setParameter('plan', $plan);
        }

        $subscriptions = $query->orderBy('s.createdAt', 'DESC')->getQuery()->getResult();

        $all = $subRepo->findAll();
        $stats = [
            'total'         => count($all),
            'total_free'    => count(array_filter($all, fn($s) => $s->getPlan() === Subscription::PLAN_FREE)),
            'total_starter' => count(array_filter($all, fn($s) => $s->getPlan() === Subscription::PLAN_STARTER)),
            'total_pro'     => count(array_filter($all, fn($s) => $s->getPlan() === Subscription::PLAN_PRO)),
            'expiring_soon' => $this->countExpiringSoon($all),
        ];

        return $this->render('admin/subscriptions/index.html.twig', [
            'subscriptions' => $subscriptions,
            'plan'          => $plan,
            'stats'         => $stats,
        ]);
    }

    #[Route('/{id}/detail', name: 'show')]
    public function show(Subscription $subscription): Response
    {
        return $this->render('admin/subscriptions/show.html.twig', [
            'subscription' => $subscription,
        ]);
    }

    #[Route('/{id}/renew', name: 'renew', methods: ['POST'])]
    public function renew(Subscription $subscription, Request $request, EntityManagerInterface $em, LogService $logService): Response
    {
        $mois = max(1, (int) $request->request->get('mois', 1));
        $now  = new \DateTimeImmutable();

        $newExpiration = $subscription->getDateExpiration()
            ? $subscription->getDateExpiration()->modify("+{$mois} month")
            : $now->modify("+{$mois} month");

        $subscription->setDateExpiration($newExpiration);
        $subscription->setStatut(Subscription::STATUS_ACTIVE);
        $subscription->setUpdatedAt($now);
        $em->flush();

        $logService->subscriptionRenewed(
            $subscription->getProprietaire()->getFullName(),
            $subscription->getId(),
            $mois
        );

        $this->addFlash('success', sprintf('Abonnement prolongé de %d mois.', $mois));
        return $this->redirectToRoute('admin_subscriptions_show', ['id' => $subscription->getId()]);
    }

    #[Route('/{id}/upgrade', name: 'upgrade', methods: ['POST'])]
    public function upgrade(Subscription $subscription, EntityManagerInterface $em, LogService $logService): Response
    {
        $subscription->setPlan(Subscription::PLAN_PRO);
        $subscription->setDateDebut(new \DateTimeImmutable());
        $subscription->setDateExpiration((new \DateTimeImmutable())->modify('+1 month'));
        $subscription->setStatut(Subscription::STATUS_ACTIVE);
        $em->flush();

        $logService->subscriptionUpgraded(
            $subscription->getProprietaire()->getFullName(),
            $subscription->getId(),
            Subscription::PLAN_PRO
        );

        $this->addFlash('success', 'Abonnement passé en plan Pro.');
        return $this->redirectToRoute('admin_subscriptions_show', ['id' => $subscription->getId()]);
    }

    private function countExpiringSoon($subscriptions, $days = 7): int
    {
        $now = new \DateTimeImmutable();
        $soon = $now->modify("+{$days} days");
        
        $count = 0;
        foreach ($subscriptions as $sub) {
            if ($sub->getDateExpiration() && $sub->getDateExpiration() <= $soon && $sub->getDateExpiration() > $now) {
                $count++;
            }
        }
        return $count;
    }
}
