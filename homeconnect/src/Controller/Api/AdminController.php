<?php

namespace App\Controller\Api;

use App\Entity\Commission;
use App\Entity\Subscription;
use App\Entity\User;
use App\Repository\CommissionRepository;
use App\Repository\SubscriptionRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/admin', name: 'api_admin_')]
class AdminController extends AbstractController
{
    #[Route('/commissions', name: 'commissions_list', methods: ['GET'])]
    public function listCommissions(CommissionRepository $repository): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        
        $commissions = $repository->findAll();
        $data = [];
        foreach ($commissions as $comm) {
            $data[] = [
                'id' => $comm->getId(),
                'rentalId' => $comm->getRental()->getId(),
                'montantLocation' => $comm->getMontantLocation(),
                'montantCommission' => $comm->getMontantCommission(),
                'createdAt' => $comm->getCreatedAt()->format('c'),
            ];
        }

        return new JsonResponse($data);
    }

    #[Route('/subscriptions', name: 'subscriptions_list', methods: ['GET'])]
    public function listSubscriptions(SubscriptionRepository $repository): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        
        $subscriptions = $repository->findAll();
        $data = [];
        foreach ($subscriptions as $sub) {
            $data[] = [
                'id' => $sub->getId(),
                'proprietaire' => $sub->getProprietaire()->getFullName(),
                'plan' => $sub->getPlan(),
                'dateExpiration' => $sub->getDateExpiration() ? $sub->getDateExpiration()->format('c') : null,
                'statut' => $sub->getStatut(),
            ];
        }

        return new JsonResponse($data);
    }

    #[Route('/user/{id}/verify-kyc', name: 'verify_kyc', methods: ['POST'])]
    public function verifyKyc(
        User $user,
        Request $request,
        EntityManagerInterface $em
    ): JsonResponse {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        
        $data = json_decode($request->getContent(), true);
        $status = $data['status'] ?? 'approved';
        
        $user->setKycStatus($status);
        if ($status === 'approved') {
            $user->setKycApprovedAt(new \DateTimeImmutable());
        } else {
            $user->setKycRejectionReason($data['reason'] ?? 'Document non conforme');
        }

        $em->flush();

        return new JsonResponse(['message' => 'KYC status updated']);
    }

    // ── Tous les biens (toutes statuts) ─────────────────────────────────────

    #[Route('/properties', name: 'properties_list', methods: ['GET'])]
    public function listProperties(\App\Repository\PropertyRepository $repo): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');

        $properties = $repo->findAll();
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
                'titre'        => $p->getTitle(),
                'description'  => $p->getDescription(),
                'address'      => $p->getAddress(),
                'lieu'         => $p->getAddress(),
                'city'         => $p->getCity(),
                'ville'        => $p->getCity(),
                'pricePerMonth'=> (int) $p->getPricePerMonth(),
                'prix'         => (int) $p->getPricePerMonth(),
                'rooms'        => $p->getRooms(),
                'pieces'       => $p->getRooms(),
                'bedrooms'     => $p->getBedrooms(),
                'surface'      => $p->getSurface(),
                'type'         => $p->getType(),
                'statut'       => $p->getStatut(),
                'status'       => $p->getStatut(),
                'verified'     => $p->isVerified() ?? false,
                'views'        => $p->getViews() ?? 0,
                'images'       => $images,
                'imageUrl'     => $images[0] ?? null,
                'createdAt'    => $p->getCreatedAt()?->format('c'),
                'proprietaireId' => $owner?->getId(),
                'proprietaire' => $owner ? [
                    'id'     => $owner->getId(),
                    'nom'    => $owner->getNom(),
                    'prenom' => $owner->getPrenom(),
                    'email'  => $owner->getEmail(),
                ] : null,
            ];
        }

        return new JsonResponse($data);
    }

    // ── Valider / Rejeter un bien ────────────────────────────────────────────

    #[Route('/properties/{id}/approve', name: 'property_approve', methods: ['POST'])]
    public function approveProperty(int $id, \App\Repository\PropertyRepository $repo, \Doctrine\ORM\EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $p = $repo->find($id);
        if (!$p) return new JsonResponse(['error' => 'Introuvable'], 404);
        $p->setStatut(\App\Entity\Property::STATUS_ACTIVE);
        $em->flush();
        return new JsonResponse(['success' => true, 'statut' => 'active']);
    }

    #[Route('/properties/{id}/reject', name: 'property_reject', methods: ['POST'])]
    public function rejectProperty(int $id, \App\Repository\PropertyRepository $repo, \Doctrine\ORM\EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $p = $repo->find($id);
        if (!$p) return new JsonResponse(['error' => 'Introuvable'], 404);
        $p->setStatut(\App\Entity\Property::STATUS_SUSPENDED);
        $em->flush();
        return new JsonResponse(['success' => true, 'statut' => 'suspended']);
    }

    #[Route('/properties/{id}/delete', name: 'property_delete', methods: ['POST'])]
    public function deleteProperty(int $id, \App\Repository\PropertyRepository $repo, \Doctrine\ORM\EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $p = $repo->find($id);
        if (!$p) return new JsonResponse(['error' => 'Introuvable'], 404);
        $em->remove($p);
        $em->flush();
        return new JsonResponse(['success' => true]);
    }

    // ── Liste des utilisateurs ───────────────────────────────────────────────

    #[Route('/users', name: 'users_list', methods: ['GET'])]
    public function listUsers(\App\Repository\UserRepository $repo): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');

        $users = $repo->findAll();
        $data  = [];
        foreach ($users as $user) {
            $roles = $user->getRoles();
            if (in_array('ROLE_ADMIN', $roles)) {
                $role = 'admin';
            } elseif (in_array('ROLE_PROPRIETAIRE', $roles)) {
                $role = 'proprietaire';
            } elseif (in_array('ROLE_LOCATAIRE', $roles)) {
                $role = 'locataire';
            } else {
                $role = 'locataire';
            }
            $data[] = [
                'id'                 => $user->getId(),
                'email'              => $user->getEmail(),
                'nom'                => $user->getNom() ?? '',
                'prenom'             => $user->getPrenom() ?? '',
                'telephone'          => $user->getTelephone() ?? '',
                'role'               => $role,
                'isVerified'         => $user->isVerified() ? 1 : 0,
                'verificationStatus' => $user->getVerificationStatus() ?? 'en_attente',
                'subscriptionType'   => $user->getSubscriptionType() ?? 'gratuit',
                'rating'             => $user->getRating() ?? 0.0,
                'reviewCount'        => $user->getReviewCount() ?? 0,
                'kyc_status'         => $user->getKycStatus(),
            ];
        }

        return new JsonResponse($data);
    }

    // ── Routes de certification mobile ───────────────────────────────────────

    #[Route('/kyc/{id}/approve', name: 'kyc_approve_mobile', methods: ['GET', 'POST'])]
    public function kycApprove(int $id, \App\Repository\UserRepository $repo, EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $user = $repo->find($id);
        if (!$user) return new JsonResponse(['error' => 'Introuvable'], 404);

        $user->setKycStatus('approved');
        $user->setKycApprovedAt(new \DateTimeImmutable());
        $user->setVerificationStatus('certifie');
        $user->setIsVerified(true);
        $em->flush();

        return new JsonResponse(['success' => true, 'message' => 'Compte certifié.', 'verificationStatus' => 'certifie']);
    }

    /**
     * POST /api/admin/kyc/{id}/reject  — rejeter un dossier avec motif
     */
    #[Route('/kyc/{id}/reject', name: 'kyc_reject_mobile', methods: ['POST'])]
    public function kycReject(int $id, Request $request, \App\Repository\UserRepository $repo, EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $user = $repo->find($id);
        if (!$user) return new JsonResponse(['error' => 'Introuvable'], 404);

        $data   = json_decode($request->getContent(), true) ?? [];
        $reason = $data['reason'] ?? $request->request->get('reason', 'Documents non conformes.');
        $user->setKycStatus('rejected');
        $user->setKycRejectionReason($reason);
        $user->setVerificationStatus('rejete');
        $user->setIsVerified(false);
        $em->flush();

        return new JsonResponse(['success' => true, 'verificationStatus' => 'rejete']);
    }

    #[Route('/kyc/{id}/suspend', name: 'kyc_suspend_mobile', methods: ['POST'])]
    public function kycSuspend(int $id, Request $request, \App\Repository\UserRepository $repo, EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $user = $repo->find($id);
        if (!$user) return new JsonResponse(['error' => 'Introuvable'], 404);

        $data   = json_decode($request->getContent(), true) ?? [];
        $reason = $data['reason'] ?? 'Suspendu par l\'administrateur.';
        $user->setKycStatus('rejected');
        $user->setKycRejectionReason($reason);
        $user->setVerificationStatus('rejete');
        $user->setIsVerified(false);
        $em->flush();

        return new JsonResponse(['success' => true]);
    }

    #[Route('/logs', name: 'logs_list', methods: ['GET'])]
    public function listLogs(\App\Repository\LogRepository $logRepo, \Symfony\Component\HttpFoundation\Request $request): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');

        $action   = $request->query->get('action', '');
        $dateFrom = $request->query->get('date_from', '');
        $dateTo   = $request->query->get('date_to', '');

        $qb = $logRepo->createQueryBuilder('l')
            ->leftJoin('l.user', 'u')->addSelect('u')
            ->orderBy('l.createdAt', 'DESC');

        if ($action) $qb->andWhere('l.action = :a')->setParameter('a', $action);
        if ($dateFrom) $qb->andWhere('l.createdAt >= :from')->setParameter('from', new \DateTimeImmutable($dateFrom . ' 00:00:00'));
        if ($dateTo)   $qb->andWhere('l.createdAt <= :to')->setParameter('to', new \DateTimeImmutable($dateTo . ' 23:59:59'));

        $logs = $qb->setMaxResults(200)->getQuery()->getResult();

        $data = array_map(fn(\App\Entity\Log $l) => [
            'id'        => $l->getId(),
            'action'    => $l->getAction(),
            'details'   => $l->getDetails(),
            'createdAt' => $l->getCreatedAt()?->format('c'),
            'admin'     => $l->getUser() ? [
                'id'    => $l->getUser()->getId(),
                'email' => $l->getUser()->getEmail(),
                'name'  => $l->getUser()->getFullName(),
            ] : null,
        ], $logs);

        return new JsonResponse($data);
    }

    #[Route('/users/{id}', name: 'user_delete', methods: ['DELETE'])]
    public function deleteUser(int $id, \App\Repository\UserRepository $repo, EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $current = $this->getUser();
        $user    = $repo->find($id);
        if (!$user) return new JsonResponse(['error' => 'Introuvable'], 404);
        if ($current instanceof \App\Entity\User && $current->getId() === $user->getId()) {
            return new JsonResponse(['error' => 'Impossible de supprimer son propre compte'], 400);
        }
        $em->remove($user);
        $em->flush();
        return new JsonResponse(['success' => true]);
    }

    #[Route('/properties/{id}/suspend', name: 'property_suspend', methods: ['POST'])]
    public function suspendProperty(int $id, Request $request, \App\Repository\PropertyRepository $repo, EntityManagerInterface $em): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');
        $property = $repo->find($id);
        if (!$property) return new JsonResponse(['error' => 'Bien introuvable'], 404);

        $data  = json_decode($request->getContent(), true) ?? [];
        $motif = $data['motif'] ?? 'Suspendu par l\'administrateur';
        $property->setStatut(\App\Entity\Property::STATUS_SUSPENDED);
        $property->setMotifSuspension($motif);
        $em->flush();

        return new JsonResponse(['success' => true]);
    }
}
