<?php

namespace App\Controller\Api;

use App\Entity\Favorite;
use App\Entity\Property;
use App\Entity\PropertyInteraction;
use App\Entity\Subscription;
use App\Entity\User;
use App\Repository\FavoriteRepository;
use App\Repository\PropertyInteractionRepository;
use App\Repository\PropertyRepository;
use App\Repository\SubscriptionRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/properties', name: 'api_properties_')]
class PropertyController extends AbstractController
{
    #[Route('', name: 'list', methods: ['GET'])]
    public function list(PropertyRepository $repository, Request $request): JsonResponse
    {
        $page     = max(1, (int) $request->query->get('page', 1));
        $limit    = min(50, max(1, (int) $request->query->get('limit', 20)));
        $offset   = ($page - 1) * $limit;

        $qb = $repository->createQueryBuilder('p')
            ->where('p.statut IN (:statuts)')
            ->setParameter('statuts', [Property::STATUS_ACTIVE, Property::STATUS_PENDING]);

        $this->applyFilters($qb, $request);
        $this->applySort($qb, $request);

        $total = (clone $qb)->select('COUNT(p.id)')->getQuery()->getSingleScalarResult();

        $properties = $qb->setFirstResult($offset)->setMaxResults($limit)->getQuery()->getResult();

        return new JsonResponse([
            'data'        => array_map(fn($p) => $this->serializeProperty($p), $properties),
            'pagination'  => [
                'page'        => $page,
                'limit'       => $limit,
                'total'       => (int) $total,
                'total_pages' => (int) ceil($total / $limit),
                'has_next'    => ($page * $limit) < $total,
                'has_prev'    => $page > 1,
            ],
        ]);
    }

    #[Route('/search', name: 'search', methods: ['GET'])]
    public function search(PropertyRepository $repository, Request $request): JsonResponse
    {
        $page   = max(1, (int) $request->query->get('page', 1));
        $limit  = min(50, max(1, (int) $request->query->get('limit', 20)));
        $q      = trim($request->query->get('q', ''));

        $qb = $repository->createQueryBuilder('p')
            ->where('p.statut = :status')
            ->setParameter('status', Property::STATUS_ACTIVE);

        if ($q !== '') {
            $qb->andWhere('p.title LIKE :q OR p.description LIKE :q OR p.city LIKE :q OR p.address LIKE :q')
               ->setParameter('q', '%' . $q . '%');
        }

        $this->applyFilters($qb, $request);
        $this->applySort($qb, $request);

        $total      = (clone $qb)->select('COUNT(p.id)')->getQuery()->getSingleScalarResult();
        $properties = $qb->setFirstResult(($page - 1) * $limit)->setMaxResults($limit)->getQuery()->getResult();

        return new JsonResponse([
            'data'       => array_map(fn($p) => $this->serializeProperty($p), $properties),
            'query'      => $q,
            'pagination' => [
                'page'        => $page,
                'limit'       => $limit,
                'total'       => (int) $total,
                'total_pages' => (int) ceil($total / $limit),
                'has_next'    => ($page * $limit) < $total,
            ],
        ]);
    }

    private function applyFilters(\Doctrine\ORM\QueryBuilder $qb, Request $request): void
    {
        if ($v = $request->query->get('city'))       $qb->andWhere('LOWER(p.city) = LOWER(:city)')->setParameter('city', $v);
        if ($v = $request->query->get('type'))       $qb->andWhere('p.type = :type')->setParameter('type', $v);
        if ($v = $request->query->get('min_price'))  $qb->andWhere('p.pricePerMonth >= :minP')->setParameter('minP', (float)$v);
        if ($v = $request->query->get('max_price'))  $qb->andWhere('p.pricePerMonth <= :maxP')->setParameter('maxP', (float)$v);
        if ($v = $request->query->get('min_rooms'))  $qb->andWhere('p.rooms >= :minR')->setParameter('minR', (int)$v);
        if ($v = $request->query->get('max_rooms'))  $qb->andWhere('p.rooms <= :maxR')->setParameter('maxR', (int)$v);
        if ($v = $request->query->get('min_surface'))$qb->andWhere('p.surface >= :minS')->setParameter('minS', (float)$v);
        if ($v = $request->query->get('furnished'))  $qb->andWhere('p.furnished = :fur')->setParameter('fur', filter_var($v, FILTER_VALIDATE_BOOLEAN));
        if ($v = $request->query->get('verified'))   $qb->andWhere('p.isVerified = :ver')->setParameter('ver', filter_var($v, FILTER_VALIDATE_BOOLEAN));
        if ($v = $request->query->get('owner_id'))   $qb->andWhere('p.proprietaire = :oid')->setParameter('oid', (int)$v);
    }

