<?php
chdir('d:/magni/homeconnect');
require 'd:/magni/homeconnect/vendor/autoload.php';

// Load .env
$dotenv = new \Symfony\Component\Dotenv\Dotenv();
$dotenv->loadEnv('d:/magni/homeconnect/.env');
if (file_exists('d:/magni/homeconnect/.env.local')) {
    $dotenv->load('d:/magni/homeconnect/.env.local');
}

use Symfony\Component\HttpFoundation\Request;
use App\Kernel;

$_SERVER['APP_ENV'] = 'dev';
$_SERVER['APP_DEBUG'] = '1';
$_SERVER['DOCUMENT_ROOT'] = 'd:/magni/homeconnect/public';

$kernel = new Kernel('dev', true);
$kernel->boot();
$em = $kernel->getContainer()->get('doctrine')->getManager();

// Trouver les utilisateurs pour chaque rôle
$users = $em->createQuery('SELECT u FROM App\Entity\User u')->getResult();
$adminUser = $propUser = $locUser = null;
foreach ($users as $u) {
    $roles = $u->getRoles();
    if (!$adminUser && in_array('ROLE_ADMIN', $roles)) $adminUser = $u;
    if (!$propUser && in_array('ROLE_PROPRIETAIRE', $roles)) $propUser = $u;
    if (!$locUser && in_array('ROLE_LOCATAIRE', $roles)) $locUser = $u;
}

echo "Admin: " . ($adminUser?->getEmail() ?? 'N/A') . "\n";
echo "Proprio: " . ($propUser?->getEmail() ?? 'N/A') . "\n";
echo "Locataire: " . ($locUser?->getEmail() ?? 'N/A') . "\n\n";

function doRequest(Kernel $kernel, string $method, string $uri, $user = null, array $post = []): array {
    $server = [
        'HTTP_HOST'   => 'localhost',
        'SERVER_NAME' => 'localhost',
        'SERVER_PORT' => '80',
        'HTTPS'       => 'off',
    ];

    if ($user) {
        $token = new \Symfony\Component\Security\Core\Authentication\Token\UsernamePasswordToken(
            $user, 'main', $user->getRoles()
        );
        $sessionFactory = $kernel->getContainer()->get('session.factory');
        $session = $sessionFactory->createSession();
        $session->set('_security_main', serialize($token));
        $session->save();
        $server['HTTP_COOKIE'] = ini_get('session.name') . '=' . $session->getId();
    }

    $request = Request::create($uri, $method, $post, [], [], $server);
    if ($user) {
        $session = $kernel->getContainer()->get('session.factory')->createSession();
        $session->set('_security_main', serialize(
            new \Symfony\Component\Security\Core\Authentication\Token\UsernamePasswordToken(
                $user, 'main', $user->getRoles()
            )
        ));
        $request->setSession($session);
    }

    try {
        $resp = $kernel->handle($request);
        $kernel->terminate($request, $resp);
        $code = $resp->getStatusCode();
        $body = $resp->getContent();
        // Détecter les erreurs Symfony dans le HTML
        $hasError = str_contains($body, 'Uncaught') || str_contains($body, 'Exception') ||
                    str_contains($body, 'Error:') || ($code === 500);
        return ['code' => $code, 'body' => substr($body, 0, 300), 'error' => $hasError];
    } catch (\Throwable $e) {
        return ['code' => 500, 'body' => $e->getMessage(), 'error' => true];
    }
}

function printResult(array $r, string $label, string $uri): void {
    $code = $r['code'];
    if ($code === 200) $icon = '✅';
    elseif ($code >= 301 && $code <= 303) $icon = '↩️ ';
    elseif ($r['error']) $icon = '❌';
    else $icon = '⚠️ ';

    echo "$icon [$code] $label\n";
    if ($r['error'] || $code === 500) {
        echo "     └─ " . substr($r['body'], 0, 150) . "\n";
    }
}

