<?php

namespace App\Form;

use App\Entity\User;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\Extension\Core\Type\CheckboxType;
use Symfony\Component\Form\Extension\Core\Type\ChoiceType;
use Symfony\Component\Form\Extension\Core\Type\EmailType;
use Symfony\Component\Form\Extension\Core\Type\HiddenType;
use Symfony\Component\Form\Extension\Core\Type\PasswordType;
use Symfony\Component\Form\Extension\Core\Type\TelType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Validator\Constraints\IsTrue;
use Symfony\Component\Validator\Constraints\Length;
use Symfony\Component\Validator\Constraints\NotBlank;
use Symfony\Component\Validator\Constraints\Regex;

class RegistrationFormType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            // ── Identité ──
            ->add('prenom', TextType::class, [
                'label'       => 'Prénom',
                'attr'        => [
                    'placeholder'  => 'Marie',
                    'autocomplete' => 'given-name',
                ],
                'constraints' => [
                    new NotBlank(message: 'Veuillez saisir votre prénom.'),
                    new Length(
                        min: 2,
                        max: 100,
                        minMessage: 'Le prénom doit contenir au moins {{ limit }} caractères.',
                        maxMessage: 'Le prénom ne peut pas dépasser {{ limit }} caractères.',
                    ),
                ],
            ])

            ->add('nom', TextType::class, [
                'label' => 'Nom',
                'attr'  => [
                    'placeholder'  => 'Tossou',
                    'autocomplete' => 'family-name',
                ],
                'constraints' => [
                    new NotBlank(message: 'Veuillez saisir votre nom.'),
                    new Length(
                        min: 2,
                        max: 100,
                        minMessage: 'Le nom doit contenir au moins {{ limit }} caractères.',
                        maxMessage: 'Le nom ne peut pas dépasser {{ limit }} caractères.',
                    ),
                ],
            ])

            // ── Contact ──
            ->add('email', EmailType::class, [
                'label' => 'Adresse email',
                'attr'  => [
                    'placeholder'  => 'votre@email.com',
                    'autocomplete' => 'email',
                ],
                'constraints' => [
                    new NotBlank(message: 'Veuillez saisir votre adresse email.'),
                ],
            ])

            ->add('telephone', TelType::class, [
                'label'    => 'Téléphone',
                'required' => false,
                'attr'     => [
                    'placeholder'  => '+229 97 00 00 00',
                    'autocomplete' => 'tel',
                ],
                'constraints' => [
                    new Regex(
                        pattern: '/^[\+0-9\s\-]{8,20}$/',
                        message: 'Numéro de téléphone invalide.',
                    ),
                ],
            ])

            // ── Localisation ──
            ->add('ville', ChoiceType::class, [
                'label'       => 'Ville',
                'required'    => false,
                'placeholder' => 'Sélectionnez votre ville',
                'choices'     => [
                    'Cotonou'       => 'cotonou',
                    'Porto-Novo'    => 'porto-novo',
                    'Parakou'       => 'parakou',
                    'Abomey-Calavi' => 'abomey-calavi',
                    'Bohicon'       => 'bohicon',
                    'Natitingou'    => 'natitingou',
                    'Djougou'       => 'djougou',
                    'Lokossa'       => 'lokossa',
                    'Ouidah'        => 'ouidah',
                    'Autre'         => 'autre',
                ],
            ])

            // ── Rôle (non mappé, géré dans le controller) ──
            ->add('role', HiddenType::class, [
                'mapped' => false,
                'data'   => null,
            ])

            // ── Sécurité ──
            ->add('plainPassword', PasswordType::class, [
                'label'  => 'Mot de passe',
                'mapped' => false,
                'attr'   => [
                    'placeholder'  => 'Min. 6 caractères',
                    'autocomplete' => 'new-password',
                    'id'           => 'reg_password',
                ],
                'constraints' => [
                    new NotBlank(message: 'Veuillez saisir un mot de passe.'),
                    new Length(
                        min: 6,
                        max: 4096,
                        minMessage: 'Votre mot de passe doit contenir au moins {{ limit }} caractères.',
                    ),
                ],
            ])

            // ── CGU (non mappé) ──
            ->add('agreeTerms', CheckboxType::class, [
                'label'  => false,
                'mapped' => false,
                'constraints' => [
                    new IsTrue(message: 'Vous devez accepter les conditions d\'utilisation.'),
                ],
            ])
        ;
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setDefaults([
            'data_class' => User::class,
        ]);
    }
}