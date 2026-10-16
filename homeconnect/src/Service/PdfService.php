<?php

namespace App\Service;

use Dompdf\Dompdf;
use Dompdf\Options;
use Twig\Environment;

class PdfService
{
    private $twig;
    private $dompdf;

    public function __construct(Environment $twig)
    {
        $this->twig = $twig;
        
        $options = new Options();
        $options->set('defaultFont', 'Arial');
        $options->set('isRemoteEnabled', true);
        
        $this->dompdf = new Dompdf($options);
    }

    /**
     * Génère un PDF à partir d'un template Twig
     */
    public function generateBinaryPdf(string $template, array $data = []): string
    {
        $html = $this->twig->render($template, $data);
        $this->dompdf->loadHtml($html);
        $this->dompdf->setPaper('A4', 'portrait');
        $this->dompdf->render();
        
        return $this->dompdf->output();
    }

    /**
     * Affiche le PDF dans le navigateur
     */
    public function showPdfFile(string $html, string $filename): void
    {
        $this->dompdf->loadHtml($html);
        $this->dompdf->setPaper('A4', 'portrait');
        $this->dompdf->render();
        $this->dompdf->stream($filename, [
            'Attachment' => false
        ]);
    }
}
