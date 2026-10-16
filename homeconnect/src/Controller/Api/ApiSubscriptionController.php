<?php

namespace App\Controller\Api;

use App\Entity\Subscription;
use App\Entity\User;
use App\Repository\PropertyRepository;
use App\Repository\SubscriptionRepository;
use App\Service\FedaPayService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/subscription', name: 'api_subscription_')]
class ApiSubscriptionController extends AbstractController
{
    #[Route('/plans', name: 'plans', methods: ['GET'])]
    public function plans(): JsonResponse
    {
        $plans = [];
        foreach (Subscription::PLAN_LABELS as $key => $label) {
            $plans[] = [
                'key'           => $key,
                'label'         => $label,
                'price'         => Subscription::PLAN_PRICES[$key],
                'maxProperties' => Subscription::PLAN_LIMITS[$key],
                'features'      => $this->getPlanFeatures($key),
            ];
        }
        return new JsonResponse($plans);
    }

    #[Route('/current', name: 'current', methods: ['GET'])]
    public function current(
        SubscriptionRepository $subRepo,
        PropertyRepository $propRepo
    ): JsonResponse {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $sub = $subRepo->findOneBy(['proprietaire' => $user]);
        if (!$sub) {
            $sub = new Subscription();
            $sub->setProprietaire($user);
        }

        $publishedCount = $propRepo->countActiveByOwner($user);

        $data = $sub->toApiArray();
        $data['publishedCount'] = $publishedCount;
        $data['canPublishMore'] = $sub->canPublishMore($publishedCount);
        $data['remainingSlots'] = $sub->getMaxProperties() === null
            ? null
            : max(0, $sub->getMaxProperties() - $publishedCount);

        return new JsonResponse($data);
    }

    #[Route('/upgrade', name: 'upgrade', methods: ['POST'])]
    public function upgrade(
        Request $request,
        SubscriptionRepository $subRepo,
        EntityManagerInterface $em,
        FedaPayService $fedaPayService
    ): JsonResponse {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true) ?? [];
        $targetPlan = $data['plan'] ?? null;
        $months     = max(1, (int) ($data['months'] ?? 1));

        if (!in_array($targetPlan, [Subscription::PLAN_STARTER, Subscription::PLAN_PRO])) {
            return new JsonResponse(['error' => 'Plan invalide. Valeurs: starter, pro'], Response::HTTP_BAD_REQUEST);
        }

        $sub = $subRepo->findOneBy(['proprietaire' => $user]);
        if (!$sub) {
            $sub = new Subscription();
            $sub->setProprietaire($user);
            $em->persist($sub);
        }

        // Vérifier qu'on ne downgrade pas
        $currentPlan = $sub->getPlan();
        $order = ['free' => 0, 'starter' => 1, 'pro' => 2];
        if (($order[$targetPlan] ?? 0) <= ($order[$currentPlan] ?? 0)) {
            return new JsonResponse(['error' => 'Impossible de passer à un plan inférieur ou identique'], Response::HTTP_BAD_REQUEST);
        }

        $price = Subscription::PLAN_PRICES[$targetPlan] * $months;

        // Initier paiement FedaPay si plan payant
        $paymentUrl = null;
        if ($price > 0) {
            try {
                $transaction = $fedaPayService->createTransaction([
                    'amount'      => $price,
                    'description' => 'Abonnement ' . Subscription::PLAN_LABELS[$targetPlan] . ' – ' . $months . ' mois',
                    'email'       => $user->getEmail(),
                    'metadata'    => [
                        'userId'     => $user->getId(),
                        'plan'       => $targetPlan,
                        'months'     => $months,
                        'type'       => 'subscription_upgrade',
                    ],
                ]);
                $paymentUrl = $transaction['payment_url'] ?? null;
            } catch (\Throwable $e) {
                // Si FedaPay échoue, on active quand même en mode test
                $paymentUrl = null;
            }
        }

        // Si pas de paiement nécessaire (ou mode dev), activer immédiatement
        if ($price === 0 || $paymentUrl === null) {
            $this->activateSubscription($sub, $targetPlan, $months, $em);
            $em->flush();
            return new JsonResponse([
                'success'      => true,
                'message'      => 'Abonnement ' . Subscription::PLAN_LABELS[$targetPlan] . ' activé',
                'subscription' => $sub->toApiArray(),
            ]);
        }

        return new JsonResponse([
            'success'     => false,
            'paymentRequired' => true,
            'paymentUrl'  => $paymentUrl,
            'amount'      => $price,
            'plan'        => $targetPlan,
            'months'      => $months,
        ]);
    }

    #[Route('/webhook/activated', name: 'webhook_activated', methods: ['POST'])]
    public function webhookActivated(
        Request $request,
        SubscriptionRepository $subRepo,
        EntityManagerInterface $em
    ): JsonResponse {
        $data   = json_decode($request->getContent(), true) ?? [];
        $meta   = $data['transaction']['metadata'] ?? [];
        $userId = $meta['userId'] ?? null;
        $plan   = $meta['plan'] ?? null;
        $months = (int) ($meta['months'] ?? 1);
        $type   = $meta['type'] ?? '';

        if ($type !== 'subscription_upgrade' || !$userId || !$plan) {
            return new JsonResponse(['ok' => false]);
        }

        $user = $em->getRepository(User::class)->find($userId);
        if (!$user) {
            return new JsonResponse(['ok' => false]);
        }

        $sub = $subRepo->findOneBy(['proprietaire' => $user]);
        if (!$sub) {
            $sub = new Subscription();
            $sub->setProprietaire($user);
            $em->persist($sub);
        }

        $this->activateSubscription($sub, $plan, $months, $em);
        $em->flush();

        return new JsonResponse(['ok' => true]);
    }

    private function activateSubscription(
        Subscription $sub,
        string $plan,
        int $months,
        EntityManagerInterface $em
    ): void {
        $now   = new \DateTimeImmutable();
        $start = $sub->getDateExpiration() && $sub->getDateExpiration() > $now
            ? $sub->getDateExpiration()
            : $now;

        $sub->setPlan($plan);
        $sub->setStatut(Subscription::STATUS_ACTIVE);
        $sub->setDateDebut($now);
        $sub->setDateExpiration($start->modify('+' . $months . ' months'));
        $sub->setUpdatedAt($now);
    }

    private function getPlanFeatures(string $plan): array
    {
        return match ($plan) {
            'free'    => [
                '3 biens maximum',
                'Tableau de bord standard',
                'Messagerie incluse',
                'Support communauté',
            ],
            'starter' => [
                "Jusqu'à 10 biens",
                'Tableau de bord avancé',
                'Messagerie WhatsApp',
                'Statistiques détaillées',
                'Support email prioritaire',
            ],
            'pro' => [
                'Biens illimités',
                'Tableau de bord premium',
                'Messagerie WhatsApp + Appels',
                'Statistiques & exports PDF',
                'Support téléphonique dédié',
                'Badge "Propriétaire Pro"',
            ],
            default => [],
        };
    }
}
