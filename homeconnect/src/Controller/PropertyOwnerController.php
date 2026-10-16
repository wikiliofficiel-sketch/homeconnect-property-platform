<?php

namespace App\Controller;

use App\Entity\Application;
use App\Entity\Property;
use App\Entity\User;
use App\Entity\Visite;
use App\Entity\Notification;
use App\Entity\Rental;
use App\Entity\Subscription;
use App\Repository\ApplicationRepository;
use App\Repository\MessageRepository;
use App\Repository\PropertyRepository;
use App\Repository\VisiteRepository;
use App\Repository\NotificationRepository;
use App\Repository\SubscriptionRepository;
use App\Service\CommissionService;
use App\Entity\SupportTicket;
use App\Repository\PartnerRepository;
use App\Repository\ReviewRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/proprietary')]
#[IsGranted('ROLE_PROPRIETAIRE')]
class PropertyOwnerController extends AbstractController
{
    #[Route('/', name: 'app_owner_dashboard')]
    public function dashboard(
        PropertyRepository $propertyRepo,
        ApplicationRepository $appRepo,
        SubscriptionRepository $subRepo,
        NotificationRepository $notifRepo,
        MessageRepository $messageRepo
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        // Verificar KYC
        if (!$user->canPublishProperty()) {
            $this->addFlash('warning', 'Votre compte doit être certifié KYC pour publier des biens.');
        }

        $myProperties = $propertyRepo->findBy(['proprietaire' => $user]);
        $pendingApplications = $appRepo->findBy(['property' => $myProperties, 'statut' => 'pending']);
        $subscription = $subRepo->findOneBy(['proprietaire' => $user]);
        $unreadNotifications = $notifRepo->findUnread($user->getId());

        // Load messages efficiently via repository (avoids lazy-loading all messages in Twig)
        $recentMessages = $messageRepo->findRecentReceived($user->getId(), 5);
        $unreadMessagesCount = $messageRepo->countUnreadReceived($user->getId());

        return $this->render('owner/dashboard.html.twig', [
            'properties'               => $myProperties,
            'rentals'                  => $user->getRentals(),
            'pendingApplicationsCount' => count($pendingApplications),
            'subscription'             => $subscription,
            'isPremium'                => $subscription && $subscription->isPremiumPlus(),
            'unreadNotificationsCount' => count($unreadNotifications),
            'recentMessages'           => $recentMessages,
            'unreadMessagesCount'      => $unreadMessagesCount,
            'stats' => [
                'activeProperties'  => count(array_filter($myProperties, fn($p) => $p->getStatut() === 'active')),
                'totalApplications' => count($appRepo->findBy(['property' => $myProperties])),
                'totalRentals'      => count($user->getRentals()),
            ]
        ]);
    }

    // ──────── MES BIENS ────────────────────────────────────────────────

    #[Route('/properties', name: 'app_owner_properties')]
    public function myProperties(PropertyRepository $repo, SubscriptionRepository $subRepo, EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $properties = $repo->findBy(['proprietaire' => $user], ['createdAt' => 'DESC']);

        $subscription = $subRepo->findOneBy(['proprietaire' => $user]);
        if (!$subscription) {
            $subscription = new Subscription();
            $subscription->setProprietaire($user);
            $em->persist($subscription);
            $em->flush();
        }
        $publishedCount = $repo->countActiveByOwner($user);

        return $this->render('owner/properties/list.html.twig', [
            'properties'     => $properties,
            'subscription'   => $subscription,
            'publishedCount' => $publishedCount,
            'canAddMore'     => $subscription->canPublishMore($publishedCount),
        ]);
    }

    #[Route('/properties/{id}/show', name: 'app_owner_property_show')]
    public function showProperty(
        Property $property,
        ApplicationRepository $appRepo
    ): Response {
        $this->denyAccessUnlessGranted('view', $property);

        $applications = $appRepo->findBy(['property' => $property], ['createdAt' => 'DESC']);

        return $this->render('owner/properties/show.html.twig', [
            'property'     => $property,
            'applications' => $applications,
            'stats' => [
                'views'        => $property->getViews(),
                'applications' => count($applications),
                'pending'      => count(array_filter($applications, fn($a) => $a->getStatut() === 'pending')),
                'accepted'     => count(array_filter($applications, fn($a) => $a->getStatut() === 'accepted')),
            ],
        ]);
    }

