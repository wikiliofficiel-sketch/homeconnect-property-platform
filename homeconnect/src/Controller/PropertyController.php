<?php

namespace App\Controller;

use App\Entity\Property;
use App\Form\PropertyFormType;
use App\Repository\PropertyRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/property')]
class PropertyController extends AbstractController
{
    #[Route('', name: 'app_property_index')]
    public function index(PropertyRepository $propertyRepository): Response
    {
        $properties = $propertyRepository->findAvailable();

        return $this->render('property/index.html.twig', [
            'properties' => $properties,
        ]);
    }

    #[Route('/{id}', name: 'app_property_show')]
    public function show(Property $property): Response
    {
        return $this->render('property/show.html.twig', [
            'property' => $property,
        ]);
    }

    #[Route('/create', name: 'app_property_create')]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function create(Request $request, EntityManagerInterface $entityManager): Response
    {
        /** @var \App\Entity\User $user */
        $user = $this->getUser();
        $isAdmin = $user && in_array('ROLE_ADMIN', $user->getRoles());
        if (!$isAdmin && $user && !$user->canPublishProperty()) {
            $this->addFlash('error', 'Certification KYC requise avant de publier un bien.');
            return $this->redirectToRoute('app_owner_kyc');
        }

        $property = new Property();
        $form = $this->createForm(PropertyFormType::class, $property);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $property->setProprietaire($this->getUser());
            $property->setCreatedAt(new \DateTimeImmutable());

            $entityManager->persist($property);
            $entityManager->flush();

            $this->addFlash('success', 'Propriété créée avec succès !');
            return $this->redirectToRoute('app_property_show', ['id' => $property->getId()]);
        }

        return $this->render('property/create.html.twig', [
            'form' => $form,
        ]);
    }

    #[Route('/{id}/edit', name: 'app_property_edit')]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function edit(Request $request, Property $property, EntityManagerInterface $entityManager): Response
    {
        $this->denyAccessUnlessGranted('PROPERTY_EDIT', $property);

        $form = $this->createForm(PropertyFormType::class, $property);
        $form->handleRequest($request);

        if ($form->isSubmitted() && $form->isValid()) {
            $property->setUpdatedAt(new \DateTimeImmutable());
            $entityManager->flush();

            $this->addFlash('success', 'Propriété mise à jour avec succès !');
            return $this->redirectToRoute('app_property_show', ['id' => $property->getId()]);
        }

        return $this->render('property/edit.html.twig', [
            'property' => $property,
            'form' => $form,
        ]);
    }

    #[Route('/{id}/delete', name: 'app_property_delete', methods: ['POST'])]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function delete(Request $request, Property $property, EntityManagerInterface $entityManager): Response
    {
        $this->denyAccessUnlessGranted('PROPERTY_DELETE', $property);

        if ($this->isCsrfTokenValid('delete' . $property->getId(), $request->request->get('_token'))) {
            $entityManager->remove($property);
            $entityManager->flush();
            $this->addFlash('success', 'Propriété supprimée avec succès !');
        }

        return $this->redirectToRoute('app_property_index');
    }

    #[Route('/search', name: 'app_property_search')]
    public function search(Request $request, PropertyRepository $propertyRepository): Response
    {
        $criteria = $request->query->all();
        $properties = $propertyRepository->searchProperties($criteria);

        return $this->render('property/search.html.twig', [
            'properties' => $properties,
            'criteria' => $criteria,
        ]);
    }

    #[Route('/my-properties', name: 'app_my_properties')]
    #[IsGranted('ROLE_PROPRIETAIRE')]
    public function myProperties(PropertyRepository $propertyRepository): Response
    {
        $properties = $propertyRepository->findByProprietaire($this->getUser());

        return $this->render('property/my_properties.html.twig', [
            'properties' => $properties,
        ]);
    }
}
