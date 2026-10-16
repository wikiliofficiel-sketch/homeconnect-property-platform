<?php

namespace App\Service;

use FedaPay\FedaPay;
use FedaPay\Transaction;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;

class FedaPayService
{
    private $params;

    public function __construct(ParameterBagInterface $params)
    {
        $this->params = $params;
        
        FedaPay::setApiKey($this->params->get('FEDAPAY_API_KEY') ?: $_ENV['FEDAPAY_API_KEY']);
        FedaPay::setEnvironment($this->params->get('FEDAPAY_ENVIRONMENT') ?: $_ENV['FEDAPAY_ENVIRONMENT']);
    }

    /**
     * Crée une transaction et retourne le lien de paiement
     */
    public function createPayment(float $amount, string $description, array $customerData): string
    {
        $transaction = Transaction::create([
            'description' => $description,
            'amount' => (int) $amount,
            'currency' => ['iso' => 'XOF'],
            'callback_url' => $customerData['callback_url'] ?? null,
            'customer' => [
                'firstname' => $customerData['firstname'],
                'lastname' => $customerData['lastname'],
                'email' => $customerData['email'],
                'phone_number' => [
                    'number' => $customerData['phone'],
                    'country' => 'bj'
                ]
            ],
            'custom_metadata' => $customerData['metadata'] ?? []
        ]);

        $token = $transaction->generateToken();
        
        return $token->url;
    }
}
