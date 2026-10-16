<?php

namespace App\Controller\Api;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/kyc', name: 'api_kyc_')]
class KycController extends AbstractController
{
    /** Soumettre les documents KYC après inscription (appelé par le mobile) */
    #[Route('/submit', name: 'submit', methods: ['POST'])]
    public function submit(Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true) ?? [];

        if (isset($data['kycIdentiteUrl']))         $user->setKycIdentiteUrl($data['kycIdentiteUrl']);
        if (isset($data['kycIdentiteType']))        $user->setKycIdentiteType($data['kycIdentiteType']);
        if (isset($data['kycDomicileUrl']))         $user->setKycDomicileUrl($data['kycDomicileUrl']);
        if (isset($data['kycDomicileType']))        $user->setKycDomicileType($data['kycDomicileType']);
        if (isset($data['kycProprieteUrl']))        $user->setKycProprieteUrl($data['kycProprieteUrl']);
        if (isset($data['kycProprieteType']))       $user->setKycProprieteType($data['kycProprieteType']);
        if (isset($data['kycRibUrl']))              $user->setKycRibUrl($data['kycRibUrl']);
        if (isset($data['kycAssuranceUrl']))        $user->setKycAssuranceUrl($data['kycAssuranceUrl']);
        if (isset($data['kycAvisImpositionUrl']))   $user->setKycAvisImpositionUrl($data['kycAvisImpositionUrl']);
        if (isset($data['kycCasParticulier']))      $user->setKycCasParticulier($data['kycCasParticulier']);
        if (isset($data['kycCasParticulierUrl']))   $user->setKycCasParticulierUrl($data['kycCasParticulierUrl']);

        $user->setKycStatus('pending');
        $user->setKycSubmittedAt(new \DateTimeImmutable());
        $user->setVerificationStatus('en_attente');

        // Stocker JSON consolidé (pour rétro-compatibilité admin web)
        $allDocs = array_filter([
            'identite'        => $data['kycIdentiteUrl'] ?? null,
            'domicile'        => $data['kycDomicileUrl'] ?? null,
            'propriete'       => $data['kycProprieteUrl'] ?? null,
            'rib'             => $data['kycRibUrl'] ?? null,
            'assurance'       => $data['kycAssuranceUrl'] ?? null,
            'avis_imposition' => $data['kycAvisImpositionUrl'] ?? null,
            'cas_particulier' => $data['kycCasParticulierUrl'] ?? null,
        ]);
        if (!empty($allDocs)) {
            $user->setKycDocuments(json_encode($allDocs));
        }

        $em->flush();

        return new JsonResponse([
            'success' => true,
            'message' => 'Documents KYC soumis. Validation sous 24–48h.',
            'status'  => 'pending',
        ]);
    }

    /**
     * GET /api/kyc/profile — Profil complet avec données KYC (pour le mobile)
     */
    #[Route('/profile', name: 'profile', methods: ['GET'])]
    public function profile(): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $roles = $user->getRoles();
        if (in_array('ROLE_ADMIN', $roles)) {
            $role = 'admin';
        } elseif (in_array('ROLE_PROPRIETAIRE', $roles)) {
            $role = 'proprietaire';
        } else {
            $role = 'locataire';
        }

        return new JsonResponse([
            'id'                 => $user->getId(),
            'email'              => $user->getEmail(),
            'prenom'             => $user->getPrenom(),
            'nom'                => $user->getNom(),
            'telephone'          => $user->getTelephone(),
            'role'               => $role,
            'isVerified'         => $user->isVerified() ? 1 : 0,
            'verificationStatus' => $user->getVerificationStatus(),
            'kycStatus'          => $user->getKycStatus(),
            'kycRejectionReason' => $user->getKycRejectionReason(),
            'kycSubmittedAt'     => $user->getKycSubmittedAt()?->format('c'),
            'kycApprovedAt'      => $user->getKycApprovedAt()?->format('c'),
            'kycBadgeVisible'    => $user->isKycApproved() ? 1 : 0,
            'subscriptionType'   => $user->getSubscriptionType(),
            'rating'             => $user->getRating(),
            'reviewCount'        => $user->getReviewCount(),
            'documents' => [
                'identite'       => ['url' => $user->getKycIdentiteUrl(),         'type' => $user->getKycIdentiteType()],
                'domicile'       => ['url' => $user->getKycDomicileUrl(),         'type' => $user->getKycDomicileType()],
                'propriete'      => ['url' => $user->getKycProprieteUrl(),        'type' => $user->getKycProprieteType()],
                'rib'            => ['url' => $user->getKycRibUrl()],
                'assurance'      => ['url' => $user->getKycAssuranceUrl()],
                'avisImposition' => ['url' => $user->getKycAvisImpositionUrl()],
                'casParticulier' => ['url' => $user->getKycCasParticulierUrl(),   'type' => $user->getKycCasParticulier()],
            ],
        ]);
    }

    /** Statut KYC du compte connecté */
    #[Route('/status', name: 'status', methods: ['GET'])]
    public function status(): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        return new JsonResponse([
            'kycStatus'          => $user->getKycStatus(),
            'verificationStatus' => $user->getVerificationStatus(),
            'isApproved'         => $user->isKycApproved(),
            'isPending'          => $user->isKycPending(),
            'isRejected'         => $user->isKycRejected(),
            'rejectionReason'    => $user->getKycRejectionReason(),
            'submittedAt'        => $user->getKycSubmittedAt()?->format('c'),
            'approvedAt'         => $user->getKycApprovedAt()?->format('c'),
            'hasDocuments'       => $user->hasKycDocuments(),
            'documents' => [
                'identite'       => ['url' => $user->getKycIdentiteUrl(),         'type' => $user->getKycIdentiteType()],
                'domicile'       => ['url' => $user->getKycDomicileUrl(),         'type' => $user->getKycDomicileType()],
                'propriete'      => ['url' => $user->getKycProprieteUrl(),        'type' => $user->getKycProprieteType()],
                'rib'            => ['url' => $user->getKycRibUrl()],
                'assurance'      => ['url' => $user->getKycAssuranceUrl()],
                'avisImposition' => ['url' => $user->getKycAvisImpositionUrl()],
                'casParticulier' => ['url' => $user->getKycCasParticulierUrl(),   'type' => $user->getKycCasParticulier()],
            ],
        ]);
    }
}