    private function applySort(\Doctrine\ORM\QueryBuilder $qb, Request $request): void
    {
        $sort = match ($request->query->get('sort', 'recent')) {
            'price_asc'  => ['p.pricePerMonth', 'ASC'],
            'price_desc' => ['p.pricePerMonth', 'DESC'],
            'rating'     => ['p.rating', 'DESC'],
            'views'      => ['p.views', 'DESC'],
            default      => ['p.createdAt', 'DESC'],
        };
        $qb->orderBy($sort[0], $sort[1]);
    }

    #[Route('/{id}', name: 'show', methods: ['GET'])]
    public function show(Property $property): JsonResponse
    {
        if ($property->getStatut() !== Property::STATUS_ACTIVE) {
            return new JsonResponse(['error' => 'Property not found or inactive'], Response::HTTP_NOT_FOUND);
        }

        return new JsonResponse($this->serializeProperty($property));
    }

    #[Route('/owner', name: 'owner_list', methods: ['GET'])]
    public function ownerList(PropertyRepository $repository): JsonResponse
    {
        $user = $this->getUser();
        $properties = $repository->findBy(['proprietaire' => $user]);

        $data = [];
        foreach ($properties as $property) {
            $data[] = $this->serializeProperty($property);
        }

        return new JsonResponse($data);
    }

    // Séquence 2 du mémoire : Propriétaire → Ajouter maison → Système → BD → Notifier admin
    #[Route('/new', name: 'create', methods: ['POST'])]
    public function create(Request $request, EntityManagerInterface $em, NotificationService $notificationService, PropertyRepository $propRepo, SubscriptionRepository $subRepo): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        // Vérification KYC (sauf admins)
        $isAdminUser = in_array('ROLE_ADMIN', $user->getRoles(), true);
        if (!$isAdminUser && !$user->canPublishProperty()) {
            return new JsonResponse([
                'error'        => 'Certification KYC requise avant de publier',
                'kycRequired'  => true,
                'kycStatus'    => $user->getKycStatus(),
                'verificationStatus' => $user->getVerificationStatus(),
            ], Response::HTTP_FORBIDDEN);
        }

        // Vérification de la limite d'abonnement (sauf pour les admins)
        if (!in_array('ROLE_ADMIN', $user->getRoles(), true)) {
            $sub   = $subRepo->findOneBy(['proprietaire' => $user]) ?? new Subscription();
            $sub->setProprietaire($user);
            $count = $propRepo->countActiveByOwner($user);
            if (!$sub->canPublishMore($count)) {
                $next = $sub->getNextUpgradePlan();
                return new JsonResponse([
                    'error'           => 'Limite de biens atteinte (' . $sub->getPlanLabel() . ')',
                    'upgradeRequired' => true,
                    'currentPlan'     => $sub->getPlan(),
                    'nextPlan'        => $next,
                    'nextPlanPrice'   => $next ? (Subscription::PLAN_PRICES[$next] ?? null) : null,
                ], Response::HTTP_PAYMENT_REQUIRED);
            }
        }

        $data = json_decode($request->getContent(), true);
        if (!$data) {
            return new JsonResponse(['error' => 'Invalid JSON'], Response::HTTP_BAD_REQUEST);
        }

