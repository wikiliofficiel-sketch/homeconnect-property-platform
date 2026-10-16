<?php

namespace App\Controller\Api;

use App\Entity\Application;
use App\Entity\Property;
use App\Entity\User;
use App\Repository\ApplicationRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/applications', name: 'api_applications_')]
class ApplicationController extends AbstractController
{
    #[Route('', name: 'list', methods: ['GET'])]
    public function list(ApplicationRepository $repository): JsonResponse
    {
        $user = $this->getUser();
        $applications = $repository->findBy(['locataire' => $user]);
        
        $data = [];
        foreach ($applications as $app) {
            $data[] = $this->serializeApplication($app);
        }

        return new JsonResponse($data);
    }

    // Candidatures reçues sur les biens du propriétaire connecté
    #[Route('/owner', name: 'owner_list', methods: ['GET'])]
    public function ownerList(ApplicationRepository $repository, EntityManagerInterface $em): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        // Récupère toutes les candidatures pour les biens du propriétaire
        $qb = $em->createQueryBuilder();
        $applications = $qb->select('a')
            ->from(Application::class, 'a')
            ->join('a.property', 'p')
            ->where('p.proprietaire = :owner')
            ->setParameter('owner', $user)
            ->orderBy('a.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        return new JsonResponse(array_map(fn($a) => $this->serializeApplication($a), $applications));
    }

    // Route originale avec propertyId en path
    #[Route('/submit/{propertyId}', name: 'submit', methods: ['POST'])]
    public function submit(
        int $propertyId,
        EntityManagerInterface $em,
        Request $request,
        NotificationService $notificationService
    ): JsonResponse {
        return $this->createApplication($propertyId, $em, $request, $notificationService);
    }

    // Mobile appelle POST /api/applications/new avec { propertyId, message } dans le body
    #[Route('/new', name: 'new', methods: ['POST'])]
    public function new(EntityManagerInterface $em, Request $request, NotificationService $notificationService): JsonResponse
    {
        $data = json_decode($request->getContent(), true);
        $propertyId = $data['propertyId'] ?? $data['property_id'] ?? null;

        if (!$propertyId) {
            return new JsonResponse(['error' => 'propertyId is required'], Response::HTTP_BAD_REQUEST);
        }

        return $this->createApplication((int)$propertyId, $em, $request, $notificationService);
    }

    // Séquence 3 du mémoire : Admin/Propriétaire → Valider/Refuser candidature → Notifier Locataire
    #[Route('/{id}/status', name: 'update_status', methods: ['POST', 'PATCH'])]
    public function updateStatus(
        int $id,
        EntityManagerInterface $em,
        Request $request,
        NotificationService $notificationService
    ): JsonResponse {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $application = $em->getRepository(Application::class)->find($id);
        if (!$application) {
            return new JsonResponse(['error' => 'Application not found'], Response::HTTP_NOT_FOUND);
        }

        $isOwner = $application->getProperty()->getProprietaire() === $user;
        $isTenant = $application->getLocataire() === $user;
        $isAdmin = \in_array('ROLE_ADMIN', $user->getRoles());
        if (!$isOwner && !$isTenant && !$isAdmin) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        $data = json_decode($request->getContent(), true);
        $rawStatus = $data['status'] ?? $data['statut'] ?? null;

        if (!$rawStatus) {
            return new JsonResponse(['error' => 'status is required'], Response::HTTP_BAD_REQUEST);
        }

        $newStatut = $this->mapStatusToBackend($rawStatus);
        $application->setStatut($newStatut);
        $application->setRespondedAt(new \DateTime());

        if (isset($data['motifRefus']) || isset($data['rejection_reason'])) {
            $application->setMotifRefus($data['motifRefus'] ?? $data['rejection_reason']);
        }

        $em->flush();

        // Séquence 3 : Système → Notifier résultat demande → Locataire
        $locataire = $application->getLocataire();
        $propertyTitle = $application->getProperty()->getTitle();

        if ($newStatut === 'accepted') {
            $notificationService->notifyAndFlush(
                $locataire,
                'application_accepted',
                \sprintf('Votre candidature pour "%s" a été acceptée !', $propertyTitle),
                'Candidature acceptée',
                $application->getId(),
                'application'
            );
        } elseif ($newStatut === 'refused') {
            $motif = $application->getMotifRefus() ? ' Motif : ' . $application->getMotifRefus() : '';
            $notificationService->notifyAndFlush(
                $locataire,
                'application_refused',
                \sprintf('Votre candidature pour "%s" n\'a pas été retenue.%s', $propertyTitle, $motif),
                'Candidature refusée',
                $application->getId(),
                'application'
            );
        }

        return new JsonResponse([
            'message' => 'Statut de la candidature mis à jour',
            'application' => $this->serializeApplication($application),
        ]);
    }

