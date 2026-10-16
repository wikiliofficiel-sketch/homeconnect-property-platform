<?php

namespace App\Controller\Admin;

use App\Entity\Setting;
use App\Repository\SettingRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\IsGranted;

#[Route('/admin/config', name: 'admin_config_')]
#[IsGranted('ROLE_ADMIN')]
class AdminConfigController extends AbstractController
{
    #[Route('/', name: 'index')]
    public function index(SettingRepository $settingRepo): Response
    {
        $settings = $settingRepo->findAll();
        $settingsMap = [];
        foreach ($settings as $s) {
            $settingsMap[$s->getName()] = $s->getValue();
        }

        return $this->render('admin/config/index.html.twig', [
            'settings' => $settingsMap,
        ]);
    }

    #[Route('/update', name: 'update', methods: ['POST'])]
    public function update(Request $request, EntityManagerInterface $em, SettingRepository $settingRepo): Response
    {
        $data = $request->request->all();
        foreach ($data as $name => $value) {
            $setting = $settingRepo->findOneBy(['name' => $name]);
            if (!$setting) {
                $setting = new Setting();
                $setting->setName($name);
            }
            $setting->setValue($value);
            $em->persist($setting);
        }
        $em->flush();

        $this->addFlash('success', 'Configuration mise à jour avec succès.');
        return $this->redirectToRoute('admin_config_index');
    }
}
