<?php

namespace App\Controller\Api;

use App\Entity\Property;
use App\Entity\Subscription;
use App\Entity\User;
use App\Repository\ApplicationRepository;
use App\Repository\CommissionRepository;
use App\Repository\PropertyRepository;
use App\Repository\SubscriptionRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

/**
 * Fournit GET /api/properties/mine avec les infos d'abonnement.
 * Les autres routes de propriétés sont gérées par PropertyController.
 */
#[Route('/api/properties', name: 'api_prop_')]
class ApiPropertyController extends AbstractController
{
    #[Route('/mine', name: 'mine', methods: ['GET'])]
    public function mine(PropertyRepository $propRepo, SubscriptionRepository $subRepo): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $properties   = $propRepo->findByProprietaire($user);
        $sub          = $subRepo->findOneBy(['proprietaire' => $user]) ?? new Subscription();
        $count        = $propRepo->countActiveByOwner($user);

        $data = [];
        foreach ($properties as $p) {
            $owner = $p->getProprietaire();
            $images = array_values(array_filter(
                $p->getImages() ?? [],
                fn($img) => str_starts_with($img, '/') || str_starts_with($img, 'http')
            ));
            $data[] = [
                'id'           => $p->getId(),
                'title'        => $p->getTitle(),
                'description'  => $p->getDescription(),
                'address'      => $p->getAddress(),
                'city'         => $p->getCity(),
                'pricePerMonth'=> $p->getPricePerMonth(),
                'rooms'        => $p->getRooms(),
                'bedrooms'     => $p->getBedrooms(),
                'surface'      => $p->getSurface(),
                'type'         => $p->getType(),
                'statut'       => $p->getStatut(),
                'furnished'    => $p->isFurnished(),
                'hasParking'   => $p->hasParking(),
                'verified'     => $p->isVerified(),
                'views'        => $p->getViews(),
                'images'       => $images,
                'createdAt'    => $p->getCreatedAt()?->format('c'),
                'proprietaire' => $owner ? [
                    'id'        => $owner->getId(),
                    'email'     => $owner->getEmail(),
                    'prenom'    => $owner->getPrenom(),
                    'nom'       => $owner->getNom(),
                    'telephone' => $owner->getTelephone(),
                ] : null,
            ];
        }

        return new JsonResponse([
            'properties'    => $data,
            'count'         => $count,
            'maxProperties' => $sub->getMaxProperties(),
            'canAdd'        => $sub->canPublishMore($count),
            'plan'          => $sub->getPlan(),
        ]);
    }

    #[Route('/statistics', name: 'statistics', methods: ['GET'])]
    public function statistics(
        PropertyRepository $propRepo,
        ApplicationRepository $appRepo,
        CommissionRepository $commRepo,
        SubscriptionRepository $subRepo
    ): JsonResponse {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $properties   = $propRepo->findBy(['proprietaire' => $user]);
        $totalViews   = array_sum(array_map(fn($p) => $p->getViews(), $properties));
        $applications = $appRepo->findBy(['property' => $properties]);
        $totalApps    = count($applications);
        $accepted     = count(array_filter($applications, fn($a) => $a->getStatut() === 'accepted'));
        $convRate     = $totalViews > 0 ? round($totalApps / $totalViews * 100, 1) : 0;

        // Revenus actifs (locations actives)
        $totalRevenue = 0.0;
        foreach ($properties as $p) {
            foreach ($p->getRentals() as $rental) {
                if ($rental->getStatus() === 'active') {
                    $totalRevenue += (float) $rental->getMonthlyPrice();
                }
            }
        }

        // Commissions perçues
        $sub      = $subRepo->findOneBy(['proprietaire' => $user]);
        $commRate = ($sub && in_array($sub->getPlan(), ['starter', 'pro'])) ? 3.0 : 5.0;

        // Stats par bien
        $propStats = [];
        foreach ($properties as $p) {
            $appCount = count($appRepo->findBy(['property' => $p]));
            $propStats[] = [
                'id'           => $p->getId(),
                'title'        => $p->getTitle(),
                'statut'       => $p->getStatut(),
                'views'        => $p->getViews(),
                'applications' => $appCount,
                'rentals'      => count($p->getRentals()->toArray()),
                'pricePerMonth'=> $p->getPricePerMonth(),
            ];
        }

        return new JsonResponse([
            'totalProperties'    => count($properties),
            'totalViews'         => $totalViews,
            'totalApplications'  => $totalApps,
            'acceptedCount'      => $accepted,
            'conversionRate'     => $convRate,
            'totalMonthlyRevenue'=> $totalRevenue,
            'commissionRate'     => $commRate,
            'plan'               => $sub ? $sub->getPlan() : 'free',
            'properties'         => $propStats,
        ]);
    }

    // Note: POST /api/properties/new and GET /api/properties/{id} are handled by PropertyController.
}