// ═══════════════════════════════════════════════
echo "╔══════════════════════════════╗\n";
echo "║  PAGES PUBLIQUES             ║\n";
echo "╚══════════════════════════════╝\n";
foreach ([
    ['GET', '/',         'Accueil'],
    ['GET', '/login',    'Page Login'],
    ['GET', '/register', 'Inscription'],
] as [$m, $u, $l]) {
    printResult(doRequest($kernel, $m, $u), $l, $u);
}

// ═══════════════════════════════════════════════
echo "\n╔══════════════════════════════╗\n";
echo "║  ADMIN                       ║\n";
echo "╚══════════════════════════════╝\n";
$adminPages = [
    ['GET',  '/admin/',                       'Dashboard'],
    ['GET',  '/admin/properties/',            'Liste biens'],
    ['GET',  '/admin/users/',                 'Liste utilisateurs'],
    ['GET',  '/admin/kyc/',                   'KYC dashboard'],
    ['GET',  '/admin/messages/',              'Messages'],
    ['GET',  '/admin/logs/',                  'Logs activité'],
    ['GET',  '/admin/subscriptions/',         'Abonnements'],
    ['GET',  '/admin/reports/',               'Signalements'],
    ['GET',  '/admin/commissions/',           'Commissions'],
    ['GET',  '/admin/config/',                'Configuration'],
    ['GET',  '/admin/partners/',              'Partenaires'],
    ['POST', '/admin/properties/27/approve',  'Approuver bien'],
    ['POST', '/admin/properties/28/suspend',  'Suspendre bien'],
    ['POST', '/admin/users/16/toggle-verify', 'Toggle verify user'],
];
foreach ($adminPages as [$m, $u, $l]) {
    printResult(doRequest($kernel, $m, $u, $adminUser), $l, $u);
}

// ═══════════════════════════════════════════════
echo "\n╔══════════════════════════════╗\n";
echo "║  PROPRIÉTAIRE                ║\n";
echo "╚══════════════════════════════╝\n";
if ($propUser) {
    // Trouver les routes propriétaire
    $router = $kernel->getContainer()->get('router');
    $routes = $router->getRouteCollection()->all();
    $ownerRoutes = [];
    foreach ($routes as $name => $route) {
        if (str_contains($name, 'owner') || str_contains($route->getPath(), '/proprietary') || str_contains($route->getPath(), '/owner')) {
            $path = $route->getPath();
            if (!str_contains($path, '{') ) {
                $ownerRoutes[$path] = $name;
            }
        }
    }

    $ownerPages = [
        ['GET', '/proprietary/dashboard',    'Dashboard'],
        ['GET', '/proprietary/properties',   'Mes biens'],
        ['GET', '/proprietary/applications', 'Candidatures'],
        ['GET', '/proprietary/subscription', 'Abonnement'],
        ['GET', '/proprietary/contracts',    'Contrats'],
        ['GET', '/proprietary/messages',     'Messages'],
    ];
    foreach ($ownerPages as [$m, $u, $l]) {
        printResult(doRequest($kernel, $m, $u, $propUser), $l, $u);
    }
} else {
    echo "⚠️  Aucun propriétaire trouvé en DB\n";
}

// ═══════════════════════════════════════════════
echo "\n╔══════════════════════════════╗\n";
echo "║  LOCATAIRE                   ║\n";
echo "╚══════════════════════════════╝\n";
if ($locUser) {
    $tenantPages = [
        ['GET', '/locataire/dashboard',    'Dashboard'],
        ['GET', '/locataire/search',       'Recherche biens'],
        ['GET', '/locataire/applications', 'Mes candidatures'],
        ['GET', '/locataire/messages',     'Messages'],
        ['GET', '/locataire/profile',      'Profil'],
    ];
    foreach ($tenantPages as [$m, $u, $l]) {
        printResult(doRequest($kernel, $m, $u, $locUser), $l, $u);
    }
} else {
    echo "⚠️  Aucun locataire trouvé en DB\n";
}

echo "\n✅ Tests terminés\n";
