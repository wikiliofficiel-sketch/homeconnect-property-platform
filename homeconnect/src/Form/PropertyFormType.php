<?php

namespace App\Form;

use App\Entity\Property;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Form\Extension\Core\Type\{TextType, TextareaType, NumberType, IntegerType, CheckboxType, ChoiceType};

class PropertyFormType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            ->add('title', TextType::class, [
                'label' => 'Titre',
                'attr' => ['placeholder' => 'Ex: Appartement 2 pièces près du centre'],
            ])
            ->add('description', TextareaType::class, [
                'label' => 'Description',
                'attr' => ['rows' => 6, 'placeholder' => 'Décrivez votre propriété en détail...'],
            ])
            ->add('address', TextType::class, [
                'label' => 'Adresse',
                'attr' => ['placeholder' => 'Ex: 123 Rue de Paris'],
            ])
            ->add('zipCode', TextType::class, [
                'label' => 'Code Postal',
                'attr' => ['placeholder' => 'Ex: 75001'],
            ])
            ->add('city', TextType::class, [
                'label' => 'Ville',
                'attr' => ['placeholder' => 'Ex: Paris'],
            ])
            ->add('country', TextType::class, [
                'label' => 'Pays',
                'attr' => ['placeholder' => 'Ex: France'],
                'required' => false,
            ])
            ->add('pricePerMonth', NumberType::class, [
                'label' => 'Prix par mois (€)',
                'attr' => ['step' => '0.01', 'min' => '0'],
            ])
            ->add('deposit', NumberType::class, [
                'label' => 'Caution (€)',
                'attr' => ['step' => '0.01', 'min' => '0'],
                'required' => false,
            ])
            ->add('rooms', IntegerType::class, [
                'label' => 'Nombre de pièces',
                'attr' => ['min' => '1'],
            ])
            ->add('bedrooms', IntegerType::class, [
                'label' => 'Nombre de chambres',
                'attr' => ['min' => '1'],
            ])
            ->add('surface', NumberType::class, [
                'label' => 'Surface (m²)',
                'attr' => ['step' => '0.01', 'min' => '0'],
            ])
            ->add('furnished', CheckboxType::class, [
                'label' => 'Meublé',
                'required' => false,
            ])
            ->add('hasParking', CheckboxType::class, [
                'label' => 'Parking disponible',
                'required' => false,
            ])
            ->add('isAvailable', CheckboxType::class, [
                'label' => 'Disponible',
                'required' => false,
            ])
        ;
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setDefaults([
            'data_class' => Property::class,
        ]);
    }
}
