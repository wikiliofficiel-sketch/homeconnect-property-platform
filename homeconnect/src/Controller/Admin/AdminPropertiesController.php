<?php

namespace App\Controller\Admin;

use App\Entity\Notification;
use App\Entity\Property;
use App\Entity\User;
use App\Repository\PropertyRepository;
use App\Repository\UserRepository;
use App\Service\CommissionService;
use App\Service\LogService;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/properties', name: 'admin_properties_')]
#[IsGranted('ROLE_ADMIN')]
class AdminPropertiesController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(PropertyRepository $propertyRepo, Request $request): Response
    {
        $status = $request->query->get('status', '');

        $query = $propertyRepo->createQueryBuilder('p');

        if ($status && in_array($status, [Property::STATUS_ACTIVE, Property::STATUS_PENDING, Property::STATUS_SUSPENDED, Property::STATUS_DRAFT])) {
            $query->andWhere('p.statut = :status')
                  ->setParameter('status', $status);
        }

        $properties = $query->orderBy('p.createdAt', 'DESC')->getQuery()->getResult();

        $stats = [
            'draft' => $propertyRepo->countByStatut(Property::STATUS_DRAFT),
            'pending' => $propertyRepo->countByStatut(Property::STATUS_PENDING),
            'active' => $propertyRepo->countByStatut(Property::STATUS_ACTIVE),
            'suspended' => $propertyRepo->countByStatut(Property::STATUS_SUSPENDED),
        ];

        return $this->render('admin/properties/index.html.twig', [
            'properties' => $properties,
            'status' => $status,
            'stats' => $stats,
        ]);
    }

    #[Route('/{id}/detail', name: 'show')]
    public function show(Property $property): Response
    {
        return $this->render('admin/properties/show.html.twig', [
            'property' => $property,
        ]);
    }

    #[Route('/{id}/approve', name: 'approve', methods: ['POST'])]
    public function approve(Property $property, EntityManagerInterface $em, NotificationService $notificationService, LogService $logService): Response
    {
        $property->setStatut(Property::STATUS_ACTIVE);
        $em->flush();

        $notificationService->notifyAndFlush(
            $property->getProprietaire(),
            'property_validated',
            sprintf('Votre bien "%s" a été validé et est maintenant visible par les locataires.', $property->getTitle()),
            'Bien validé',
            $property->getId(),
            'property'
        );

        $logService->propertyApproved($property->getTitle(), $property->getId());

        $this->addFlash('success', 'Bien approuvé. Le propriétaire a été notifié.');
        return $this->redirectToRoute('admin_properties_show', ['id' => $property->getId()]);
    }

    #[Route('/{id}/suspend', name: 'suspend', methods: ['POST'])]
    public function suspend(Property $property, Request $request, EntityManagerInterface $em, NotificationService $notificationService, LogService $logService): Response
    {
        $motif = $request->request->get('motif', '');
        $property->setStatut(Property::STATUS_SUSPENDED);
        $property->setMotifSuspension($motif ?: null);
        $em->flush();

        $message = sprintf('Votre bien "%s" a été suspendu par l\'administrateur.', $property->getTitle());
        if ($motif) {
            $message .= ' Motif : ' . $motif;
        }

        $notificationService->notifyAndFlush(
            $property->getProprietaire(),
            'property_suspended',
            $message,
            'Bien suspendu',
            $property->getId(),
            'property'
        );

        $logService->propertySuspended($property->getTitle(), $property->getId(), $motif);

        $this->addFlash('success', 'Bien suspendu. Le propriétaire a été notifié.');
        return $this->redirectToRoute('admin_properties_show', ['id' => $property->getId()]);
    }

    #[Route('/{id}/delete', name: 'delete', methods: ['POST'])]
    public function delete(Property $property, EntityManagerInterface $em, LogService $logService): Response
    {
        $title = $property->getTitle();
        $id    = $property->getId();
        $em->remove($property);
        $em->flush();

        $logService->propertyDeleted($title, $id);

        $this->addFlash('success', 'Bien supprimé');
        return $this->redirectToRoute('admin_properties_index');
    }

    // ── Création de bien par l'admin ──────────────────────────────────────

    #[Route('/new', name: 'new', methods: ['GET', 'POST'])]
    public function new(Request $request, EntityManagerInterface $em, UserRepository $userRepo): Response
    {
        if ($request->isMethod('POST')) {
            /** @var User $admin */
            $admin = $this->getUser();

            $ownerId = $request->request->get('proprietaire_id');
            $owner   = $ownerId ? $userRepo->find($ownerId) : $admin;
            if (!$owner) {
                $this->addFlash('danger', 'Propriétaire introuvable.');
                return $this->redirectToRoute('admin_properties_new');
            }

            $property = new Property();
            $property->setProprietaire($owner)
                ->setTitle($request->request->get('title'))
                ->setDescription($request->request->get('description'))
                ->setAddress($request->request->get('address'))
                ->setCity($request->request->get('city'))
                ->setZipCode($request->request->get('zipCode', ''))
                ->setCountry($request->request->get('country', 'Bénin'))
                ->setPricePerMonth($request->request->get('pricePerMonth'))
                ->setDeposit($request->request->get('deposit') ?: null)
                ->setRooms((int) $request->request->get('rooms', 1))
                ->setBedrooms((int) $request->request->get('bedrooms', 0))
                ->setSurface((float) $request->request->get('surface', 0))
                ->setType($request->request->get('propertyType'))
                ->setEquipements($request->request->all('equipments') ?: [])
                ->setAnimauxAcceptes(in_array('pets_allowed', $request->request->all('rules') ?: []))
                ->setFumeursAcceptes(in_array('smoking_allowed', $request->request->all('rules') ?: []))
                ->setStatut(Property::STATUS_ACTIVE); // L'admin publie directement

            $photosJson = $request->request->get('photos_base64');
            if ($photosJson) {
                $photos = json_decode($photosJson, true);
                if (is_array($photos)) {
                    $property->setImages($this->saveBase64Images($photos));
                }
            }

            $em->persist($property);

            // Notifier le propriétaire si différent de l'admin
            if ($owner !== $admin) {
                $notif = new Notification();
                $notif->setDestinataire($owner)
                    ->setType('property_validated')
                    ->setMessage(sprintf('L\'administrateur a publié le bien "%s" sur votre compte.', $property->getTitle()))
                    ->setRelatedEntityId(0)
                    ->setRelatedEntityType('property');
                $em->persist($notif);
            }

            $em->flush();

            $this->addFlash('success', sprintf('Bien "%s" créé et publié directement.', $property->getTitle()));
            return $this->redirectToRoute('admin_properties_index');
        }

        $proprietaires = $userRepo->createQueryBuilder('u')
            ->where('u.roles LIKE :role')
            ->setParameter('role', '%ROLE_PROPRIETAIRE%')
            ->orderBy('u.nom', 'ASC')
            ->getQuery()
            ->getResult();

        return $this->render('admin/properties/create.html.twig', [
            'proprietaires' => $proprietaires,
        ]);
    }

    private function saveBase64Images(array $images): array
    {
        $uploadDir = $this->getParameter('kernel.project_dir') . '/public/uploads/properties';
        if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);

        $result = [];
        foreach ($images as $img) {
            if (is_string($img) && str_starts_with($img, 'data:image/')) {
                try {
                    $base64 = explode(',', $img, 2)[1] ?? '';
                    $data   = base64_decode($base64);
                    $ext    = str_contains($img, 'png') ? 'png' : (str_contains($img, 'webp') ? 'webp' : 'jpg');
                    $name   = uniqid('prop_', true) . '.' . $ext;
                    file_put_contents($uploadDir . '/' . $name, $data);
                    $result[] = '/uploads/properties/' . $name;
                } catch (\Throwable) {
                    $result[] = $img;
                }
            } else {
                $result[] = $img;
            }
        }
        return $result;
    }
}