    // Séquence 1 : Locataire → Faire demande → Système → BD → Notifier propriétaire
    private function createApplication(int $propertyId, EntityManagerInterface $em, Request $request, NotificationService $notificationService): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $property = $em->getRepository(Property::class)->find($propertyId);
        if (!$property) {
            return new JsonResponse(['error' => 'Property not found'], Response::HTTP_NOT_FOUND);
        }

        $data = json_decode($request->getContent(), true);

        $application = new Application();
        $application->setLocataire($user);
        $application->setProperty($property);
        $application->setStatut('pending');
        $application->setCreatedAt(new \DateTime());
        $application->setMessage($data['message'] ?? '');

        if (isset($data['dateDebut'])) {
            $application->setDateDebut(new \DateTime($data['dateDebut']));
        }
        if (isset($data['dateFin'])) {
            $application->setDateFin(new \DateTime($data['dateFin']));
        }

        $em->persist($application);
        $em->flush();

        // Séquence 1 : Système → Notifier nouvelle demande → Propriétaire du bien
        $proprietaire = $property->getProprietaire();
        $notificationService->notifyAndFlush(
            $proprietaire,
            'application_received',
            \sprintf('%s a soumis une candidature pour votre bien "%s"', $user->getFullName(), $property->getTitle()),
            'Nouvelle candidature',
            $application->getId(),
            'application'
        );

        return new JsonResponse([
            'message' => 'Candidature soumise avec succès',
            'id' => $application->getId(),
            'application' => $this->serializeApplication($application),
        ], Response::HTTP_CREATED);
    }

    private function mapStatusToBackend(string $status): string
    {
        return match(strtolower(trim($status))) {
            'en_attente', 'pending' => 'pending',
            'acceptée', 'acceptee', 'accepted', 'approved' => 'accepted',
            'rejetée', 'rejetee', 'refused', 'rejected' => 'refused',
            'annulée', 'annulee', 'cancelled', 'canceled' => 'cancelled',
            default => $status,
        };
    }

    private function serializeApplication(Application $app): array
    {
        $statut = $app->getStatut();
        $statutMobile = match($statut) {
            'pending' => 'en_attente',
            'accepted' => 'acceptée',
            'refused' => 'rejetée',
            'cancelled' => 'annulée',
            default => $statut,
        };

        return [
            'id' => $app->getId(),
            'propertyId' => $app->getProperty()->getId(),
            'propertyTitle' => $app->getProperty()->getTitle(),
            // Alias FR pour mobile
            'titreProperty' => $app->getProperty()->getTitle(),
            'locataireId' => $app->getLocataire()->getId(),
            'locataireName' => $app->getLocataire()->getFullName(),
            'email' => $app->getLocataire()->getEmail(),
            'telephone' => $app->getLocataire()->getTelephone(),
            'statut' => $statut,
            // Alias mobile
            'status' => $statutMobile,
            'dateCandidat' => $app->getCreatedAt()->format('c'),
            'createdAt' => $app->getCreatedAt()->format('c'),
            'message' => $app->getMessage(),
            'motifRefus' => $app->getMotifRefus(),
        ];
    }
}
