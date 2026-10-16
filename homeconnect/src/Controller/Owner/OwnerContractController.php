<?php

namespace App\Controller\Owner;

use App\Entity\Rental;
use App\Service\PdfService;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/proprietary/contracts')]
#[IsGranted('ROLE_PROPRIETAIRE')]
class OwnerContractController extends AbstractController
{
    #[Route('/{id}/generate', name: 'app_owner_contract_generate_pdf')]
    public function generateContract(Rental $rental, PdfService $pdfService): Response
    {
        // Vérifier que le propriétaire a bien accès à ce bien
        if ($rental->getProperty()->getProprietaire() !== $this->getUser()) {
            throw $this->createAccessDeniedException("Vous n'êtes pas le propriétaire de ce bien.");
        }

        $filename = 'contrat_bail_' . $rental->getId() . '.pdf';

        $pdfContent = $pdfService->generateBinaryPdf('pdf/contract_bail.html.twig', [
            'rental' => $rental,
            'property' => $rental->getProperty(),
            'owner' => $rental->getProperty()->getProprietaire(),
            'tenant' => $rental->getLocataire(),
        ]);

        return new Response($pdfContent, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'inline; filename="' . $filename . '"',
        ]);
    }
}
