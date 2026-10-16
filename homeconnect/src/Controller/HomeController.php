<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class HomeController extends AbstractController
{
    #[Route('/', name: 'app_home')]
    public function index(): Response
    {
        if ($user = $this->getUser()) {
            $roles = $user->getRoles();
            if (in_array('ROLE_ADMIN', $roles)) {
                return $this->redirectToRoute('admin_dashboard');
            }
            if (in_array('ROLE_PROPRIETAIRE', $roles)) {
                return $this->redirectToRoute('app_owner_dashboard');
            }
            if (in_array('ROLE_LOCATAIRE', $roles)) {
                return $this->redirectToRoute('app_tenant_dashboard');
            }
        }

        return $this->render('home/index.html.twig', [
            'controller_name' => 'HomeController',
        ]);
    }
}
