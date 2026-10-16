<?php
require dirname(__DIR__, 1) . '/homeconnect/vendor/autoload.php';

use Symfony\Component\HttpClient\HttpClient;
use Symfony\Component\BrowserKit\HttpBrowser;

$browser = new \Symfony\Component\BrowserKit\HttpBrowser(HttpClient::create());

// 1. Get login page (initiates session, gets CSRF token)
$crawler = $browser->request('GET', 'http://localhost:8000/login');
$csrfInput = $crawler->filter('input[name="_csrf_token"]');
$csrf = $csrfInput->count() ? $csrfInput->attr('value') : '';
echo "CSRF from page: [$csrf]\n";

// 2. Submit login form
$crawler = $browser->submitForm('Se connecter', [
    'email'       => 'admin@homeconnect.com',
    'password'    => 'admin123',
    '_csrf_token' => $csrf,
]);

echo "After login URL: " . $browser->getHistory()->current()->getUri() . "\n";
echo "Response status: " . $browser->getInternalResponse()->getStatusCode() . "\n";
echo substr($browser->getInternalResponse()->getContent(), 0, 200) . "\n";
