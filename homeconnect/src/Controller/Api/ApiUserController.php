<?php

namespace App\Controller\Api;

use App\Entity\Log;
use App\Entity\User;
use App\Entity\Property;
use App\Entity\Application;
use App\Entity\Message;
use App\Entity\Notification;
use App\Entity\Visite;
use App\Entity\SupportTicket;
use App\Entity\PropertyComment;
use App\Entity\PropertyInteraction;
use App\Entity\Rental;
use App\Entity\Report;
use App\Entity\Review;
use App\Entity\Subscription;
use App\Entity\Favorite;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Serializer\SerializerInterface;
use Symfony\Component\Validator\Validator\ValidatorInterface;

#[Route('/api', name: 'api_user_')]
class ApiUserController extends AbstractController
{
    #[Route('/health', name: 'api_health', methods: ['GET'])]
    public function health(): JsonResponse
    {
        return $this->json(['status' => 'ok', 'timestamp' => time()]);
    }

    #[Route('/register', name: 'register', methods: ['POST'])]
    public function register(
        Request $request,
        UserPasswordHasherInterface $passwordHasher,
        EntityManagerInterface $entityManager,
        SerializerInterface $serializer,
        ValidatorInterface $validator
    ): JsonResponse {
        $data = $request->getContent();
        $user = $serializer->deserialize($data, User::class, 'json');

        $errors = $validator->validate($user);
        if (count($errors) > 0) {
            return $this->json($errors, Response::HTTP_BAD_REQUEST);
        }

        // Handle password hashing manually since deserialize doesn't know about it
        $decodedData = json_decode($data, true);
        if (isset($decodedData['password'])) {
            $user->setPassword($passwordHasher->hashPassword($user, $decodedData['password']));
        }

        // Map Flutter app fields to Symfony entity fields
        if (!empty($decodedData['firstname']) || !empty($decodedData['prenom'])) {
            $user->setPrenom($decodedData['firstname'] ?? $decodedData['prenom']);
        }
        if (!empty($decodedData['lastname']) || !empty($decodedData['nom'])) {
            $user->setNom($decodedData['lastname'] ?? $decodedData['nom']);
        }
        if (!empty($decodedData['role'])) {
            $roleStr = strtoupper($decodedData['role']);
            if ($roleStr === 'PROPRIETAIRE' || $roleStr === 'OWNER' || $roleStr === 'LANDLORD') {
                $user->setRoles(["ROLE_PROPRIETAIRE"]);
            } elseif ($roleStr === 'ADMIN') {
                $user->setRoles(["ROLE_ADMIN"]);
            } else {
                $user->setRoles(["ROLE_LOCATAIRE"]);
            }
        }

        // Prevent Not Null constraint violations
        if (!$user->getPrenom()) {
            $user->setPrenom('Inconnu');
        }
        if (!$user->getNom()) {
            $user->setNom('Inconnu');
        }
        if (!$user->getRoles() || empty($user->getRoles())) {
            $user->setRoles(['ROLE_LOCATAIRE']);
        }

        $user->setIsVerified(true);
        $user->setKycStatus($user->getRoles()[0] === 'ROLE_PROPRIETAIRE' ? 'en_attente' : 'approved');

        $entityManager->persist($user);
        $entityManager->flush();

        return $this->json(['message' => 'User registered successfully'], Response::HTTP_CREATED);
    }

    #[Route('/me', name: 'me', methods: ['GET'])]
    #[Route('/user/profile', name: 'user_profile', methods: ['GET'])]
    public function me(SerializerInterface $serializer): JsonResponse
    {
        $user = $this->getUser();
        if (!$user) {
            return $this->json(['message' => 'Not authenticated'], Response::HTTP_UNAUTHORIZED);
        }

        $json = $serializer->serialize($user, 'json', ['groups' => 'property:read']);

        return new JsonResponse($json, Response::HTTP_OK, [], true);
    }

