<?php

namespace App\Controller\Api;

use App\Entity\Property;
use App\Entity\Report;
use App\Entity\User;
use App\Repository\ReportRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

/**
 * Correspond à la Séquence 4 du mémoire : Porter Plainte (Locataire)
 * Acteurs : Locataire → Système → Base de données → (Administrateur notifié)
 */
#[Route('/api/reports', name: 'api_reports_')]
class ReportApiController extends AbstractController
{
    // Séquence 4 : Locataire → Porter plainte(nom, tel, message) → Système
    #[Route('', name: 'create', methods: ['POST'])]
    public function create(
        Request $request,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): JsonResponse {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $data = json_decode($request->getContent(), true);

        // Champs obligatoires selon le diagramme de classes : motif (= message dans la Plainte)
        $motif = $data['motif'] ?? $data['message'] ?? $data['description'] ?? null;
        if (!$motif) {
            return new JsonResponse(['error' => 'Le motif est obligatoire'], Response::HTTP_BAD_REQUEST);
        }

        $type = $data['type'] ?? Report::TYPE_USER;

        // Validation du type selon les constantes de l'entité
        $validTypes = [Report::TYPE_PROPERTY, Report::TYPE_USER, Report::TYPE_REVIEW];
        if (!in_array($type, $validTypes)) {
            $type = Report::TYPE_USER;
        }

        $report = new Report();
        $report->setSignataire($user);
        $report->setMotif($motif);
        $report->setType($type);
        $report->setStatut(Report::STATUS_OPEN);

        // Priorité selon les données reçues (FR ou EN)
        $priorityMap = [
            'basse' => 'low', 'low' => 'low',
            'moyenne' => 'medium', 'medium' => 'medium',
            'haute' => 'high', 'high' => 'high',
            'critique' => 'critical', 'critical' => 'critical',
        ];
        $rawPriority = strtolower($data['priorite'] ?? $data['priority'] ?? 'medium');
        $report->setPriorite($priorityMap[$rawPriority] ?? Report::PRIORITY_MEDIUM);

        // Lien vers un bien si fourni
        if (!empty($data['propertyId']) || !empty($data['property_id'])) {
            $propertyId = $data['propertyId'] ?? $data['property_id'];
            $property = $em->getRepository(Property::class)->find($propertyId);
            if ($property) {
                $report->setProperty($property);
            }
        }

        // Utilisateur ciblé si fourni
        if (!empty($data['targetUserId']) || !empty($data['target_user_id'])) {
            $targetId = $data['targetUserId'] ?? $data['target_user_id'];
            $targetUser = $em->getRepository(User::class)->find($targetId);
            if ($targetUser) {
                $report->setUtilisateur($targetUser);
            }
        }

        $em->persist($report);
        $em->flush();

        // Séquence 4 : après enregistrement → notifier les admins
        $notificationService->notifyAdmins(
            'report_created',
            sprintf('%s a déposé un signalement : "%s"', $user->getFullName(), substr($motif, 0, 100)),
            'Nouveau signalement',
            $report->getId(),
            'report'
        );

        return new JsonResponse([
            'message' => 'Signalement enregistré avec succès',
            'id'      => $report->getId(),
            'statut'  => $report->getStatut(),
        ], Response::HTTP_CREATED);
    }

    // Liste des signalements du locataire connecté
    #[Route('', name: 'list', methods: ['GET'])]
    public function list(ReportRepository $repository): JsonResponse
    {
        $user = $this->getUser();
        if (!$user instanceof User) {
            return new JsonResponse(['error' => 'Unauthorized'], Response::HTTP_UNAUTHORIZED);
        }

        $reports = $repository->findBy(['signataire' => $user], ['createdAt' => 'DESC']);

        return new JsonResponse(array_map(fn(Report $r) => $this->serializeReport($r), $reports));
    }

    // Détail d'un signalement
    #[Route('/{id}', name: 'show', methods: ['GET'])]
    public function show(Report $report): JsonResponse
    {
        $user = $this->getUser();
        if ($report->getSignataire() !== $user && !in_array('ROLE_ADMIN', $user->getRoles())) {
            return new JsonResponse(['error' => 'Forbidden'], Response::HTTP_FORBIDDEN);
        }

        return new JsonResponse($this->serializeReport($report));
    }

    private function serializeReport(Report $r): array
    {
        $statutFr = match($r->getStatut()) {
            'open'       => 'Ouvert',
            'in_review'  => 'En cours',
            'resolved'   => 'Résolu',
            'dismissed'  => 'Rejeté',
            default      => $r->getStatut(),
        };

        $prioriteFr = match($r->getPriorite()) {
            'low'      => 'Basse',
            'medium'   => 'Moyenne',
            'high'     => 'Haute',
            'critical' => 'Critique',
            default    => $r->getPriorite(),
        };

        return [
            'id'              => $r->getId(),
            'type'            => $r->getType(),
            'motif'           => $r->getMotif(),
            // Alias mobile
            'message'         => $r->getMotif(),
            'description'     => $r->getMotif(),
            'statut'          => $r->getStatut(),
            'statutFr'        => $statutFr,
            'priorite'        => $r->getPriorite(),
            'prioriteFr'      => $prioriteFr,
            'signataireId'    => $r->getSignataire()->getId(),
            'signataireName'  => $r->getSignataire()->getFullName(),
            'propertyId'      => $r->getProperty()?->getId(),
            'propertyTitle'   => $r->getProperty()?->getTitle(),
            'targetUserId'    => $r->getUtilisateur()?->getId(),
            'targetUserName'  => $r->getUtilisateur()?->getFullName(),
            'createdAt'       => $r->getCreatedAt()->format('c'),
            'dateCreation'    => $r->getCreatedAt()->format('c'),
            'resolvedAt'      => $r->getResolvedAt()?->format('c'),
        ];
    }
}