    #[Route('/properties/new', name: 'app_owner_property_new')]
    public function newProperty(
        Request $request,
        EntityManagerInterface $em,
        PropertyRepository $propertyRepo,
        SubscriptionRepository $subRepo,
        NotificationService $notificationService
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $isAdmin = in_array('ROLE_ADMIN', $user->getRoles());

        if (!$isAdmin && !$user->canPublishProperty()) {
            $this->addFlash('error', 'Certification KYC requise avant de publier. Veuillez soumettre vos documents.');
            return $this->redirectToRoute('app_owner_kyc');
        }

        // Vérifier la limite d'abonnement
        if (!$isAdmin) {
            $subscription = $subRepo->findOneBy(['proprietaire' => $user]);
            if (!$subscription) {
                // Aucun enregistrement → créer plan gratuit en base
                $subscription = new Subscription();
                $subscription->setProprietaire($user);
                $em->persist($subscription);
                $em->flush();
            }
            $publishedCount = $propertyRepo->countActiveByOwner($user);
            if (!$subscription->canPublishMore($publishedCount)) {
                $this->addFlash('warning', sprintf(
                    'Vous avez atteint la limite de %d bien(s) de votre plan %s. Passez à un abonnement supérieur pour en ajouter d\'autres.',
                    $subscription->getMaxProperties(),
                    $subscription->getPlanLabel()
                ));
                return $this->redirectToRoute('app_owner_subscription');
            }
        }

        $property = new Property();
        $property->setProprietaire($user);

        if ($request->isMethod('POST')) {
            $rules = $request->request->all('rules') ?: [];

            $property->setTitle($request->request->get('title'))
                ->setDescription($request->request->get('description'))
                ->setAddress($request->request->get('address'))
                ->setCity($request->request->get('city'))
                ->setZipCode($request->request->get('zipCode', ''))
                ->setCountry('Bénin')
                ->setPricePerMonth($request->request->get('pricePerMonth') ?: '0')
                ->setDeposit($request->request->get('deposit') ?: null)
                ->setRooms((int) $request->request->get('rooms', 1))
                ->setBedrooms((int) $request->request->get('bedrooms', 0))
                ->setSurface((float) $request->request->get('surface', 0))
                ->setType($request->request->get('propertyType'))
                ->setStatutAnnonce($request->request->get('statutAnnonce', 'À louer'))
                ->setPrixVente($request->request->get('prixVente') ?: null)
                ->setChargesComprises((bool) $request->request->get('chargesComprises'))
                ->setMontantCharges($request->request->get('montantCharges') ?: null)
                ->setFraisAgence($request->request->get('fraisAgence') ?: null)
                ->setNbSalons((int) $request->request->get('nbSalons', 0))
                ->setNbSallesDeBain((int) $request->request->get('nbSallesDeBain', 0))
                ->setNbToilettes((int) $request->request->get('nbToilettes', 0))
                ->setTypeCuisine($request->request->get('typeCuisine', 'Non équipée'))
                ->setEtage($request->request->get('etage') !== '' ? (int) $request->request->get('etage') : null)
                ->setHasAscenseur((bool) $request->request->get('hasAscenseur'))
                ->setHasParking((bool) $request->request->get('hasParking'))
                ->setParkingPlaces($request->request->get('hasParking') ? (int) $request->request->get('parkingPlaces', 1) : 0)
                ->setHasJardin((bool) $request->request->get('hasJardin'))
                ->setHasBalcon((bool) $request->request->get('hasBalcon'))
                ->setFurnished(in_array('meuble', $request->request->all('equipments') ?: []))
                ->setVideoUrl($request->request->get('videoUrl') ?: null)
                ->setDureeMinLocation($request->request->get('dureeMinLocation') ? (int) $request->request->get('dureeMinLocation') : null)
                ->setPreavis($request->request->get('preavis') ? (int) $request->request->get('preavis') : null)
                ->setDisponibilite($request->request->get('disponibilite') ?: null)
                ->setAnimauxAcceptes(in_array('pets_allowed', $rules))
                ->setFumeursAcceptes(in_array('smoking_allowed', $rules))
                ->setStatut('pending');

            $property->setEquipements($request->request->all('equipments') ?: []);

            $photosJson = $request->request->get('photos_base64');
            if ($photosJson) {
                $photos = json_decode($photosJson, true);
                if (is_array($photos)) {
                    $property->setImages($photos);
                }
            }

            $em->persist($property);
            $em->flush();

            // Notifier le propriétaire (confirmation)
            $notif = new Notification();
            $notif->setDestinataire($user)
                ->setType('property_submitted')
                ->setMessage('Votre bien "' . $property->getTitle() . '" a été soumis pour modération.')
                ->setRelatedEntityId($property->getId())
                ->setRelatedEntityType('property');
            $em->persist($notif);

            // Notifier les admins
            $notificationService->notifyAdmins(
                'property_submitted',
                sprintf(
                    'Nouveau bien soumis par %s : "%s" à %s.',
                    $user->getFullName(),
                    $property->getTitle(),
                    $property->getCity()
                ),
                'Nouveau bien à valider',
                $property->getId(),
                'property'
            );

            $this->addFlash('success', 'Bien soumis avec succès ! En attente de validation par l\'administrateur.');
            return $this->redirectToRoute('app_owner_properties');
        }

        return $this->render('owner/properties/create.html.twig');
    }