        $property = new Property();
        $property->setProprietaire($user);

        // Accepte les noms de champs FR (mobile) ET EN (backend)
        $property->setTitle($data['title'] ?? $data['titre'] ?? '');
        $property->setDescription($data['description'] ?? $data['descriptionDetaillee'] ?? '');
        $property->setAddress($data['address'] ?? $data['lieu'] ?? '');
        $property->setCity($data['city'] ?? $data['ville'] ?? '');
        $property->setZipCode($data['zipCode'] ?? $data['codePostal'] ?? '');
        $property->setPricePerMonth($data['pricePerMonth'] ?? $data['prix'] ?? 0);
        $property->setRooms($data['rooms'] ?? $data['pieces'] ?? 0);
        $property->setBedrooms($data['bedrooms'] ?? $data['nbChambres'] ?? 0);
        $property->setSurface((float)($data['surface'] ?? $data['superficie'] ?? 0));
        $property->setType($data['type'] ?? 'Appartement');
        $property->setFurnished((bool)($data['furnished'] ?? false));
        $property->setHasParking((bool)($data['hasParking'] ?? false));
        $property->setImages($this->saveBase64Images($data['images'] ?? [], $this->getParameter('kernel.project_dir')));
        $property->setVideoUrl($data['videoUrl'] ?? $data['propertyVideoUrl'] ?? null);
        $isAdmin = in_array('ROLE_ADMIN', $user->getRoles(), true);
        $property->setStatut($isAdmin ? Property::STATUS_ACTIVE : Property::STATUS_PENDING);
        $property->setCreatedAt(new \DateTimeImmutable());

        // Champs étendus
        $property->setNbSalons($data['nbSalons'] ?? 0);
        $property->setNbSallesDeBain($data['nbSallesDeBain'] ?? 0);
        $property->setNbToilettes($data['nbToilettes'] ?? 0);
        $property->setEtage($data['etage'] ?? null);
        $property->setHasAscenseur((bool)($data['hasAscenseur'] ?? false));
        $property->setParkingPlaces($data['parkingPlaces'] ?? 0);
        $property->setHasJardin((bool)($data['hasJardin'] ?? false));
        $property->setHasBalcon((bool)($data['hasBalcon'] ?? false));
        $property->setEquipements($data['equipements'] ?? []);
        $property->setAnimauxAcceptes((bool)($data['animauxAcceptes'] ?? false));
        $property->setFumeursAcceptes((bool)($data['fumeursAcceptes'] ?? false));
        $property->setDureeMinLocation($data['dureeMinLocation'] ?? null);
        $property->setPreavis($data['preavis'] ?? null);
        $property->setStatutAnnonce($data['statutAnnonce'] ?? 'À louer');

        if (isset($data['deposit']) || isset($data['depotGarantie'])) {
            $property->setDeposit($data['deposit'] ?? $data['depotGarantie']);
        }
        if (isset($data['chargesComprises'])) {
            $property->setChargesComprises((bool)$data['chargesComprises']);
        }
        if (isset($data['montantCharges'])) {
            $property->setMontantCharges($data['montantCharges']);
        }

        $em->persist($property);
        $em->flush();

        // Séquence 2 : Système → Notifier admin (nouveau bien en attente de validation)
        $notificationService->notifyAdmins(
            'property_submitted',
            \sprintf(
                '%s a soumis un nouveau bien "%s" en attente de validation.',
                $user->getFullName(),
                $property->getTitle()
            ),
            'Nouveau bien à valider',
            $property->getId(),
            'property'
        );

