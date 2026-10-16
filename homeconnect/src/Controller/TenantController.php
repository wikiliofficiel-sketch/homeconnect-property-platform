<?php

namespace App\Controller;

use App\Entity\User;
use App\Entity\Property;
use App\Entity\Application;
use App\Entity\Favorite;
use App\Entity\Review;
use App\Entity\Post;
use App\Entity\PostComment;
use App\Entity\CommunityReport;
use App\Entity\Partner;
use App\Entity\Notification;
use App\Entity\PropertyInteraction;
use App\Entity\PropertyComment;
use App\Repository\PropertyRepository;
use App\Repository\ApplicationRepository;
use App\Repository\FavoriteRepository;
use App\Repository\ReviewRepository;
use App\Repository\PostRepository;
use App\Repository\PropertyInteractionRepository;
use App\Repository\PropertyCommentRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use App\Entity\SupportTicket;
use App\Repository\PostCommentRepository;
use App\Repository\CommunityReportRepository;
use App\Repository\PartnerRepository;
use App\Service\NotificationService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/locataire')]
#[IsGranted('ROLE_LOCATAIRE')]
class TenantController extends AbstractController
{
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // DASHBOARD & NAVIGATION
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/', name: 'app_tenant_dashboard')]
    public function dashboard(
        ApplicationRepository $appRepo,
        FavoriteRepository $favRepo,
        ReviewRepository $reviewRepo,
        PropertyRepository $propertyRepo
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        $myApplications = $appRepo->findByLocataire($user->getId());
        $favorites = $favRepo->findByLocataire($user->getId());
        $unreadReviews = $reviewRepo->findByTargetUser($user->getId());
        
        $recommendedProperties = $propertyRepo->findBy(['statut' => Property::STATUS_ACTIVE], ['createdAt' => 'DESC'], 5);

        return $this->render('tenant/dashboard.html.twig', [
            'applicationsCount' => count($myApplications),
            'favoritesCount' => count($favorites),
            'reviewsCount' => count($unreadReviews),
            'pendingApplications' => array_filter($myApplications, fn($a) => $a->getStatut() === 'pending'),
            'recentFavorites' => array_slice($favorites, 0, 3),
            'recommendedProperties' => $recommendedProperties,
            'rentals' => $user->getRentals(),
        ]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // RECHERCHE & BIENS
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/search', name: 'app_tenant_search')]
    public function search(PropertyRepository $repo, Request $request): Response
    {
        $query = $repo->createQueryBuilder('p')
            ->andWhere('p.statut = :statut')
            ->setParameter('statut', Property::STATUS_ACTIVE);

        // Filtres
        $ville = $request->query->get('ville');
        $budget = $request->query->get('budget');
        $pieces = $request->query->get('pieces');
        $verified = $request->query->get('verified');

        if ($ville) {
            $query->andWhere('p.city LIKE :ville')
                ->setParameter('ville', '%' . $ville . '%');
        }

        if ($budget) {
            $query->andWhere('p.pricePerMonth <= :budget')
                ->setParameter('budget', $budget);
        }

        if ($pieces) {
            $query->andWhere('p.rooms >= :pieces')
                ->setParameter('pieces', $pieces);
        }

        if ($verified === 'on') {
            $query->leftJoin('p.proprietaire', 'prop')
                ->andWhere('prop.isVerified = true');
        }

        $properties = $query->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        return $this->render('tenant/search/list.html.twig', [
            'properties' => $properties,
            'filters' => [
                'ville' => $ville,
                'budget' => $budget,
                'pieces' => $pieces,
                'verified' => $verified,
            ]
        ]);
    }

    #[Route('/property/{id}', name: 'app_tenant_property_show')]
    public function showProperty(
        Property $property,
        FavoriteRepository $favRepo,
        ReviewRepository $reviewRepo,
        PropertyRepository $propertyRepo,
        ApplicationRepository $appRepo,
        PropertyInteractionRepository $interactionRepo,
        PropertyCommentRepository $commentRepo,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        if ($property->getStatut() !== Property::STATUS_ACTIVE) {
            throw $this->createAccessDeniedException('This property is not available');
        }

        $property->setViews($property->getViews() + 1);
        $em->flush();

        $isFavorite = $favRepo->isFavorite($user->getId(), $property->getId());
        $proprietaireReviews = $reviewRepo->findByTargetUser($property->getProprietaire()->getId());
        $avgRating = $reviewRepo->calculateAverageRating($property->getProprietaire()->getId());

        $existingApplication = $appRepo->findOneBy([
            'property'  => $property,
            'locataire' => $user,
            'statut'    => ['pending', 'accepted'],
        ]);

        $similar = $propertyRepo->createQueryBuilder('p')
            ->where('p.statut = :statut')
            ->andWhere('p.id != :id')
            ->andWhere('(p.city = :city OR p.type = :type)')
            ->setParameter('statut', Property::STATUS_ACTIVE)
            ->setParameter('id', $property->getId())
            ->setParameter('city', $property->getCity())
            ->setParameter('type', $property->getType())
            ->setMaxResults(4)
            ->orderBy('p.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        $likesCount    = $interactionRepo->countByType($property->getId(), 'like');
        $dislikesCount = $interactionRepo->countByType($property->getId(), 'dislike');
        $userInteraction = $interactionRepo->findOneByPropertyAndUser($property->getId(), $user->getId());
        $propertyComments = $commentRepo->findByProperty($property->getId());

        return $this->render('tenant/property/show.html.twig', [
            'property'            => $property,
            'isFavorite'          => $isFavorite,
            'proprietaire'        => $property->getProprietaire(),
            'reviews'             => $proprietaireReviews,
            'avgRating'           => $avgRating,
            'similarProperties'   => $similar,
            'existingApplication' => $existingApplication,
            'likesCount'          => $likesCount,
            'dislikesCount'       => $dislikesCount,
            'userInteraction'     => $userInteraction,
            'propertyComments'    => $propertyComments,
        ]);
    }

    #[Route('/property/{id}/react', name: 'app_tenant_property_react', methods: ['POST'])]
    public function reactToProperty(
        Property $property,
        Request $request,
        EntityManagerInterface $em,
        PropertyInteractionRepository $interactionRepo
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $type = $request->request->get('type');

        if (!\in_array($type, ['like', 'dislike'])) {
            return $this->redirectToRoute('app_tenant_property_show', ['id' => $property->getId()]);
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
            $interaction->setProperty($property);
            $interaction->setUser($user);
            $interaction->setType($type);
            $em->persist($interaction);
        }

        $em->flush();

        // Resync denormalized counters
        $property->setLikesCount($interactionRepo->countByType($property->getId(), 'like'));
        $property->setDislikesCount($interactionRepo->countByType($property->getId(), 'dislike'));
        $em->flush();

        return $this->redirectToRoute('app_tenant_property_show', ['id' => $property->getId()]);
    }

    #[Route('/property/{id}/comment', name: 'app_tenant_property_comment', methods: ['POST'])]
    public function commentProperty(
        Property $property,
        Request $request,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user    = $this->getUser();
        $content = trim($request->request->get('content', ''));

        if (\strlen($content) < 5) {
            $this->addFlash('danger', 'Le commentaire doit faire au moins 5 caractères.');
            return $this->redirectToRoute('app_tenant_property_show', ['id' => $property->getId()]);
        }

        if (\strlen($content) > 500) {
            $this->addFlash('danger', 'Le commentaire ne peut pas dépasser 500 caractères.');
            return $this->redirectToRoute('app_tenant_property_show', ['id' => $property->getId()]);
        }

        $comment = new PropertyComment();
        $comment->setProperty($property);
        $comment->setAuthor($user);
        $comment->setContent($content);
        $em->persist($comment);

        $property->setCommentsCount($property->getCommentsCount() + 1);
        $em->flush();

        $this->addFlash('success', 'Commentaire publié !');
        return $this->redirectToRoute('app_tenant_property_show', ['id' => $property->getId()]);
    }

    #[Route('/property/comment/{id}/delete', name: 'app_tenant_property_comment_delete', methods: ['POST'])]
    public function deletePropertyComment(PropertyComment $comment, EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($comment->getAuthor()->getId() !== $user->getId()) {
            throw $this->createAccessDeniedException();
        }

        $property   = $comment->getProperty();
        $propertyId = $property->getId();
        $em->remove($comment);
        $property->setCommentsCount(\max(0, $property->getCommentsCount() - 1));
        $em->flush();

        $this->addFlash('success', 'Commentaire supprimé.');
        return $this->redirectToRoute('app_tenant_property_show', ['id' => $propertyId]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // FAVORIS
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/favorites', name: 'app_tenant_favorites')]
    public function favorites(FavoriteRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $favorites = $repo->findByLocataire($user->getId());

        return $this->render('tenant/favorites/list.html.twig', [
            'favorites' => $favorites,
        ]);
    }

    #[Route('/favorite/toggle/{propertyId}', name: 'app_tenant_favorite_toggle', methods: ['POST'])]
    public function toggleFavorite(
        int $propertyId,
        PropertyRepository $propRepo,
        FavoriteRepository $favRepo,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $property = $propRepo->find($propertyId);

        if (!$property) {
            throw $this->createNotFoundException();
        }

        $existing = $favRepo->findOneBy(['locataire' => $user, 'property' => $property]);

        if ($existing) {
            $em->remove($existing);
            $message = 'Bien retiré des favoris';
        } else {
            $favorite = new Favorite();
            $favorite->setLocataire($user);
            $favorite->setProperty($property);
            $em->persist($favorite);
            $message = 'Bien ajouté aux favoris';
        }

        $em->flush();
        $this->addFlash('success', $message);

        return $this->redirectToRoute('app_tenant_property_show', ['id' => $propertyId]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // APPLICATIONS / CANDIDATURES
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/applications', name: 'app_tenant_applications')]
    public function myApplications(ApplicationRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $applications = $repo->findByLocataire($user->getId());

        return $this->render('tenant/applications/list.html.twig', [
            'applications' => $applications,
        ]);
    }

    #[Route('/application/{id}', name: 'app_tenant_application_show')]
    public function showApplication(Application $application, ReviewRepository $reviewRepo): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($application->getLocataire()->getId() !== $user->getId()) {
            throw $this->createAccessDeniedException();
        }

        $proprietaire = $application->getProperty()->getProprietaire();
        $avgRating    = $reviewRepo->calculateAverageRating($proprietaire->getId());
        $reviews      = $reviewRepo->findByTargetUser($proprietaire->getId());

        return $this->render('tenant/applications/show.html.twig', [
            'application'  => $application,
            'proprietaire' => $proprietaire,
            'avgRating'    => $avgRating,
            'totalReviews' => count($reviews),
        ]);
    }

    #[Route('/property/{id}/apply', name: 'app_tenant_apply', methods: ['POST'])]
    public function applyToProperty(
        Property $property,
        Request $request,
        ApplicationRepository $appRepo,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        if ($property->getStatut() !== Property::STATUS_ACTIVE) {
            throw $this->createAccessDeniedException('Cannot apply to inactive property');
        }

        // Check if already applied
        $existing = $appRepo->findOneBy([
            'property' => $property,
            'locataire' => $user,
            'statut' => 'pending'
        ]);

        if ($existing) {
            $this->addFlash('warning', 'Vous avez déjà une candidature en attente pour ce bien.');
            return $this->redirectToRoute('app_tenant_property_show', ['id' => $property->getId()]);
        }

        $dateDebut = $request->request->get('dateDebut') ?: date('Y-m-d');
        $dateFin   = $request->request->get('dateFin')   ?: date('Y-m-d', strtotime('+1 month'));
        $message   = $request->request->get('message', '');

        $application = new Application();
        $application->setProperty($property);
        $application->setLocataire($user);
        $application->setDateDebut(new \DateTime($dateDebut));
        $application->setDateFin(new \DateTime($dateFin));
        $application->setStatut('pending');

        if ($message) {
            $application->setMessage($message);
        }

        $em->persist($application);
        $em->flush();

        // Notifier les admins de la nouvelle candidature
        $notificationService->notifyAdmins(
            'application_received',
            sprintf(
                'Nouvelle candidature de %s pour le bien "%s".',
                $user->getFullName(),
                $property->getTitle()
            ),
            'Nouvelle candidature',
            $application->getId(),
            'application'
        );

        $this->addFlash('success', 'Candidature envoyée avec succès !');
        return $this->redirectToRoute('app_tenant_applications');
    }

    #[Route('/application/{id}/cancel', name: 'app_tenant_application_cancel', methods: ['POST'])]
    public function cancelApplication(
        Application $application,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        if ($application->getLocataire()->getId() !== $user->getId()) {
            throw $this->createAccessDeniedException();
        }

        if (!in_array($application->getStatut(), ['pending', 'accepted'])) {
            throw $this->createAccessDeniedException('Cannot cancel this application');
        }

        $application->setStatut('cancelled');
        $em->flush();

        $this->addFlash('success', 'Candidature annulée');
        return $this->redirectToRoute('app_tenant_applications');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // REVIEWS / Ã‰VALUATIONS
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/reviews', name: 'app_tenant_reviews')]
    public function myReviews(ReviewRepository $repo): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $receivedReviews = $repo->findByTargetUser($user->getId());
        $avgRating = $repo->calculateAverageRating($user->getId());
        
        $starStats = [];
        for ($i = 5; $i >= 1; $i--) {
            $starStats[$i] = count(array_filter($receivedReviews, fn($r) => $r->getRating() == $i));
        }

        return $this->render('tenant/reviews/list_v2.html.twig', [
            'reviews' => $receivedReviews,
            'averageRating' => $avgRating,
            'totalReviews' => count($receivedReviews),
            'rentals' => $user->getRentals(),
            'starStats' => $starStats,
        ]);
    }

    #[Route('/review/create', name: 'app_tenant_review_create', methods: ['POST'])]
    public function createReview(
        Request $request,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $rentalId = $request->request->get('rentalId');
        $rental = $em->getRepository('App\Entity\Rental')->find($rentalId);

        if (!$rental || $rental->getLocataire()->getId() !== $user->getId()) {
            throw $this->createAccessDeniedException();
        }

        $rating = (int) $request->request->get('rating');
        $comment = $request->request->get('comment');

        if ($rating < 1 || $rating > 5 || !$comment) {
            $this->addFlash('error', 'Veuillez remplir tous les champs');
            return $this->redirectToRoute('app_tenant_property_show', ['id' => $rental->getProperty()->getId()]);
        }

        $review = new Review();
        $review->setRental($rental);
        $review->setAuthor($user);
        $review->setTargetUser($rental->getProperty()->getProprietaire());
        $review->setType(Review::TYPE_PROPRIETAIRE);
        $review->setRating($rating);
        $review->setComment($comment);

        $em->persist($review);
        $em->flush();

        $this->addFlash('success', 'Ã‰valuation publiée !');
        return $this->redirectToRoute('app_tenant_property_show', ['id' => $rental->getProperty()->getId()]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // COMMUNAUTÉ
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/community', name: 'app_tenant_community')]
    public function community(PostRepository $repo, Request $request): Response
    {
        $category = $request->query->get('category');
        $search = $request->query->get('search');

        if ($search) {
            $posts = $repo->searchByTitle($search);
        } elseif ($category) {
            $posts = $repo->findByCategory($category);
        } else {
            $posts = $repo->findLatest(20);
        }

        return $this->render('tenant/community/posts/list.html.twig', [
            'posts' => $posts,
            'category' => $category,
            'search' => $search,
        ]);
    }

    #[Route('/community/post/{id}', name: 'app_tenant_post_show', requirements: ['id' => '\d+'])]
    public function showPost(
        Post $post,
        PostCommentRepository $commentRepo
    ): Response {
        $post->incrementViewCount();

        $comments = $commentRepo->findByPost($post->getId());

        return $this->render('tenant/community/posts/show.html.twig', [
            'post' => $post,
            'comments' => $comments,
        ]);
    }

    #[Route('/community/post/create', name: 'app_tenant_post_create', methods: ['POST'])]
    public function createPost(
        Request $request,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        $title = $request->request->get('title');
        $content = $request->request->get('content');
        $category = $request->request->get('category');

        if (!$title || !$content) {
            $this->addFlash('error', 'Titre et contenu sont requis');
            return $this->redirectToRoute('app_tenant_community');
        }

        $post = new Post();
        $post->setAuthor($user);
        $post->setTitle($title);
        $post->setContent($content);
        $post->setCategory($category);

        $em->persist($post);
        $em->flush();

        $this->addFlash('success', 'Post créé !');
        return $this->redirectToRoute('app_tenant_post_show', ['id' => $post->getId()]);
    }

    #[Route('/community/comment/{postId}', name: 'app_tenant_comment_create', methods: ['POST'])]
    public function createComment(
        int $postId,
        Request $request,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $post = $em->getRepository(Post::class)->find($postId);

        if (!$post) {
            throw $this->createNotFoundException();
        }

        $content = $request->request->get('content');

        if (!$content) {
            $this->addFlash('error', 'Le commentaire ne peut pas être vide');
            return $this->redirectToRoute('app_tenant_post_show', ['id' => $postId]);
        }

        $comment = new PostComment();
        $comment->setPost($post);
        $comment->setAuthor($user);
        $comment->setContent($content);

        $em->persist($comment);
        $em->flush();

        $this->addFlash('success', 'Commentaire ajouté !');
        return $this->redirectToRoute('app_tenant_post_show', ['id' => $postId]);
    }

    #[Route('/community/report', name: 'app_tenant_report_create', methods: ['POST'])]
    public function reportContent(
        Request $request,
        EntityManagerInterface $em,
        NotificationService $notificationService
    ): Response {
        /** @var User $user */
        $user = $this->getUser();

        $propertyId  = $request->request->get('propertyId');
        $postId      = $request->request->get('postId');
        $commentId   = $request->request->get('commentId');
        $reason      = $request->request->get('reason', '');
        $description = $request->request->get('description', '');
        $priority    = $request->request->get('priority', \App\Entity\Report::PRIORITY_MEDIUM);

        if (!\in_array($priority, [\App\Entity\Report::PRIORITY_LOW, \App\Entity\Report::PRIORITY_MEDIUM, \App\Entity\Report::PRIORITY_HIGH, \App\Entity\Report::PRIORITY_CRITICAL])) {
            $priority = \App\Entity\Report::PRIORITY_MEDIUM;
        }

        // ── Signalement d'un BIEN ──────────────────────────────────
        if ($propertyId) {
            $property = $em->getRepository(Property::class)->find($propertyId);
            if ($property) {
                $report = new \App\Entity\Report();
                $report->setType(\App\Entity\Report::TYPE_PROPERTY);
                $report->setProperty($property);
                $report->setSignataire($user);
                $report->setMotif($reason . ($description ? ' — ' . $description : ''));
                $report->setPriorite($priority);
                $em->persist($report);
                $em->flush();

                $notificationService->notifyAdmins(
                    'report_received',
                    \sprintf('[%s] %s a signalé le bien "%s" : %s', \strtoupper($priority), $user->getFullName(), $property->getTitle(), $reason),
                    'Nouveau signalement de bien',
                    $report->getId(),
                    'reports'
                );

                $this->addFlash('success', 'Signalement envoyé. Notre équipe va examiner cette annonce sous 24h.');
                return $this->redirectToRoute('app_tenant_property_show', ['id' => $propertyId]);
            }
        }

        // ── Signalement d'un UTILISATEUR ──────────────────────────
        $reportedUserId = $request->request->get('reportedUserId');
        if ($reportedUserId) {
            $reportedUser = $em->getRepository(User::class)->find($reportedUserId);
            if ($reportedUser) {
                $report = new \App\Entity\Report();
                $report->setType(\App\Entity\Report::TYPE_USER);
                $report->setUtilisateur($reportedUser);
                $report->setSignataire($user);
                $report->setMotif($reason . ($description ? ' — ' . $description : ''));
                $report->setPriorite($priority);
                $em->persist($report);
                $em->flush();

                $notificationService->notifyAdmins(
                    'report_received',
                    \sprintf('[%s] %s a signalé l\'utilisateur %s : %s', \strtoupper($priority), $user->getFullName(), $reportedUser->getFullName(), $reason),
                    'Nouveau signalement d\'utilisateur',
                    $report->getId(),
                    'reports'
                );

                $this->addFlash('success', 'Signalement envoyé. Merci pour votre vigilance.');
                return $this->redirectToRoute('app_tenant_dashboard');
            }
        }

        // ── Signalement communautaire (post/commentaire) ───────────
        $communityReport = new CommunityReport();
        $communityReport->setReporter($user);
        $communityReport->setReason($reason);
        $communityReport->setDescription($description);
        $communityReport->setPriority($priority);

        if ($postId) {
            $post = $em->getRepository(Post::class)->find($postId);
            $communityReport->setPost($post);
        }
        if ($commentId) {
            $comment = $em->getRepository(PostComment::class)->find($commentId);
            $communityReport->setComment($comment);
        }

        $em->persist($communityReport);
        $em->flush();

        $this->addFlash('success', 'Signalement envoyé. Merci !');
        return $this->redirectToRoute('app_tenant_community');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // PARTENAIRES
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/partners', name: 'app_tenant_partners')]
    public function partners(PartnerRepository $repo): Response
    {
        $partners = $repo->findByStatut(Partner::STATUS_ACTIVE);

        return $this->render('tenant/partners.html.twig', [
            'partners' => $partners,
        ]);
    }

    #[Route('/partner/{id}/contact', name: 'app_tenant_partner_contact', methods: ['POST'])]
    public function contactPartner(
        int $id,
        Request $request,
        EntityManagerInterface $em
    ): Response {
        /** @var User $user */
        $user = $this->getUser();
        $partner = $em->getRepository('App\Entity\Partner')->find($id);

        if (!$partner) {
            throw $this->createNotFoundException();
        }

        $message = $request->request->get('message');

        // Store contact inquiry (could create a new entity or send email)
        // For now, just create notification
        $notif = new Notification();
        $notif->setDestinataire($user)
            ->setType('partner_contact')
            ->setMessage('Demande de contact envoyée Ã  ' . $partner->getNom())
            ->setRelatedEntityId($partner->getId())
            ->setRelatedEntityType('partner');

        $em->persist($notif);
        $em->flush();

        $this->addFlash('success', 'Demande envoyée. Le partenaire vous contactera bientÃ´t !');
        return $this->redirectToRoute('app_tenant_partners');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // MESSAGERIE (CHAT RÃ‰EL)
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/messages', name: 'app_tenant_messages')]
    public function messages(EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user        = $this->getUser();
        $userRepo    = $em->getRepository(User::class);
        $messageRepo = $em->getRepository(\App\Entity\Message::class);

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
            // Locataire ↔ Admin uniquement
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

        // Toujours proposer les admins comme contacts disponibles
        $admins = $userRepo->findWithRole('ROLE_ADMIN');
        $defaultContacts = [];
        foreach ($admins as $admin) {
            if (!isset($convMap[$admin->getId()])) {
                $defaultContacts[] = $admin;
            }
        }

        return $this->render('tenant/messages/list.html.twig', [
            'conversations'   => array_values($convMap),
            'defaultContacts' => $defaultContacts,
        ]);
    }

    #[Route('/messages/{receiverId}', name: 'app_tenant_messages_chat')]
    public function chat(int $receiverId, EntityManagerInterface $em, Request $request, NotificationService $notificationService): Response
    {
        /** @var User $user */
        $user        = $this->getUser();
        $userRepo    = $em->getRepository(User::class);
        $messageRepo = $em->getRepository(\App\Entity\Message::class);
        $receiver    = $userRepo->find($receiverId);

        if (!$receiver) throw $this->createNotFoundException();

        // Locataire ne peut écrire qu'à un admin
        if (!\in_array('ROLE_ADMIN', $receiver->getRoles())) {
            $this->addFlash('danger', 'Vous pouvez uniquement échanger avec l\'administration HomeConnect.');
            return $this->redirectToRoute('app_tenant_messages');
        }

        if ($request->isMethod('POST')) {
            $content = trim($request->request->get('content', ''));
            if ($content) {
                $msg = new \App\Entity\Message();
                $msg->setSender($user)->setReceiver($receiver)->setContent($content);
                $msg->setStatus(\App\Entity\Message::STATUS_SENT);
                $em->persist($msg);
                $em->flush();

                // Notifier le destinataire (admin)
                $notificationService->notifyAndFlush(
                    $receiver,
                    'message_received',
                    sprintf('%s vous a envoyé un message : "%s"', $user->getFullName(), mb_substr($content, 0, 80)),
                    'Nouveau message',
                    $msg->getId(),
                    'message'
                );

                if ($request->isXmlHttpRequest()
                    || $request->headers->get('X-Requested-With') === 'XMLHttpRequest') {
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
                return $this->redirectToRoute('app_tenant_messages_chat', ['receiverId' => $receiverId]);
            }
        }

        $messages = $messageRepo->findConversation($user->getId(), $receiverId);

        // Marquer reçus comme lus
        $uid = $user->getId();
        foreach ($messages as $msg) {
            if ($msg->getReceiver()?->getId() === $uid
                && $msg->getStatus() !== \App\Entity\Message::STATUS_READ) {
                $msg->setStatus(\App\Entity\Message::STATUS_READ);
                $msg->setReadAt(new \DateTimeImmutable());
            }
        }
        $em->flush();

        // Construire conversations sidebar (admins uniquement)
        $allMessages = $messageRepo->createQueryBuilder('m')
            ->where('(m.sender = :user AND m.deletedForSender = false)')
            ->orWhere('(m.receiver = :user AND m.deletedForReceiver = false)')
            ->setParameter('user', $user)
            ->orderBy('m.createdAt', 'DESC')
            ->getQuery()
            ->getResult();

        $convMap = [];
        foreach ($allMessages as $msg) {
            $isMine  = $msg->getSender()->getId() === $uid;
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

        return $this->render('tenant/messages/list.html.twig', [
            'activeContact'   => $receiver,
            'messages'        => $messages,
            'conversations'   => array_values($convMap),
            'defaultContacts' => [],
        ]);
    }

    #[Route('/messages/upload/{receiverId}', name: 'app_tenant_messages_upload', methods: ['POST'])]
    public function upload(int $receiverId, Request $request, EntityManagerInterface $em): JsonResponse
    {
        /** @var User $user */
        $user = $this->getUser();
        $receiver = $em->getRepository(User::class)->find($receiverId);
        if (!$receiver) return new JsonResponse(['error' => 'User not found'], 404);

        $file = $request->files->get('file');
        $type = $request->request->get('type', 'image'); // 'image', 'audio', 'document'
        $stickerUrl = $request->request->get('sticker_url');
        
        if (!$file && !$stickerUrl) return new JsonResponse(['error' => 'No file or sticker provided'], 400);

        $attachmentUrl = $stickerUrl;
        if ($file) {
            $uploadDir = $this->getParameter('kernel.project_dir') . '/public/uploads/messages';
            if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);
            $filename = uniqid() . '.' . $file->guessExtension();
            $file->move($uploadDir, $filename);
            $attachmentUrl = '/uploads/messages/' . $filename;
        }

        $msg = new \App\Entity\Message();
        $msg->setSender($user);
        $msg->setReceiver($receiver);
        $msg->setType($type);
        $msg->setAttachmentUrl($attachmentUrl);
        $msg->setContent($stickerUrl ? 'Sticker' : ($type === 'audio' ? 'Message vocal' : ($type === 'image' ? 'Image' : 'Fichier')));
        
        $em->persist($msg);
        $em->flush();

        return new JsonResponse([
            'success' => true,
            'url' => $msg->getAttachmentUrl(),
            'type' => $msg->getType(),
            'createdAt' => $msg->getCreatedAt()->format('H:i')
        ]);
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // CONTRATS & Ã‰TATS DES LIEUX
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/contracts', name: 'app_tenant_contracts')]
    public function contracts(EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $rentals = $em->getRepository(\App\Entity\Rental::class)->findBy(['locataire' => $user]);

        return $this->render('tenant/contracts/list.html.twig', [
            'rentals' => $rentals,
        ]);
    }

    #[Route('/contract/{id}/inventory', name: 'app_tenant_contract_inventory', methods: ['POST'])]
    public function saveInventory(int $id, Request $request, EntityManagerInterface $em): Response
    {
        $rental = $em->getRepository(\App\Entity\Rental::class)->find($id);
        if (!$rental) throw $this->createNotFoundException();

        $data = $request->request->all();
        $rental->setInventoryData(json_encode($data));
        $em->flush();

        $this->addFlash('success', 'Ã‰tat des lieux enregistré en base de données.');
        return $this->redirectToRoute('app_tenant_contracts');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // ABONNEMENT PREMIUM+
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/subscription', name: 'app_tenant_subscription')]
    public function subscription(EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        $subscription = $em->getRepository(\App\Entity\Subscription::class)->findOneBy(['proprietaire' => $user]);

        return $this->render('tenant/subscription.html.twig', [
            'subscription' => $subscription,
        ]);
    }

    #[Route('/subscription/upgrade', name: 'app_tenant_subscription_upgrade', methods: ['POST'])]
    public function upgradeSubscription(EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();
        
        $sub = $em->getRepository(\App\Entity\Subscription::class)->findOneBy(['proprietaire' => $user]);
        if (!$sub) {
            $sub = new \App\Entity\Subscription();
            $sub->setProprietaire($user);
        }

        $sub->setPlan('premium_plus');
        $sub->setStatut('active');
        $sub->setDateDebut(new \DateTimeImmutable());
        $sub->setDateExpiration((new \DateTimeImmutable())->modify('+1 year'));

        $em->persist($sub);
        $em->flush();

        $this->addFlash('success', 'Félicitations ! Votre abonnement Premium+ est maintenant actif.');
        return $this->redirectToRoute('app_tenant_subscription');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // VÃ‰RIFICATION KYC
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/kyc', name: 'app_tenant_kyc', methods: ['GET', 'POST'])]
    public function kyc(Request $request, EntityManagerInterface $em): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($request->isMethod('POST')) {
            $user->setKycStatus('pending');
            $user->setKycSubmittedAt(new \DateTimeImmutable());
            // Logique réelle d'upload de fichiers ici...
            $em->flush();

            $this->addFlash('success', 'Documents KYC soumis pour validation.');
            return $this->redirectToRoute('app_tenant_profile');
        }

        return $this->render('tenant/kyc.html.twig');
    }

    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // PROFIL
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    #[Route('/profile', name: 'app_tenant_profile', methods: ['GET', 'POST'])]
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
            return $this->redirectToRoute('app_tenant_profile');
        }

        $avgRating    = $reviewRepo->calculateAverageRating($user->getId());
        $totalReviews = $reviewRepo->countReviews($user->getId());

        $visitesPlanifiees = (int) $em->createQuery(
            'SELECT COUNT(v) FROM App\Entity\Visite v JOIN v.application a WHERE a.locataire = :user AND v.statut = :statut'
        )->setParameter('user', $user)->setParameter('statut', 'planifiee')->getSingleScalarResult();

        $signalementsCount = (int) $em->createQuery(
            'SELECT COUNT(r) FROM App\Entity\Report r WHERE r.signataire = :user'
        )->setParameter('user', $user)->getSingleScalarResult();

        return $this->render('tenant/profile.html.twig', [
            'user'              => $user,
            'averageRating'     => $avgRating,
            'totalReviews'      => $totalReviews,
            'reviews'           => $reviewRepo->findByTargetUser($user->getId()),
            'visitesPlanifiees' => $visitesPlanifiees,
            'signalementsCount' => $signalementsCount,
        ]);
    }

    #[Route('/profile/password', name: 'app_tenant_change_password', methods: ['POST'])]
    public function changePassword(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $passwordHasher): Response
    {
        /** @var User $user */
        $user            = $this->getUser();
        $currentPassword = $request->request->get('current_password', '');
        $newPassword     = $request->request->get('new_password', '');
        $confirmPassword = $request->request->get('confirm_password', '');

        if (!$passwordHasher->isPasswordValid($user, $currentPassword)) {
            $this->addFlash('danger', 'Mot de passe actuel incorrect.');
            return $this->redirectToRoute('app_tenant_profile');
        }

        if (\strlen($newPassword) < 8) {
            $this->addFlash('danger', 'Le nouveau mot de passe doit contenir au moins 8 caractères.');
            return $this->redirectToRoute('app_tenant_profile');
        }

        if ($newPassword !== $confirmPassword) {
            $this->addFlash('danger', 'Les nouveaux mots de passe ne correspondent pas.');
            return $this->redirectToRoute('app_tenant_profile');
        }

        $user->setPassword($passwordHasher->hashPassword($user, $newPassword));
        $em->flush();

        $this->addFlash('success', 'Mot de passe modifié avec succès !');
        return $this->redirectToRoute('app_tenant_profile');
    }

    #[Route('/profile/delete', name: 'app_tenant_delete_account', methods: ['POST'])]
    public function deleteAccount(Request $request, EntityManagerInterface $em, UserPasswordHasherInterface $passwordHasher): Response
    {
        /** @var User $user */
        $user     = $this->getUser();
        $password = $request->request->get('delete_password', '');

        if (!$passwordHasher->isPasswordValid($user, $password)) {
            $this->addFlash('danger', 'Mot de passe incorrect. La suppression a été annulée.');
            return $this->redirectToRoute('app_tenant_profile');
        }

        $em->remove($user);
        $em->flush();

        $request->getSession()->invalidate();

        return $this->redirect('/');
    }

    #[Route('/support', name: 'app_tenant_support', methods: ['GET', 'POST'])]
    public function support(Request $request, EntityManagerInterface $em, NotificationService $notificationService): Response
    {
        /** @var User $user */
        $user = $this->getUser();

        if ($request->isMethod('POST')) {
            $subject = trim($request->request->get('subject', ''));
            $message = trim($request->request->get('message', ''));
            $type    = trim($request->request->get('type', 'general'));

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
                    sprintf('Nouveau ticket de support de %s : "%s"', $user->getFullName(), $subject),
                    'Nouveau ticket support',
                    $ticket->getId(),
                    'support'
                );

                $this->addFlash('success', 'Votre demande a bien été envoyée. L\'équipe vous répondra sous 24-48h.');
                return $this->redirectToRoute('app_tenant_support');
            }

            $this->addFlash('danger', 'Veuillez remplir le sujet et le message.');
        }

        return $this->render('tenant/support.html.twig');
    }
}

