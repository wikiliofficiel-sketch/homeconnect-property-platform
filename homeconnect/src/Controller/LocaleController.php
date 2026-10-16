<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class LocaleController extends AbstractController
{
    #[Route('/change-locale/{locale}', name: 'app_change_locale')]
    public function changeLocale(string $locale, Request $request): Response
    {
        // Validate the locale
        $allowedLocales = ['fr', 'en', 'fon'];
        if (!in_array($locale, $allowedLocales, true)) {
            $locale = 'fr';
        }

        $request->getSession()->set('_locale', $locale);

        $referer = $request->headers->get('referer');

        // Avoid redirect loops: if the referer points back to a /change-locale/ URL
        // (e.g. user is on the 500 error page), fall back to the home page.
        if ($referer && !str_contains($referer, '/change-locale/')) {
            return $this->redirect($referer);
        }

        return $this->redirectToRoute('app_home');
    }
}
