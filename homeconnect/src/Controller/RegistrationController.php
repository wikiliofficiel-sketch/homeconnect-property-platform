<?php

namespace App\Controller;

use App\Entity\User;
use App\Form\RegistrationFormType;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\File\UploadedFile;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Attribute\Route;

class RegistrationController extends AbstractController
{
    #[Route('/register', name: 'app_register')]
    public function register(
        Request $request,
        UserPasswordHasherInterface $userPasswordHasher,
        Security $security,
        EntityManagerInterface $entityManager
    ): Response {
        $user = new User();
        $form = $this->createForm(RegistrationFormType::class, $user);
        $form->handleRequest($request);

        if (($form->isSubmitted() && $form->isValid())
            || ($request->isMethod('POST') && $request->request->has('email'))) {

            // Rôle
            $formRole = $request->request->get('role');
            if ($request->request->has('registration_form')) {
                $formData = $request->request->all('registration_form');
                if (isset($formData['role'])) $formRole = $formData['role'];
            }

            if (!$form->isSubmitted()) {
                $user->setEmail($request->request->get('email'));
                $user->setPrenom($request->request->get('prenom'));
                $user->setNom($request->request->get('nom'));
                $user->setTelephone($request->request->get('telephone'));
                $user->setVille($request->request->get('ville'));
                $plainPassword = $request->request->get('password');
            } else {
                $plainPassword = $form->get('plainPassword')->getData();
                if (!$formRole) $formRole = $form->get('role')->getData();
            }

            $user->setPassword($userPasswordHasher->hashPassword($user, $plainPassword));
            $user->setIsVerified(true);
            $user->setCreatedAt(new \DateTimeImmutable());

            $formRole = strtolower(trim($formRole ?? 'locataire'));
            if ($formRole === 'locataire') {
                $user->setRoles(['ROLE_LOCATAIRE']);
                $user->setVerificationStatus(null); // locataire n'a pas besoin de KYC
            } else {
                $user->setRoles(['ROLE_PROPRIETAIRE']);
                $user->setVerificationStatus('en_attente'); // KYC non encore validé
                $user->setKycStatus('pending');
                $user->setKycSubmittedAt(new \DateTimeImmutable());

                // Traitement des documents KYC
                $uploadDir = $this->getParameter('kernel.project_dir') . '/public/uploads/kyc';
                if (!is_dir($uploadDir)) mkdir($uploadDir, 0777, true);

                $this->handleKycUpload($request, $user, $uploadDir);
            }

            $entityManager->persist($user);
            $entityManager->flush();

            $roleLabel = ($formRole === 'locataire') ? 'Locataire' : 'Propriétaire';
            if ($formRole !== 'locataire') {
                $this->addFlash('success', "Compte créé ! Vos documents KYC sont en cours d'examen. Vous recevrez une notification une fois validé.");
            } else {
                $this->addFlash('success', "Votre compte $roleLabel a été créé. Connectez-vous maintenant.");
            }
            return $this->redirectToRoute('app_login');
        }

        return $this->render('registration/register.html.twig', [
            'registrationForm' => $form,
        ]);
    }

    private function handleKycUpload(Request $request, User $user, string $uploadDir): void
    {
        $userId = 'user_' . uniqid();

        /** @var UploadedFile|null $file */
        $files = [
            'kyc_identite'         => ['setter' => 'setKycIdentiteUrl',       'type' => 'kyc_identite_type',         'typeSetter' => 'setKycIdentiteType'],
            'kyc_domicile'         => ['setter' => 'setKycDomicileUrl',       'type' => 'kyc_domicile_type',         'typeSetter' => 'setKycDomicileType'],
            'kyc_propriete'        => ['setter' => 'setKycProprieteUrl',      'type' => 'kyc_propriete_type',        'typeSetter' => 'setKycProprieteType'],
            'kyc_rib'              => ['setter' => 'setKycRibUrl',            'type' => null,                        'typeSetter' => null],
            'kyc_assurance'        => ['setter' => 'setKycAssuranceUrl',      'type' => null,                        'typeSetter' => null],
            'kyc_cas_particulier'  => ['setter' => 'setKycCasParticulierUrl', 'type' => 'kyc_cas_particulier_type',  'typeSetter' => 'setKycCasParticulier'],
        ];

        $allDocs = [];
        foreach ($files as $field => $config) {
            $file = $request->files->get($field);
            if ($file instanceof UploadedFile && $file->isValid()) {
                $ext      = $file->guessExtension() ?? 'pdf';
                $filename = $userId . '_' . $field . '.' . $ext;
                $file->move($uploadDir, $filename);
                $url = '/uploads/kyc/' . $filename;

                $setter = $config['setter'];
                $user->$setter($url);
                $allDocs[$field] = $url;
            }

            if ($config['type'] && $config['typeSetter']) {
                $typeVal = $request->request->get($config['type']);
                if ($typeVal) {
                    $typeSetter = $config['typeSetter'];
                    $user->$typeSetter($typeVal);
                }
            }
        }

        // Stocker aussi dans le JSON kyc_documents pour compatibilité
        if (!empty($allDocs)) {
            $user->setKycDocuments(json_encode($allDocs));
        }
    }
}