    #[Route('/properties/{id}/edit', name: 'app_owner_property_edit')]
    public function editProperty(Property $property, Request $request, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('edit', $property);

        if ($request->isMethod('POST')) {
            $property->setTitle($request->request->get('title'))
                ->setDescription($request->request->get('description'))
                ->setAddress($request->request->get('address'))
                ->setCity($request->request->get('city'))
                ->setZipCode($request->request->get('zipCode'))
                ->setPricePerMonth($request->request->get('pricePerMonth'))
                ->setDeposit($request->request->get('deposit'))
                ->setRooms($request->request->get('rooms'))
                ->setBedrooms($request->request->get('bedrooms'))
                ->setSurface($request->request->get('surface'))
                ->setFurnished($request->request->get('furnished') ? true : false)
                ->setHasParking($request->request->get('hasParking') ? true : false)
                ->setType($request->request->get('propertyType'))
                ->setUpdatedAt(new \DateTimeImmutable());

            // Handle images from Base64 JSON
            $photosJson = $request->request->get('photos_base64');
            if ($photosJson) {
                $photos = json_decode($photosJson, true);
                if (is_array($photos)) {
                    $property->setImages($photos);
                }
            }

            $em->flush();
            $this->addFlash('success', 'Bien modifié avec succès !');
            return $this->redirectToRoute('app_owner_properties');
        }

        return $this->render('owner/properties/edit.html.twig', [
            'property' => $property,
        ]);
    }

    #[Route('/properties/{id}/suspend', name: 'app_owner_property_suspend', methods: ['POST'])]
    public function suspendProperty(Property $property, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('edit', $property);

        if ($property->getStatut() !== Property::STATUS_ACTIVE) {
            $this->addFlash('warning', 'Seul un bien actif peut être suspendu temporairement.');
            return $this->redirectToRoute('app_owner_properties');
        }

        $property->setStatut(Property::STATUS_SUSPENDED);
        $property->setMotifSuspension('Suspendu par le propriétaire');
        $em->flush();

        $this->addFlash('success', 'Annonce suspendue. Elle n\'est plus visible par les locataires.');
        return $this->redirectToRoute('app_owner_properties');
    }

    #[Route('/properties/{id}/reactivate', name: 'app_owner_property_reactivate', methods: ['POST'])]
    public function reactivateProperty(Property $property, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('edit', $property);

        if ($property->getStatut() !== Property::STATUS_SUSPENDED) {
            $this->addFlash('warning', 'Seul un bien suspendu peut être réactivé.');
            return $this->redirectToRoute('app_owner_properties');
        }

        $property->setStatut(Property::STATUS_ACTIVE);
        $property->setMotifSuspension(null);
        $em->flush();

        $this->addFlash('success', 'Annonce réactivée avec succès. Elle est de nouveau visible par les locataires.');
        return $this->redirectToRoute('app_owner_properties');
    }