        return new JsonResponse([
            'message' => 'Bien créé avec succès, en attente de validation',
            'id' => $property->getId(),
            'property' => $this->serializeProperty($property),
        ], Response::HTTP_CREATED);
    }

    // Mise à jour d'un bien (propriétaire uniquement)
    #[Route('/{id}', name: 'update', methods: ['PUT', 'PATCH'])]
    public function update(Property $property, Request $request, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User || $property->getProprietaire() !== $user) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $data = json_decode($request->getContent(), true);
        if (!$data) {
            return new JsonResponse(['error' => 'Invalid JSON'], Response::HTTP_BAD_REQUEST);
        }

        if (isset($data['title']) || isset($data['titre'])) {
            $property->setTitle($data['title'] ?? $data['titre']);
        }
        if (isset($data['description'])) $property->setDescription($data['description']);
        if (isset($data['address']) || isset($data['lieu'])) {
            $property->setAddress($data['address'] ?? $data['lieu']);
        }
        if (isset($data['city']) || isset($data['ville'])) {
            $property->setCity($data['city'] ?? $data['ville']);
        }
        if (isset($data['pricePerMonth']) || isset($data['prix'])) {
            $property->setPricePerMonth($data['pricePerMonth'] ?? $data['prix']);
        }
        if (isset($data['rooms']) || isset($data['pieces'])) {
            $property->setRooms($data['rooms'] ?? $data['pieces']);
        }
        if (isset($data['surface']) || isset($data['superficie'])) {
            $property->setSurface((float)($data['surface'] ?? $data['superficie']));
        }
        if (isset($data['images'])) $property->setImages($data['images']);
        if (isset($data['statut'])) $property->setStatut($this->mapStatusToBackend($data['statut']));
        if (isset($data['status'])) $property->setStatut($this->mapStatusToBackend($data['status']));
        $property->setUpdatedAt(new \DateTimeImmutable());

        $em->flush();

        return new JsonResponse(['message' => 'Property updated', 'property' => $this->serializeProperty($property)]);
    }

    // ── FAVORIS ───────────────────────────────────────────────────────────────

    #[Route('/favorites', name: 'favorites', methods: ['GET'])]
    public function getFavorites(FavoriteRepository $favRepo): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }
        $favorites = $favRepo->findByLocataire($user->getId());
        $data = array_map(fn($f) => [
            'propertyId' => $f->getProperty()->getId(),
            'property'   => $this->serializeProperty($f->getProperty()),
        ], $favorites);
        return new JsonResponse($data);
    }

    #[Route('/{id}/toggle-favorite', name: 'toggle_favorite', methods: ['POST'])]
    public function toggleFavorite(Property $property, FavoriteRepository $favRepo, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }
        $existing = $favRepo->findOneBy(['locataire' => $user, 'property' => $property]);
        if ($existing) {
            $em->remove($existing);
            $em->flush();
            return new JsonResponse(['isFavorite' => false]);
        }
        $fav = new Favorite();
        $fav->setLocataire($user)->setProperty($property);
        $em->persist($fav);
        $em->flush();
        return new JsonResponse(['isFavorite' => true]);
    }

    // ── RÉACTIONS (LIKE/DISLIKE) ──────────────────────────────────────────────

    #[Route('/{id}/react', name: 'react', methods: ['POST'])]
    public function react(
        Property $property,
        Request $request,
        PropertyInteractionRepository $interactionRepo,
        EntityManagerInterface $em
    ): JsonResponse {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $type = json_decode($request->getContent(), true)['type'] ?? null;
        if (!in_array($type, ['like', 'dislike'])) {
            return new JsonResponse(['error' => 'Type invalide (like|dislike)'], Response::HTTP_BAD_REQUEST);
        }

        $existing = $interactionRepo->findOneByPropertyAndUser($property->getId(), $user->getId());
        if ($existing) {
            if ($existing->getType() === $type) {
                $em->remove($existing);
            } else {
                $existing->setType($type);
            }
        } else {
            $interaction = new PropertyInteraction();
            $interaction->setProperty($property)->setUser($user)->setType($type);
            $em->persist($interaction);
        }
        $em->flush();

        $likes    = $interactionRepo->countByType($property->getId(), 'like');
        $dislikes = $interactionRepo->countByType($property->getId(), 'dislike');
        $property->setLikesCount($likes)->setDislikesCount($dislikes);
        $em->flush();

        $userReaction = $interactionRepo->findOneByPropertyAndUser($property->getId(), $user->getId());
        return new JsonResponse([
            'likesCount'    => $likes,
            'dislikesCount' => $dislikes,
            'userReaction'  => $userReaction ? $userReaction->getType() : null,
        ]);
    }

    // ── CHECK FAVORITE ────────────────────────────────────────────────────────

    #[Route('/{id}/is-favorite', name: 'is_favorite', methods: ['GET'])]
    public function isFavorite(Property $property, FavoriteRepository $favRepo): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['isFavorite' => false]);
        }
        $existing = $favRepo->findOneBy(['locataire' => $user, 'property' => $property]);
        return new JsonResponse(['isFavorite' => $existing !== null]);
    }

    private function saveBase64Images(array $images, string $projectDir): array
    {
        $result = [];
        $uploadDir = $projectDir . '/public/uploads/properties';
        if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);

        foreach ($images as $img) {
            if (str_starts_with($img, 'data:')) {
                if (preg_match('/^data:image\/(\w+);base64,(.+)$/', $img, $m)) {
                    $ext      = in_array($m[1], ['jpeg','jpg','png','webp']) ? $m[1] : 'jpg';
                    $filename = uniqid('img_') . '.' . $ext;
                    file_put_contents($uploadDir . '/' . $filename, base64_decode($m[2]));
                    $result[] = '/uploads/properties/' . $filename;
                }
            } elseif (str_starts_with($img, '/') || str_starts_with($img, 'http')) {
                $result[] = $img;
            }
        }
        return $result;
    }

    private function mapStatusToBackend(string $status): string
    {
        return match(strtolower($status)) {
            'en_attente', 'pending', 'draft' => Property::STATUS_PENDING ?? 'pending',
            'actif', 'active' => Property::STATUS_ACTIVE,
            'loué', 'loue', 'rented' => 'rented',
            'suspendu', 'suspended' => 'suspended',
            default => $status,
        };
    }

    private function mapStatusToMobile(string $status): string
    {
        return match($status) {
            'pending', 'draft' => 'en_attente',
            'active' => 'actif',
            'suspended' => 'suspendu',
            default => $status,
        };
    }

    private function serializeProperty(Property $property): array
    {
        $statut = $property->getStatut();
        return [
            // Noms anglais (backend standard)
            'id' => $property->getId(),
            'title' => $property->getTitle(),
            'description' => $property->getDescription(),
            'address' => $property->getAddress(),
            'city' => $property->getCity(),
            'zipCode' => $property->getZipCode(),
            'pricePerMonth' => (float)$property->getPricePerMonth(),
            'rooms' => $property->getRooms(),
            'bedrooms' => $property->getBedrooms(),
            'surface' => $property->getSurface(),
            'furnished' => $property->isFurnished(),
            'hasParking' => $property->hasParking(),
            'type' => $property->getType(),
            'images' => $property->getImages() ?? [],
            'statut' => $statut,
            'ownerId' => $property->getProprietaire()->getId(),
            'ownerName' => $property->getProprietaire()->getFullName(),
            'rating' => $property->getRating(),
            'views' => $property->getViews(),
            'verified' => $property->isVerified(),
            'isHighlighted' => $property->isHighlighted(),
            'createdAt' => $property->getCreatedAt()?->format('c'),
            // Aliases français pour compatibilité mobile
            'titre' => $property->getTitle(),
            'lieu' => $property->getAddress(),
            'prix' => (int)$property->getPricePerMonth(),
            'pieces' => $property->getRooms(),
            'ville' => $property->getCity(),
            'superficie' => $property->getSurface(),
            'status' => $this->mapStatusToMobile($statut),
            'proprietaireId' => $property->getProprietaire()->getId(),
        ];
    }
}
