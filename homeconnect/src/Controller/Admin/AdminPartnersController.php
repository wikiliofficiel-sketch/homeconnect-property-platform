<?php

namespace App\Controller\Admin;

use App\Entity\Partner;
use App\Repository\PartnerRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/partners', name: 'admin_partners_')]
#[IsGranted('ROLE_ADMIN')]
class AdminPartnersController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(PartnerRepository $partnerRepo, Request $request): Response
    {
        $categorie = $request->query->get('categorie', '');
        $statut = $request->query->get('status', '');

        $query = $partnerRepo->createQueryBuilder('p');

        if ($categorie) {
            $query->andWhere('p.categorie = :categorie')
                  ->setParameter('categorie', $categorie);
        }

        if ($statut && in_array($statut, [Partner::STATUS_ACTIVE, Partner::STATUS_INACTIVE, Partner::STATUS_SUSPENDED])) {
            $query->andWhere('p.statut = :statut')
                  ->setParameter('statut', $statut);
        }

        $partners = $query->orderBy('p.nom', 'ASC')->getQuery()->getResult();

        return $this->render('admin/partners/index.html.twig', [
            'partners' => $partners,
            'categorie' => $categorie,
            'statut' => $statut,
        ]);
    }

    #[Route('/new', name: 'new')]
    public function new(Request $request, EntityManagerInterface $em): Response
    {
        if ($request->isMethod('POST')) {
            $partner = new Partner();
            $partner->setNom($request->request->get('nom', ''));
            $partner->setCategorie($request->request->get('categorie', ''));
            $partner->setDescription($request->request->get('description', ''));
            $partner->setWebsite($request->request->get('website'));
            $partner->setTelephone($request->request->get('telephone'));
            $partner->setEmail($request->request->get('email'));
            $partner->setAdresse($request->request->get('adresse', ''));
            $partner->setPersonneContact($request->request->get('personne_contact', ''));

            $em->persist($partner);
            $em->flush();

            $this->addFlash('success', 'Partenaire ajouté');
            return $this->redirectToRoute('admin_partners_index');
        }

        return $this->render('admin/partners/new.html.twig');
    }

    #[Route('/{id}/detail', name: 'show')]
    public function show(Partner $partner): Response
    {
        return $this->render('admin/partners/show.html.twig', [
            'partner' => $partner,
        ]);
    }

    #[Route('/{id}/edit', name: 'edit')]
    public function edit(Partner $partner, Request $request, EntityManagerInterface $em): Response
    {
        if ($request->isMethod('POST')) {
            $partner->setNom($request->request->get('nom', ''));
            $partner->setCategorie($request->request->get('categorie', ''));
            $partner->setDescription($request->request->get('description', ''));
            $partner->setWebsite($request->request->get('website'));
            $partner->setTelephone($request->request->get('telephone'));
            $partner->setEmail($request->request->get('email'));
            $partner->setAdresse($request->request->get('adresse', ''));
            $partner->setPersonneContact($request->request->get('personne_contact', ''));
            $partner->setUpdatedAt(new \DateTimeImmutable());

            $em->flush();

            $this->addFlash('success', 'Partenaire modifié');
            return $this->redirectToRoute('admin_partners_show', ['id' => $partner->getId()]);
        }

        return $this->render('admin/partners/edit.html.twig', [
            'partner' => $partner,
        ]);
    }

    #[Route('/{id}/delete', name: 'delete', methods: ['POST'])]
    public function delete(Partner $partner, EntityManagerInterface $em): Response
    {
        $em->remove($partner);
        $em->flush();

        $this->addFlash('success', 'Partenaire supprimé');
        return $this->redirectToRoute('admin_partners_index');
    }

    #[Route('/{id}/toggle-status', name: 'toggle_status', methods: ['POST'])]
    public function toggleStatus(Partner $partner, EntityManagerInterface $em): Response
    {
        $newStatus = $partner->getStatut() === Partner::STATUS_ACTIVE 
            ? Partner::STATUS_INACTIVE 
            : Partner::STATUS_ACTIVE;
        
        $partner->setStatut($newStatus);
        $partner->setUpdatedAt(new \DateTimeImmutable());
        $em->flush();

        $this->addFlash('success', 'Statut du partenaire mis à jour');
        return $this->redirectToRoute('admin_partners_show', ['id' => $partner->getId()]);
    }
}