    #[Route('/properties/{id}/delete', name: 'app_owner_property_delete', methods: ['POST'])]
    public function deleteProperty(Property $property, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('delete', $property);

        $em->remove($property);
        $em->flush();

        $this->addFlash('success', 'Bien supprimé avec succès !');
        return $this->redirectToRoute('app_owner_properties');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€ CANDIDATURES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/applications', name: 'app_owner_applications')]
    public function applications(ApplicationRepository $repo): Response
    {        /** @var User $user */        $user = $this->getUser();
        $userProperties = $user->getProperties()->toArray();

        // Get all applications for this owner's properties
        $applications = [];
        foreach ($userProperties as $property) {
            $applications = array_merge($applications, $repo->findByProperty($property->getId()));
        }

        // Sort by date
        usort($applications, fn($a, $b) => $b->getCreatedAt() <=> $a->getCreatedAt());

        return $this->render('owner/applications/list.html.twig', [
            'applications' => $applications,
        ]);
    }

    #[Route('/applications/{id}', name: 'app_owner_application_show')]
    public function applicationDetail(Application $application): Response
    {
        $this->denyAccessUnlessGranted('view', $application);

        return $this->render('owner/applications/show.html.twig', [
            'application' => $application,
        ]);
    }

    #[Route('/applications/{id}/accept', name: 'app_owner_application_accept', methods: ['POST'])]
    public function acceptApplication(Application $application, EntityManagerInterface $em, CommissionService $commissionService): Response
    {
        $this->denyAccessUnlessGranted('edit', $application);

        $application->setStatut('accepted')
            ->setRespondedAt(new \DateTime());

        $rental = new Rental();
        $rental->setProperty($application->getProperty())
            ->setLocataire($application->getLocataire())
            ->setStartDate(\DateTimeImmutable::createFromInterface($application->getDateDebut()))
            ->setEndDate(\DateTimeImmutable::createFromInterface($application->getDateFin()))
            ->setMonthlyPrice($application->getProperty()->getPricePerMonth())
            ->setStatus('active');
        $em->persist($rental);

        $notif = new Notification();
        $notif->setDestinataire($application->getLocataire())
            ->setType('application_accepted')
            ->setMessage('Votre candidature pour ' . $application->getProperty()->getTitle() . ' a été acceptée ! Vous pouvez maintenant consulter votre contrat.')
            ->setRelatedEntityId($application->getId())
            ->setRelatedEntityType('rental')
            ->setLien($this->generateUrl('app_owner_application_show', ['id' => $application->getId()]));
        $em->persist($notif);

        $em->flush();

        // Générer la commission (5% gratuit, 3% starter/pro)
        $commissionService->generateForRental($rental);

        $this->addFlash('success', 'Candidature acceptée, location et commission créées !');
        return $this->redirectToRoute('app_owner_applications');
    }

    #[Route('/applications/{id}/refuse', name: 'app_owner_application_refuse', methods: ['POST'])]
    public function refuseApplication(Application $application, Request $request, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('edit', $application);

        $application->setStatut('refused')
            ->setRespondedAt(new \DateTime())
            ->setMotifRefus($request->request->get('motif'));

        // Create notification for locataire
        $notif = new Notification();
        $notif->setDestinataire($application->getLocataire())
            ->setType('application_refused')
            ->setMessage('Votre candidature pour ' . $application->getProperty()->getTitle() . ' a été refusée.')
            ->setRelatedEntityId($application->getId())
            ->setRelatedEntityType('application');
        $em->persist($notif);

        $em->flush();
        $this->addFlash('success', 'Candidature refusée !');
        return $this->redirectToRoute('app_owner_applications');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€ VISITES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/applications/{id}/schedule-visite', name: 'app_owner_schedule_visite', methods: ['POST'])]
    public function scheduleVisite(Application $application, Request $request, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('edit', $application);

        $visite = new Visite();
        $visite->setApplication($application)
            ->setDateHeureDebut(new \DateTime($request->request->get('dateHeureDebut')))
            ->setDateHeureFin(new \DateTime($request->request->get('dateHeureFin')))
            ->setNotes($request->request->get('notes'));

        // Notify locataire
        $notif = new Notification();
        $notif->setDestinataire($application->getLocataire())
            ->setType('visite_scheduled')
            ->setMessage('Une visite a été planifiée pour ' . $application->getProperty()->getTitle())
            ->setRelatedEntityId($visite->getId())
            ->setRelatedEntityType('visite');
        $em->persist($notif);

        $em->persist($visite);
        $em->flush();

        $this->addFlash('success', 'Visite planifiée !');
        return $this->redirectToRoute('app_owner_application_show', ['id' => $application->getId()]);
    }

    #[Route('/visites', name: 'app_owner_visites')]
    public function visites(VisiteRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $userProperties = $user->getProperties();

        // Get all visites for this owner's properties through applications
        $allVisites = [];
        foreach ($userProperties as $property) {
            $applications = $property->getApplications();
            foreach ($applications as $app) {
                $allVisites = array_merge($allVisites, $repo->findByApplicationId($app->getId()));
            }
        }

        usort($allVisites, fn($a, $b) => $a->getDateHeureDebut() <=> $b->getDateHeureDebut());

        return $this->render('owner/visites/list.html.twig', [
            'visites' => $allVisites,
        ]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€ ABONNEMENT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/subscription', name: 'app_owner_subscription')]
    public function subscription(
        SubscriptionRepository $repo,
        PropertyRepository $propRepo
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $subscription = $repo->findOneBy(['proprietaire' => $user]);

        if (!$subscription) {
            $subscription = new Subscription();
            $subscription->setProprietaire($user);
        }

        $publishedCount = $propRepo->countActiveByOwner($user);

        return $this->render('owner/subscription.html.twig', [
            'subscription'   => $subscription,
            'publishedCount' => $publishedCount,
            'canPublishMore' => $subscription->canPublishMore($publishedCount),
            // rétro-compat
            'isPremium' => in_array($subscription->getPlan(), ['starter', 'pro']),
        ]);
    }

    #[Route('/subscription/upgrade', name: 'app_owner_subscription_upgrade', methods: ['POST'])]
    public function upgradeSubscription(Request $request, EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $subscription = $em->getRepository(Subscription::class)->findOneBy(['proprietaire' => $user]);

        if (!$subscription) {
            $subscription = new Subscription();
            $subscription->setProprietaire($user);
            $em->persist($subscription);
        }

        $plan = $request->request->get('plan', 'starter');
        if (!in_array($plan, ['starter', 'pro'])) {
            $plan = 'starter';
        }

        // Vérifier qu'on ne downgrade pas
        $order = ['free' => 0, 'starter' => 1, 'pro' => 2];
        if (($order[$plan] ?? 0) <= ($order[$subscription->getPlan()] ?? 0)) {
            $this->addFlash('warning', 'Vous êtes déjà sur ce plan ou un plan supérieur.');
            return $this->redirectToRoute('app_owner_subscription');
        }

        $months = max(1, (int) $request->request->get('months', 1));
        // Réductions sur longue durée
        $months = in_array($months, [1, 3, 6, 12]) ? $months : 1;

        $now   = new \DateTimeImmutable();
        $start = $subscription->getDateExpiration() && $subscription->getDateExpiration() > $now
            ? $subscription->getDateExpiration()
            : $now;

        $subscription->setPlan($plan)
            ->setStatut(Subscription::STATUS_ACTIVE)
            ->setDateDebut($now)
            ->setDateExpiration($start->modify('+' . $months . ' months'))
            ->setUpdatedAt($now);

        $em->flush();

        $this->addFlash('success', sprintf(
            '🎉 Félicitations ! Plan %s activé pour %d mois.',
            $subscription->getPlanLabel(),
            $months
        ));
        return $this->redirectToRoute('app_owner_subscription');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€ NOTIFICATIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/notifications', name: 'app_owner_notifications')]
    public function notifications(NotificationRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $notifications = $repo->findByDestinataire($user->getId());

        return $this->render('owner/notifications.html.twig', [
            'notifications' => $notifications,
        ]);
    }

    #[Route('/notifications/{id}/read', name: 'app_owner_notification_read', methods: ['POST'])]
    public function markNotificationAsRead(Notification $notif, EntityManagerInterface $em): Response
    {
        $this->denyAccessUnlessGranted('view', $notif);

        $notif->setLue(true);
        $em->flush();

        return $this->json(['success' => true]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€ PARTENAIRES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/partners', name: 'app_owner_partners')]
    public function partners(PartnerRepository $repo): Response
    {
        $partners = $repo->findByStatut('active');

        return $this->render('owner/partners.html.twig', [
            'partners' => $partners,
        ]);
    }

    #[Route('/partners/{id}/contact', name: 'app_owner_partner_contact', methods: ['POST'])]
    public function contactPartner(Request $request, EntityManagerInterface $em): Response
    {
        $email = $request->request->get('email');
        $message = $request->request->get('message');

        // Send email or save message (implement email service)
        $this->addFlash('success', 'Message envoyé au partenaire !');

        return $this->redirectToRoute('app_owner_partners');
    }

    #[Route('/messages', name: 'app_owner_messages')]
    public function messages(EntityManagerInterface $em, MessageRepository $messageRepo): Response
    {
        /** @var User $user */
        $user     = $this->getUser();
        $userRepo = $em->getRepository(User::class);

        // Conversations existantes — propriétaire ↔ admin uniquement
        $allMessages = $messageRepo->createQueryBuilder('m')
            ->where('(m.sender = :user AND m.deletedForSender = false)')
            ->orWhere('(m.receiver = :user AND m.deletedForReceiver = false)')
            ->setParameter('user', $user)
            ->orderBy('m.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        $convMap = [];
        foreach ($allMessages as $msg) {
            $isMine  = $msg->getSender()->getId() === $user->getId();
            $partner = $isMine ? $msg->getReceiver() : $msg->getSender();
            if (!\in_array('ROLE_ADMIN', $partner->getRoles())) {
                continue;
            }
            $pid = $partner->getId();
            if (!isset($convMap[$pid])) {
                $convMap[$pid] = ['partner' => $partner, 'lastMessage' => $msg, 'unreadCount' => 0];
            }
            if (!$isMine && $msg->getStatus() !== \App\Entity\Message::STATUS_READ) {
                $convMap[$pid]['unreadCount']++;
            }
        }

        // Admins disponibles comme nouveaux contacts
        $defaultContacts = [];
        foreach ($userRepo->findWithRole('ROLE_ADMIN') as $admin) {
            if (!isset($convMap[$admin->getId()])) {
                $defaultContacts[] = $admin;
            }
        }

        return $this->render('owner/messages.html.twig', [
            'conversations'   => array_values($convMap),
            'defaultContacts' => $defaultContacts,
        ]);
    }

    #[Route('/messages/{receiverId}', name: 'app_owner_messages_chat')]
    public function chat(int $receiverId, EntityManagerInterface $em, Request $request, NotificationService $notificationService): Response
    {
        /** @var User $user */
        $user        = $this->getUser();
        $userRepo    = $em->getRepository(User::class);
        $receiver    = $userRepo->find($receiverId);
        $messageRepo = $em->getRepository(\App\Entity\Message::class);

        if (!$receiver) throw $this->createNotFoundException();

        // Propriétaire ↔ Admin uniquement
        if (!\in_array('ROLE_ADMIN', $receiver->getRoles())) {
            $this->addFlash('danger', 'Vous pouvez uniquement échanger avec l\'administration HomeConnect.');
            return $this->redirectToRoute('app_owner_messages');
        }

        if ($request->isMethod('POST')) {
            $content = trim($request->request->get('content', ''));
            if ($content) {
                $msg = new \App\Entity\Message();
                $msg->setSender($user)->setReceiver($receiver)->setContent($content);
                $msg->setStatus(\App\Entity\Message::STATUS_SENT);
                $em->persist($msg);
                $em->flush();

                $notificationService->notifyAndFlush(
                    $receiver,
                    'message_received',
                    sprintf('%s vous a envoyé un message : "%s"', $user->getFullName(), mb_substr($content, 0, 80)),
                    'Nouveau message',
                    $msg->getId(),
                    'message'
                );

                if ($request->isXmlHttpRequest() || $request->headers->get('X-Requested-With') === 'XMLHttpRequest') {
                    return new JsonResponse([
                        'success' => true,
                        'message' => [
                            'id'        => $msg->getId(),
                            'content'   => $msg->getContent(),
                            'createdAt' => $msg->getCreatedAt()->format('H:i'),
                            'isMe'      => true,
                        ],
                    ]);
                }

                return $this->redirectToRoute('app_owner_messages_chat', ['receiverId' => $receiverId]);
            }
        }

        $messages = $messageRepo->findConversation($user->getId(), $receiverId);

        // Marquer les reçus comme lus
        foreach ($messages as $msg) {
            if ($msg->getReceiver()?->getId() === $user->getId()
                && $msg->getStatus() !== \App\Entity\Message::STATUS_READ) {
                $msg->setStatus(\App\Entity\Message::STATUS_READ);
                $msg->setReadAt(new \DateTimeImmutable());
            }
        }
        $em->flush();

        // Sidebar : admin + locataires
        $allMsgs = $messageRepo->createQueryBuilder('m')
            ->where('(m.sender = :u AND m.deletedForSender = false)')
            ->orWhere('(m.receiver = :u AND m.deletedForReceiver = false)')
            ->setParameter('u', $user)
            ->orderBy('m.createdAt', 'DESC')
            ->getQuery()->getResult();

        $convMap = [];
        foreach ($allMsgs as $m) {
            $mine    = $m->getSender()->getId() === $user->getId();
            $partner = $mine ? $m->getReceiver() : $m->getSender();
            if (!\in_array('ROLE_ADMIN', $partner->getRoles())) { continue; }
            $pid = $partner->getId();
            if (!isset($convMap[$pid])) {
                $convMap[$pid] = ['partner' => $partner, 'lastMessage' => $m, 'unreadCount' => 0];
            }
            if (!$mine && $m->getStatus() !== \App\Entity\Message::STATUS_READ) {
                $convMap[$pid]['unreadCount']++;
            }
        }

        $defaultContacts = [];
        foreach ($userRepo->findWithRole('ROLE_ADMIN') as $admin) {
            if (!isset($convMap[$admin->getId()])) { $defaultContacts[] = $admin; }
        }

        return $this->render('owner/messages.html.twig', [
            'activeContact'   => $receiver,
            'messages'        => $messages,
            'conversations'   => array_values($convMap),
            'defaultContacts' => $defaultContacts,
        ]);
    }

    #[Route('/messages/upload/{receiverId}', name: 'app_owner_messages_upload', methods: ['POST'])]
    public function upload(int $receiverId, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $receiver = $em->getRepository(User::class)->find($receiverId);
        if (!$receiver) return new JsonResponse(['error' => 'User not found'], 404);

        $file = $request->files->get('file');
        $type = $request->request->get('type', 'image'); 
        $stickerUrl = $request->request->get('sticker_url');
        
        if (!$file && !$stickerUrl) return new JsonResponse(['error' => 'No file provided'], 400);

        $attachmentUrl = $stickerUrl;
        if ($file) {
            $uploadDir = $this->getParameter('kernel.project_dir') . '/public/uploads/messages';
            if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);
            $filename = uniqid() . '.' . $file->guessExtension();
            $file->move($uploadDir, $filename);
            $attachmentUrl = '/uploads/messages/' . $filename;
        }

        $msg = new \App\Entity\Message();
        $msg->setSender($user)->setReceiver($receiver)->setType($type);
        $msg->setAttachmentUrl($attachmentUrl);
        $msg->setContent($stickerUrl ? 'Sticker' : ($type === 'audio' ? 'Message vocal' : ($type === 'image' ? 'Image' : 'Fichier')));
        
        $em->persist($msg);
        $em->flush();

        return new JsonResponse(['success' => true, 'url' => $msg->getAttachmentUrl()]);
    }

    #[Route('/contracts', name: 'app_owner_contracts')]
    public function contracts(EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $rentals = $em->getRepository(Rental::class)->findByProprietaire($user);

        return $this->render('owner/contracts.html.twig', [
            'rentals' => $rentals,
        ]);
    }

    #[Route('/rentals/{id}/remind', name: 'app_owner_rental_remind', methods: ['POST'])]
    public function remindLocataire(Rental $rental, \App\Service\ReminderService $reminderService, EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        // Vérifier la propriété
        if ($rental->getProperty()->getProprietaire() !== $user) {
            throw $this->createAccessDeniedException("Vous n'êtes pas autorisé à relancer ce locataire.");
        }

        if ($rental->isPaid()) {
            $this->addFlash("info", "Le loyer pour cette location est déjà à jour.");
            return $this->redirectToRoute('app_owner_contracts');
        }

        // Utiliser le service pour envoyer la relance
        // On pourrait ajouter une notification spécifique pour dire que c'est une relance MANUELLE du bailleur
        $notif = new Notification();
        $notif->setDestinataire($rental->getLocataire())
            ->setType('manual_reminder')
            ->setMessage('ðŸ”” Rappel urgent de votre bailleur (' . $user->getFullName() . ') : Votre loyer pour ' . $rental->getProperty()->getTitle() . ' est attendu.')
            ->setLien('/tenant/contracts');
        
        $em->persist($notif);
        $em->flush();

        // On peut aussi réutiliser le service d'email
        // $reminderService->sendEmailReminder($rental); // On pourrait rendre cette méthode publique

        $this->addFlash('success', 'Relance envoyée avec succès au locataire ' . $rental->getLocataire()->getFullName() . '.');
        return $this->redirectToRoute('app_owner_contracts');
    }

    #[Route('/profile', name: 'app_owner_profile', methods: ['GET', 'POST'])]
    public function profile(Request $request, EntityManagerInterface $em, ReviewRepository $reviewRepo): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($request->isMethod('POST')) {
            $prenom    = trim($request->request->get('prenom', ''));
            $nom       = trim($request->request->get('nom', ''));
            $telephone = trim($request->request->get('telephone', ''));
            $ville     = trim($request->request->get('ville', ''));

            if ($prenom && $nom) {
                $user->setPrenom($prenom);
                $user->setNom($nom);
                $user->setTelephone($telephone ?: null);
                $user->setVille($ville ?: null);
                $em->flush();
                $this->addFlash('success', 'Profil mis à jour avec succès !');
            } else {
                $this->addFlash('danger', 'Le prénom et le nom sont obligatoires.');
            }
            return $this->redirectToRoute('app_owner_profile');
        }

        $avgRating    = $reviewRepo->calculateAverageRating($user->getId());
        $totalReviews = $reviewRepo->countReviews($user->getId());
        $reviews      = $reviewRepo->findByTargetUser($user->getId());

        return $this->render('owner/profile.html.twig', [
            'user'          => $user,
            'averageRating' => $avgRating,
            'totalReviews'  => $totalReviews,
            'reviews'       => $reviews,
        ]);
    }

    #[Route('/profile/password', name: 'app_owner_change_password', methods: ['POST'])]
    public function changePassword(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $passwordHasher): Response
    {
        /** @var User $user */
        $user            = $this->getUser();
        $currentPassword = $request->request->get('current_password', '');
        $newPassword     = $request->request->get('new_password', '');
        $confirmPassword = $request->request->get('confirm_password', '');

        if (!$passwordHasher->isPasswordValid($user, $currentPassword)) {
            $this->addFlash('danger', 'Mot de passe actuel incorrect.');
            return $this->redirectToRoute('app_owner_profile');
        }
        if (\strlen($newPassword) < 8) {
            $this->addFlash('danger', 'Le nouveau mot de passe doit contenir au moins 8 caractères.');
            return $this->redirectToRoute('app_owner_profile');
        }
        if ($newPassword !== $confirmPassword) {
            $this->addFlash('danger', 'Les nouveaux mots de passe ne correspondent pas.');
            return $this->redirectToRoute('app_owner_profile');
        }

        $user->setPassword($passwordHasher->hashPassword($user, $newPassword));
        $em->flush();
        $this->addFlash('success', 'Mot de passe modifié avec succès !');
        return $this->redirectToRoute('app_owner_profile');
    }

    #[Route('/profile/delete', name: 'app_owner_delete_account', methods: ['POST'])]
    public function deleteAccount(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $passwordHasher): Response
    {
        /** @var User $user */
        $user     = $this->getUser();
        $password = $request->request->get('delete_password', '');

        if (!$passwordHasher->isPasswordValid($user, $password)) {
            $this->addFlash('danger', 'Mot de passe incorrect. La suppression a été annulée.');
            return $this->redirectToRoute('app_owner_profile');
        }

        $em->remove($user);
        $em->flush();
        $request->getSession()->invalidate();
        return $this->redirect('/');
    }

    #[Route('/statistics', name: 'app_owner_statistics')]
    public function statistics(PropertyRepository $propertyRepo, ApplicationRepository $appRepo): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        $properties   = $propertyRepo->findBy(['proprietaire' => $user]);
        $totalViews   = array_sum(array_map(fn($p) => $p->getViews(), $properties));
        $applications = $appRepo->findBy(['property' => $properties]);
        $totalApps    = \count($applications);
        $conversionRate = $totalViews > 0 ? round($totalApps / $totalViews * 100, 1) : 0;

        // Revenus (sum of monthly prices of active rentals)
        $totalRevenue = 0;
        foreach ($properties as $property) {
            foreach ($property->getRentals() as $rental) {
                if ($rental->getStatus() === 'active') {
                    $totalRevenue += $rental->getMonthlyPrice();
                }
            }
        }

        return $this->render('owner/statistics.html.twig', [
            'properties'     => $properties,
            'totalViews'     => $totalViews,
            'totalApps'      => $totalApps,
            'conversionRate' => $conversionRate,
            'totalRevenue'   => $totalRevenue,
        ]);
    }

    #[Route('/support', name: 'app_owner_support', methods: ['GET', 'POST'])]
    public function support(Request $request, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($request->isMethod('POST')) {
            $subject = trim($request->request->get('subject', ''));
            $message = trim($request->request->get('message', ''));
            $type    = $request->request->get('type', 'general');

            if ($subject && $message) {
                $ticket = new SupportTicket();
                $ticket->setUser($user);
                $ticket->setType($type);
                $ticket->setSubject($subject);
                $ticket->setMessage($message);
                $ticket->setStatus('ouvert');
                $em->persist($ticket);
                $em->flush();

                $notificationService->notifyAdmins(
                    'support_ticket',
                    \sprintf('Nouveau ticket propriétaire de %s : "%s"', $user->getFullName(), $subject),
                    'Nouveau ticket support',
                    $ticket->getId(),
                    'support'
                );

                $this->addFlash('success', 'Votre demande a bien été envoyée. Notre équipe vous répondra sous 24h.');
                return $this->redirectToRoute('app_owner_support');
            }
            $this->addFlash('danger', 'Veuillez remplir le sujet et le message.');
        }

        return $this->render('owner/support.html.twig');
    }

    // ──────────── KYC PROPRIÉTAIRE ────────────────────────────────────────

    #[Route('/kyc', name: 'app_owner_kyc', methods: ['GET', 'POST'])]
    public function kyc(Request $request, EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($request->isMethod('POST')) {
            $uploadDir = $this->getParameter('kernel.project_dir') . '/public/uploads/kyc/' . $user->getId();
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            // ── Pièce d'identité ──────────────────────────────────────────
            $identiteType = $request->request->get('kyc_identite_type');
            if ($identiteType) {
                $user->setKycIdentiteType($identiteType);
            }
            $identiteFile = $request->files->get('kyc_identite_file');
            if ($identiteFile) {
                $filename = 'identite_' . uniqid() . '.' . $identiteFile->guessExtension();
                $identiteFile->move($uploadDir, $filename);
                $user->setKycIdentiteUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            // ── Justificatif de domicile ──────────────────────────────────
            $domicileType = $request->request->get('kyc_domicile_type');
            if ($domicileType) {
                $user->setKycDomicileType($domicileType);
            }
            $domicileFile = $request->files->get('kyc_domicile_file');
            if ($domicileFile) {
                $filename = 'domicile_' . uniqid() . '.' . $domicileFile->guessExtension();
                $domicileFile->move($uploadDir, $filename);
                $user->setKycDomicileUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            // ── Justificatif de propriété ─────────────────────────────────
            $proprieteType = $request->request->get('kyc_propriete_type');
            if ($proprieteType) {
                $user->setKycProprieteType($proprieteType);
            }
            $proprieteFile = $request->files->get('kyc_propriete_file');
            if ($proprieteFile) {
                $filename = 'propriete_' . uniqid() . '.' . $proprieteFile->guessExtension();
                $proprieteFile->move($uploadDir, $filename);
                $user->setKycProprieteUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            // ── Documents optionnels ──────────────────────────────────────
            $ribFile = $request->files->get('kyc_rib_file');
            if ($ribFile) {
                $filename = 'rib_' . uniqid() . '.' . $ribFile->guessExtension();
                $ribFile->move($uploadDir, $filename);
                $user->setKycRibUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            $assuranceFile = $request->files->get('kyc_assurance_file');
            if ($assuranceFile) {
                $filename = 'assurance_' . uniqid() . '.' . $assuranceFile->guessExtension();
                $assuranceFile->move($uploadDir, $filename);
                $user->setKycAssuranceUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            $avisFile = $request->files->get('kyc_avis_imposition_file');
            if ($avisFile) {
                $filename = 'avis_' . uniqid() . '.' . $avisFile->guessExtension();
                $avisFile->move($uploadDir, $filename);
                $user->setKycAvisImpositionUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            // ── Cas particulier ───────────────────────────────────────────
            $casParticulier = $request->request->get('kyc_cas_particulier');
            if ($casParticulier) {
                $user->setKycCasParticulier($casParticulier);
            }
            $casFile = $request->files->get('kyc_cas_particulier_file');
            if ($casFile) {
                $filename = 'cas_' . uniqid() . '.' . $casFile->guessExtension();
                $casFile->move($uploadDir, $filename);
                $user->setKycCasParticulierUrl('/uploads/kyc/' . $user->getId() . '/' . $filename);
            }

            // Vérifier que les 3 documents obligatoires sont présents
            if (!$user->hasKycDocuments()) {
                $this->addFlash('error', 'Les 3 documents obligatoires sont requis : pièce d\'identité, justificatif de domicile et justificatif de propriété.');
                return $this->redirectToRoute('app_owner_kyc');
            }

            // Mettre le statut en attente
            $user->setKycStatus('pending');
            $user->setKycSubmittedAt(new \DateTimeImmutable());
            $user->setVerificationStatus('en_attente');

            $em->flush();

            $this->addFlash('success', 'Vos documents KYC ont été soumis avec succès. Validation sous 24-48h.');
            return $this->redirectToRoute('app_owner_kyc');
        }

        return $this->render('owner/kyc.html.twig', [
            'user' => $user,
        ]);
    }
}