    #[Route('/import-bulk', name: 'import_bulk', methods: ['POST'])]
    public function importBulk(
        Request $request,
        EntityManagerInterface $entityManager,
        UserPasswordHasherInterface $passwordHasher
    ): JsonResponse {
        $data = json_decode($request->getContent(), true);
        file_put_contents($this->getParameter('kernel.project_dir') . '/var/log/sync_debug.json', $request->getContent());
        if (!$data) {
            return $this->json(['error' => 'Invalid JSON'], Response::HTTP_BAD_REQUEST);
        }

        $importLog = [];

        // Import Users
        if (isset($data['users'])) {
            foreach ($data['users'] as $userData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $userData['email']]);
                if (!$user) {
                    $user = new User();
                    $user->setEmail($userData['email']);
                    $user->setPrenom($userData['prenom'] ?? '');
                    $user->setNom($userData['nom'] ?? '');
                    $user->setTelephone($userData['telephone'] ?? null);
                    $user->setRoles([isset($userData['role']) ? 'ROLE_' . strtoupper($userData['role']) : 'ROLE_USER']);
                    $user->setPassword($passwordHasher->hashPassword($user, $userData['password'] ?? 'password123'));
                    $entityManager->persist($user);
                    $importLog[] = "User " . $user->getEmail() . " created.";
                }

                // Update KYC documents if present
                if (isset($userData['kycDocuments'])) {
                    $docs = is_string($userData['kycDocuments']) ? json_decode($userData['kycDocuments'], true) : $userData['kycDocuments'];
                    if (is_array($docs)) {
                        $user->setKycDocuments(json_encode($docs));
                        $user->setIsVerified(($userData['isVerified'] ?? 0) == 1);
                        if (isset($userData['verificationStatus'])) {
                            $user->setVerificationStatus($userData['verificationStatus']);
                        }
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Properties
        if (isset($data['properties'])) {
            foreach ($data['properties'] as $propData) {
                // Vérifier si le bien existe déjà par son titre et son propriétaire
                $ownerEmail = $propData['proprietaireEmail'] ?? 'admin@homeconnect.com';
                $owner = $entityManager->getRepository(User::class)->findOneBy(['email' => $ownerEmail]);
                
                $existingProperty = null;
                if ($owner) {
                    $existingProperty = $entityManager->getRepository(Property::class)->findOneBy([
                        'title' => $propData['titre'] ?? 'No Title',
                        'proprietaire' => $owner
                    ]);
                }

                if (!$existingProperty) {
                    $property = new Property();
                    $property->setTitle($propData['titre'] ?? 'No Title');
                    $property->setDescription($propData['description'] ?? '');
                    $property->setAddress($propData['lieu'] ?? '');
                    $property->setPricePerMonth((string)($propData['prix'] ?? '0'));
                    $property->setRooms((int)($propData['pieces'] ?? 1));
                    $property->setBedrooms((int)($propData['nbChambres'] ?? 1));
                    $property->setSurface((float)($propData['superficie'] ?? 0));
                    
                    // S'assurer d'avoir un propriétaire valide (contrainte NOT NULL)
                    if (!$owner) {
                        $owner = $entityManager->getRepository(User::class)->findOneBy(['email' => 'admin@homeconnect.com']);
                        if (!$owner) {
                            // Si vraiment aucun admin, on prend le premier utilisateur trouvé ou on saute
                            $owner = $entityManager->getRepository(User::class)->findOneBy([]);
                        }
                    }

                    if ($owner) {
                        $property->setProprietaire($owner);
                        $property->setStatut(Property::STATUS_ACTIVE);
                        
                        // Fusionner l'image principale et les images additionnelles
                        $allImages = [];
                        if (!empty($propData['imageUrl'])) {
                            $allImages[] = $propData['imageUrl'];
                        }
                        if (!empty($propData['additionalImages']) && is_array($propData['additionalImages'])) {
                            $allImages = array_merge($allImages, $propData['additionalImages']);
                        }
                        $property->setImages(array_unique($allImages));
                        
                        // Champs techniques additionnels
                        $property->setType($propData['type'] ?? 'Appartement');
                        $property->setNbSalons((int)($propData['nbSalons'] ?? 0));
                        $property->setNbToilettes((int)($propData['nbToilettes'] ?? 0));
                        $property->setNbSallesDeBain((int)($propData['nbSallesDeBain'] ?? 0));
                        $property->setTypeCuisine($propData['typeCuisine'] ?? 'Non équipée');
                        $property->setHasParking((bool)($propData['hasParking'] ?? false));
                        $property->setParkingPlaces((int)($propData['parkingPlaces'] ?? 0));
                        
                        $entityManager->persist($property);
                        $importLog[] = "Property " . $property->getTitle() . " imported with images for " . $owner->getEmail();
                    } else {
                        $importLog[] = "Property " . ($propData['titre'] ?? 'No Title') . " skipped: No owner found.";
                    }
                } else {
                    error_log("Property " . ($propData['titre'] ?? 'No Title') . " already exists for owner " . $ownerEmail);
                    $importLog[] = "Property " . ($propData['titre'] ?? 'No Title') . " already exists, skipping.";
                }
            }
            $entityManager->flush();
        }
        // Import Applications & Visites
        if (isset($data['applications'])) {
            foreach ($data['applications'] as $appData) {
                $locataire = $entityManager->getRepository(User::class)->findOneBy(['email' => $appData['locataireEmail'] ?? '']);
                $property = $entityManager->getRepository(Property::class)->findOneBy(['title' => $appData['bien'] ?? '']);

                if ($locataire && $property) {
                    $createdAt = isset($appData['date']) ? new \DateTime($appData['date']) : null;
                    $existingApp = $entityManager->getRepository(Application::class)->findOneBy([
                        'locataire' => $locataire,
                        'property' => $property,
                        'createdAt' => $createdAt
                    ]);

                    $app = $existingApp;
                    if (!$app) {
                        $app = new Application();
                        $app->setLocataire($locataire)
                            ->setProperty($property)
                            ->setDateDebut(isset($appData['dateDebut']) ? new \DateTime($appData['dateDebut']) : new \DateTime())
                            ->setDateFin(isset($appData['dateFin']) ? new \DateTime($appData['dateFin']) : (new \DateTime())->modify('+1 year'))
                            ->setCreatedAt($createdAt ?? new \DateTime());
                        $entityManager->persist($app);
                        $importLog[] = "Application for " . $property->getTitle() . " created.";
                    }

                    // Mise à jour du statut
                    $app->setStatut($appData['statut'] ?? 'pending');
                    $app->setMessage($appData['message'] ?? $app->getMessage());

                    // Gestion de la Visite
                    if (!empty($appData['visiteDate'])) {
                        $visiteDateStr = $appData['visiteDate'] . ' ' . ($appData['visiteHeure'] ?? '00:00');
                        $visiteDateTime = new \DateTime($visiteDateStr);
                        
                        $visite = $entityManager->getRepository(Visite::class)->findOneBy(['application' => $app]);
                        if (!$visite) {
                            $visite = new Visite();
                            $visite->setApplication($app);
                            $entityManager->persist($visite);
                        }
                        $visite->setDateHeureDebut($visiteDateTime);
                        $visite->setDateHeureFin((clone $visiteDateTime)->modify('+1 hour'));
                        $visite->setStatut($app->getStatut() === 'acceptee' ? 'planifiee' : 'annulee');
                        $importLog[] = "Visit for " . $property->getTitle() . " updated/created.";
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Support Tickets
        if (isset($data['tickets'])) {
            foreach ($data['tickets'] as $ticketData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $ticketData['userEmail'] ?? '']);
                if ($user) {
                    $createdAt = isset($ticketData['created_at']) ? new \DateTime($ticketData['created_at']) : new \DateTime();
                    $existingTicket = $entityManager->getRepository(SupportTicket::class)->findOneBy([
                        'user' => $user,
                        'createdAt' => $createdAt
                    ]);

                    if (!$existingTicket) {
                        $ticket = new SupportTicket();
                        $ticket->setUser($user)
                            ->setType($ticketData['type'] ?? 'general')
                            ->setSubject($ticketData['subject'] ?? 'No Subject')
                            ->setMessage($ticketData['message'] ?? '')
                            ->setStatus($ticketData['status'] ?? 'ouvert')
                            ->setCreatedAt($createdAt);
                        $entityManager->persist($ticket);
                        $importLog[] = "Support Ticket '" . $ticket->getSubject() . "' imported.";
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Messages
        if (isset($data['messages'])) {
            foreach ($data['messages'] as $msgData) {
                $sender = $entityManager->getRepository(User::class)->findOneBy(['email' => $msgData['senderEmail'] ?? '']);
                $receiver = $entityManager->getRepository(User::class)->findOneBy(['email' => $msgData['receiverEmail'] ?? '']);

                if ($sender && $receiver) {
                    $msg = new Message();
                    $msg->setSender($sender)
                        ->setReceiver($receiver)
                        ->setContent($msgData['content'] ?? '')
                        ->setIsRead($msgData['isRead'] ?? false)
                        ->setCreatedAt(isset($msgData['createdAt']) ? new \DateTimeImmutable($msgData['createdAt']) : new \DateTimeImmutable());
                    $entityManager->persist($msg);
                }
            }
            $entityManager->flush();
        }

        // Import Favorites
        if (isset($data['favorites'])) {
            foreach ($data['favorites'] as $favData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $favData['locataireEmail'] ?? '']);
                $property = $entityManager->getRepository(Property::class)->findOneBy(['title' => $favData['propertyTitle'] ?? '']);
                if ($user && $property) {
                    $existingFav = $entityManager->getRepository(Favorite::class)->findOneBy(['locataire' => $user, 'property' => $property]);
                    if (!$existingFav) {
                        $fav = new Favorite();
                        $fav->setLocataire($user)->setProperty($property);
                        $entityManager->persist($fav);
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Property Comments
        if (isset($data['comments'])) {
            foreach ($data['comments'] as $commData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $commData['userEmail'] ?? '']);
                $property = $entityManager->getRepository(Property::class)->findOneBy(['title' => $commData['propertyTitle'] ?? '']);
                if ($user && $property) {
                    $createdAt = isset($commData['createdAt']) ? new \DateTime($commData['createdAt']) : new \DateTime();
                    $existingComm = $entityManager->getRepository(PropertyComment::class)->findOneBy([
                        'author' => $user,
                        'property' => $property,
                        'createdAt' => $createdAt
                    ]);
                    if (!$existingComm) {
                        $comm = new PropertyComment();
                        $comm->setAuthor($user)
                             ->setProperty($property)
                             ->setContent($commData['text'] ?? '')
                             ->setCreatedAt(isset($commData['createdAt']) ? new \DateTimeImmutable($commData['createdAt']) : new \DateTimeImmutable());
                        $entityManager->persist($comm);
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Property Interactions
        if (isset($data['property_interactions'])) {
            foreach ($data['property_interactions'] as $intData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $intData['userEmail'] ?? '']);
                $property = $entityManager->getRepository(Property::class)->findOneBy(['title' => $intData['propertyTitle'] ?? '']);
                if ($user && $property) {
                    $existingInt = $entityManager->getRepository(PropertyInteraction::class)->findOneBy([
                        'user' => $user,
                        'property' => $property,
                        'type' => $intData['type']
                    ]);
                    if (!$existingInt) {
                        $inter = new PropertyInteraction();
                        $inter->setUser($user)
                              ->setProperty($property)
                              ->setType($intData['type'] ?? 'like')
                              ->setCreatedAt(isset($intData['createdAt']) ? new \DateTimeImmutable($intData['createdAt']) : new \DateTimeImmutable());
                        $entityManager->persist($inter);
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Notifications
        if (isset($data['notifications'])) {
            foreach ($data['notifications'] as $notifData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $notifData['userEmail'] ?? '']);
                if ($user) {
                    $createdAt = isset($notifData['createdAt']) ? new \DateTime($notifData['createdAt']) : new \DateTime();
                    $existingNotif = $entityManager->getRepository(Notification::class)->findOneBy([
                        'destinataire' => $user,
                        'title' => $notifData['title'] ?? '',
                        'createdAt' => $createdAt
                    ]);
                    if (!$existingNotif) {
                        $notif = new Notification();
                        $notif->setDestinataire($user)
                              ->setTitle($notifData['title'] ?? '')
                              ->setMessage($notifData['message'] ?? $notifData['body'] ?? '')
                              ->setType($notifData['type'] ?? 'info')
                              ->setLue($notifData['isRead'] ?? $notifData['lue'] ?? false)
                              ->setCreatedAt($createdAt);
                        $entityManager->persist($notif);
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Reports
        if (isset($data['reports'])) {
            foreach ($data['reports'] as $reportData) {
                // On identifie l'utilisateur qui fait le signalement (signataire)
                $reporter = null;
                if (isset($reportData['userEmail'])) {
                    $reporter = $entityManager->getRepository(User::class)->findOneBy(['email' => $reportData['userEmail']]);
                }

                if ($reporter) {
                    $createdAt = isset($reportData['createdAt']) ? new \DateTimeImmutable($reportData['createdAt']) : new \DateTimeImmutable();
                    $existingReport = $entityManager->getRepository(Report::class)->findOneBy([
                        'signataire' => $reporter,
                        'motif' => $reportData['raison'],
                        'createdAt' => $createdAt
                    ]);

                    if (!$existingReport) {
                        $report = new Report();
                        $report->setSignataire($reporter)
                               ->setMotif($reportData['raison'] ?? 'Autre')
                               ->setType($reportData['type'] ?? 'property')
                               ->setStatut($reportData['status'] ?? 'open')
                               ->setPriorite($reportData['priorite'] ?? 'medium')
                               ->setCreatedAt($createdAt);
                        
                        // Si le signalement concerne une propriété
                        if (isset($reportData['propertyTitle'])) {
                            $property = $entityManager->getRepository(Property::class)->findOneBy(['title' => $reportData['propertyTitle']]);
                            if ($property) {
                                $report->setProperty($property);
                            }
                        }

                        $entityManager->persist($report);
                        $importLog[] = "Report from " . $reporter->getEmail() . " imported.";
                    }
                }
            }
            $entityManager->flush();
        }
        
        // Import Support Tickets
        if (isset($data['tickets'])) {
            foreach ($data['tickets'] as $ticketData) {
                $user = $entityManager->getRepository(User::class)->findOneBy(['email' => $ticketData['userEmail'] ?? $ticketData['email'] ?? '']);
                if ($user) {
                    $createdAt = isset($ticketData['created_at']) ? new \DateTimeImmutable($ticketData['created_at']) : new \DateTimeImmutable();
                    $existingTicket = $entityManager->getRepository(SupportTicket::class)->findOneBy([
                        'user' => $user,
                        'subject' => $ticketData['sujet'] ?? $ticketData['subject'] ?? '',
                        'createdAt' => $createdAt
                    ]);

                    if (!$existingTicket) {
                        $ticket = new SupportTicket();
                        $ticket->setUser($user)
                               ->setSubject($ticketData['sujet'] ?? $ticketData['subject'] ?? 'Aide')
                               ->setMessage($ticketData['message'] ?? '')
                               ->setStatus($ticketData['status'] ?? $ticketData['statut'] ?? 'ouvert')
                               ->setType($ticketData['type'] ?? 'aide')
                               ->setCreatedAt($createdAt);
                        $entityManager->persist($ticket);
                        $importLog[] = "Support ticket from " . $user->getEmail() . " imported.";
                    }
                }
            }
            $entityManager->flush();
        }

        // Import Reviews (Évaluations)
        if (isset($data['reviews'])) {
            foreach ($data['reviews'] as $reviewData) {
                $author = $entityManager->getRepository(User::class)->findOneBy(['email' => $reviewData['authorEmail'] ?? '']);
                
                // On cherche un Rental lié à cet auteur et cette propriété pour l'associer
                $rental = null;
                if (isset($reviewData['propertyTitle'])) {
                    $property = $entityManager->getRepository(Property::class)->findOneBy(['title' => $reviewData['propertyTitle']]);
                    if ($property && $author) {
                        $rental = $entityManager->getRepository(Rental::class)->findOneBy(['locataire' => $author, 'property' => $property]);
                    }
                }

                if ($author && $rental) {
                    $createdAt = isset($reviewData['createdAt']) ? new \DateTimeImmutable($reviewData['createdAt']) : new \DateTimeImmutable();
                    $existingReview = $entityManager->getRepository(Review::class)->findOneBy([
                        'author' => $author,
                        'rental' => $rental,
                        'createdAt' => $createdAt
                    ]);

                    if (!$existingReview) {
                        $review = new Review();
                        $review->setAuthor($author)
                               ->setRental($rental)
                               ->setRating((int)($reviewData['rating'] ?? 5))
                               ->setComment($reviewData['comment'] ?? '')
                               ->setType($reviewData['type'] ?? 'locataire')
                               ->setCreatedAt($createdAt);
                        
                        // Définir la cible (propriétaire du bien)
                        $review->setTargetUser($rental->getProperty()->getProprietaire());
                        
                        $entityManager->persist($review);
                        $importLog[] = "Review for " . $rental->getProperty()->getTitle() . " imported.";
                    }
                }
            }
            $entityManager->flush();
        }

        if (!empty($importLog)) {
            $log = new Log();
            $log->setAction("Synchronisation Mobile")
                ->setDetails(implode("\n", $importLog));
            $entityManager->persist($log);
            $entityManager->flush();
        }

        return $this->json([
            'message' => 'Import completed',
            'log' => $importLog
        ]);
    }

    #[Route('/export-bulk', name: 'api_export_bulk', methods: ['GET'])]
    public function exportBulk(
        EntityManagerInterface $entityManager,
        Request $request
    ): JsonResponse {
        $conn = $entityManager->getConnection();
        $baseUrl = $request->getSchemeAndHttpHost();

        // ── USERS ──────────────────────────────────────────────────────
        $users = $conn->fetchAllAssociative('SELECT id, email, roles, prenom, nom, telephone, is_verified as isVerified, verification_status as verificationStatus, subscription_type as subscriptionType, subscription_expiry as subscriptionExpiry, rating, review_count as reviewCount FROM `user`');
        foreach ($users as &$u) {
            $roles = json_decode($u['roles'] ?? '[]', true) ?: [];
            if (in_array('ROLE_ADMIN', $roles)) { $u['role'] = 'admin'; }
            elseif (in_array('ROLE_PROPRIETAIRE', $roles)) { $u['role'] = 'proprietaire'; }
            else { $u['role'] = 'locataire'; }
            $u['isVerified'] = $u['isVerified'] ? 1 : 0;
            $u['verificationStatus'] = $u['verificationStatus'] ?? 'certifie';
        }
        unset($u);

        // ── PROPERTIES ─────────────────────────────────────────────────
        $properties = $conn->fetchAllAssociative(
            'SELECT p.*, u.email as proprietaireEmail FROM property p LEFT JOIN `user` u ON p.proprietaire_id = u.id'
        );
        foreach ($properties as &$prop) {
            $prop['titre'] = $prop['title'] ?? '';
            $prop['prix'] = (float)($prop['price_per_month'] ?? 0);
            $prop['lieu'] = $prop['address'] ?? '';
            $prop['pieces'] = (int)($prop['rooms'] ?? 1);
            $prop['superficie'] = (float)($prop['surface'] ?? 0);
            $images = json_decode($prop['images'] ?? '[]', true) ?: [];
            foreach ($images as &$img) {
                if ($img && !str_starts_with($img, 'http')) { $img = $baseUrl . $img; }
            }
            unset($img);
            $prop['imageUrl'] = !empty($images) ? $images[0] : null;
            $prop['additionalImages'] = count($images) > 1 ? array_slice($images, 1) : [];
            $prop['images'] = $images;
        }
        unset($prop);

        // ── APPLICATIONS ────────────────────────────────────────────────
        $applications = $conn->fetchAllAssociative(
            'SELECT a.id, a.statut, a.message, a.created_at as date,
                    u.email as locataireEmail, u.id as locataireId,
                    p.title as bien, p.id as propertyId
             FROM `application` a
             LEFT JOIN `user` u ON a.locataire_id = u.id
             LEFT JOIN property p ON a.property_id = p.id'
        );
        // Ajouter les visites
        $visites = $conn->fetchAllAssociative(
            'SELECT v.application_id, v.date_heure_debut FROM visite v'
        );
        $visiteMap = [];
        foreach ($visites as $v) {
            $dt = new \DateTime($v['date_heure_debut']);
            $visiteMap[(int)$v['application_id']] = [
                'visiteDate' => $dt->format('Y-m-d'),
                'visiteHeure' => $dt->format('H:i'),
            ];
        }
        foreach ($applications as &$app) {
            if (isset($visiteMap[(int)$app['id']])) {
                $app['visiteDate'] = $visiteMap[(int)$app['id']]['visiteDate'];
                $app['visiteHeure'] = $visiteMap[(int)$app['id']]['visiteHeure'];
            }
        }
        unset($app);

        // ── MESSAGES ───────────────────────────────────────────────────
        $messages = $conn->fetchAllAssociative(
            'SELECT m.id, m.content as text, m.is_read as isRead, m.created_at as timestamp,
                    s.email as senderEmail, s.id as senderId,
                    r.email as receiverEmail, r.id as receiverId
             FROM message m
             LEFT JOIN `user` s ON m.sender_id = s.id
             LEFT JOIN `user` r ON m.receiver_id = r.id'
        );

        // ── NOTIFICATIONS ───────────────────────────────────────────────
        $notifications = $conn->fetchAllAssociative(
            'SELECT n.id, n.title, n.message as body, n.type, n.lue as isRead, n.created_at as createdAt,
                    u.id as userId, u.email as userEmail
             FROM notification n LEFT JOIN `user` u ON n.destinataire_id = u.id'
        );

        // ── TICKETS ─────────────────────────────────────────────────────
        $tickets = $conn->fetchAllAssociative(
            'SELECT t.id, t.subject as sujet, t.message, t.status, t.type, t.created_at,
                    u.email as userEmail
             FROM support_ticket t LEFT JOIN `user` u ON t.user_id = u.id'
        );

        // ── FAVORITES ───────────────────────────────────────────────────
        $favorites = $conn->fetchAllAssociative(
            'SELECT f.id, u.email as locataireEmail, p.title as propertyTitle, p.id as propertyId
             FROM favorite f
             LEFT JOIN `user` u ON f.locataire_id = u.id
             LEFT JOIN property p ON f.property_id = p.id'
        );

        // ── COMMENTS ────────────────────────────────────────────────────
        $comments = $conn->fetchAllAssociative(
            'SELECT c.id, c.content as text, c.created_at as createdAt,
                    u.email as userEmail, CONCAT(u.prenom, " ", u.nom) as userName,
                    p.title as propertyTitle
             FROM property_comment c
             LEFT JOIN `user` u ON c.author_id = u.id
             LEFT JOIN property p ON c.property_id = p.id'
        );

        // ── INTERACTIONS ─────────────────────────────────────────────────
        $interactions = $conn->fetchAllAssociative(
            'SELECT i.id, i.type, i.created_at as createdAt,
                    u.email as userEmail,
                    p.title as propertyTitle
             FROM property_interaction i
             LEFT JOIN `user` u ON i.user_id = u.id
             LEFT JOIN property p ON i.property_id = p.id'
        );

        // ── RENTALS ──────────────────────────────────────────────────────
        $rentals = $conn->fetchAllAssociative(
            'SELECT r.id, r.start_date as startDate, r.end_date as endDate, r.monthly_price as monthlyPrice, r.status,
                    u.email as locataireEmail, u.id as locataireId,
                    p.title as propertyTitle, p.id as propertyId
             FROM rental r
             LEFT JOIN `user` u ON r.locataire_id = u.id
             LEFT JOIN property p ON r.property_id = p.id'
        );

        // ── SUBSCRIPTIONS ─────────────────────────────────────────────────
        $subscriptions = $conn->fetchAllAssociative('SELECT * FROM subscription');

        // ── REPORTS ───────────────────────────────────────────────────────
        $reports = $conn->fetchAllAssociative(
            'SELECT r.id, r.motif as raison, r.type, r.statut as status, r.created_at as createdAt,
                    u.email as userEmail,
                    p.title as propertyTitle
             FROM report r
             LEFT JOIN `user` u ON r.signataire_id = u.id
             LEFT JOIN property p ON r.property_id = p.id'
        );

        // ── REVIEWS ───────────────────────────────────────────────────────
        $reviews = $conn->fetchAllAssociative(
            'SELECT rev.id, rev.rating, rev.comment, rev.type, rev.created_at as createdAt,
                    u.email as authorEmail,
                    p.title as propertyTitle
             FROM review rev
             LEFT JOIN `user` u ON rev.author_id = u.id
             LEFT JOIN rental ren ON rev.rental_id = ren.id
             LEFT JOIN property p ON ren.property_id = p.id'
        );

        return $this->json([
            'users' => $users,
            'properties' => $properties,
            'applications' => $applications,
            'messages' => $messages,
            'notifications' => $notifications,
            'visites' => $visites,
            'tickets' => $tickets,
            'favorites' => $favorites,
            'comments' => $comments,
            'property_interactions' => $interactions,
            'rentals' => $rentals,
            'subscriptions' => $subscriptions,
            'reports' => $reports,
            'reviews' => $reviews,
        ]);
    }

    #[Route('/rentals/{id}/payment-link', name: 'rental_payment_link', methods: ['POST'])]
    public function getPaymentLink(
        \App\Entity\Rental $rental,
        \App\Service\FedaPayService $fedaPayService,
        EntityManagerInterface $em
    ): JsonResponse {
        /** @var User $user */
        $user = $this->getUser();
        if ($rental->getLocataire() !== $user) {
            return $this->json(['error' => 'Access denied'], Response::HTTP_FORBIDDEN);
        }

        if ($rental->isPaid()) {
            return $this->json(['message' => 'Already paid'], Response::HTTP_OK);
        }

        $totalAmount = $rental->getTotalAmountDue();
        $penalty = $rental->calculatePenalty();

        // Create pending payment record
        $payment = new \App\Entity\Payment();
        $payment->setRental($rental)
            ->setUser($user)
            ->setAmount($totalAmount)
            ->setStatus('pending');
        
        $em->persist($payment);
        $em->flush();

        $description = "Paiement Loyer - " . $rental->getProperty()->getTitle();
        if ($penalty > 0) {
            $description .= " (Incluant " . number_format($penalty, 0, ',', ' ') . " FCFA de pénalité)";
        }

        try {
            $paymentUrl = $fedaPayService->createPayment(
                (float) $totalAmount,
                $description,
                [
                    'firstname' => $user->getPrenom(),
                    'lastname' => $user->getNom(),
                    'email' => $user->getEmail(),
                    'phone' => $user->getTelephone() ?: '00000000',
                    'callback_url' => $this->generateUrl('app_tenant_payment_callback', ['id' => $payment->getId()], \Symfony\Component\Routing\Generator\UrlGeneratorInterface::ABSOLUTE_URL)
                ]
            );

            return $this->json(['payment_url' => $paymentUrl]);
        } catch (\Exception $e) {
            return $this->json(['error' => $e->getMessage()], Response::HTTP_INTERNAL_SERVER_ERROR);
        }
    }
}
