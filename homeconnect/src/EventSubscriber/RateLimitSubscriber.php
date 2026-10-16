<?php

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;
use Symfony\Contracts\Cache\CacheInterface;
use Symfony\Contracts\Cache\ItemInterface;

class RateLimitSubscriber implements EventSubscriberInterface
{
    // [max_attempts, window_seconds]
    private const RULES = [
        'login'    => [5,  900],
        'register' => [3,  3600],
        'api'      => [60, 60],
    ];

    public function __construct(private CacheInterface $cache) {}

    public static function getSubscribedEvents(): array
    {
        return [KernelEvents::REQUEST => ['onRequest', 10]];
    }

    public function onRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) return;

        $request = $event->getRequest();
        $path    = $request->getPathInfo();
        $method  = $request->getMethod();
        $ip      = preg_replace('/[^a-zA-Z0-9\._]/', '_', $request->getClientIp() ?? 'unknown');
        $isApi   = str_starts_with($path, '/api/');

        // Login
        if (in_array($path, ['/login', '/api/login_check']) && $method === 'POST') {
            if ($r = $this->check("rl_login_{$ip}", 'login', $isApi)) {
                $event->setResponse($r);
            }
            return;
        }

        // Inscription
        if (in_array($path, ['/register', '/api/register']) && $method === 'POST') {
            if ($r = $this->check("rl_register_{$ip}", 'register', $isApi)) {
                $event->setResponse($r);
            }
            return;
        }

        // API mutations
        if ($isApi && !in_array($method, ['GET', 'OPTIONS', 'HEAD'])) {
            $token = substr(md5($request->headers->get('Authorization', $ip)), 0, 12);
            if ($r = $this->check("rl_api_{$token}", 'api', true)) {
                $event->setResponse($r);
            }
        }
    }

    private function check(string $key, string $rule, bool $isApi): ?Response
    {
        [$max, $window] = self::RULES[$rule];

        // Lire le compteur depuis le cache
        $data = $this->cache->get($key, function (ItemInterface $item) use ($window): array {
            $item->expiresAfter($window);
            return ['count' => 0, 'reset_at' => time() + $window];
        });

        // Incrémenter et réécrire
        $data['count']++;
        $this->cache->delete($key);
        $this->cache->get($key, function (ItemInterface $item) use ($data): array {
            $item->expiresAfter(max(1, $data['reset_at'] - time()));
            return $data;
        });

        if ($data['count'] <= $max) {
            return null;
        }

        $retryAfter = max(1, $data['reset_at'] - time());
        $message = match ($rule) {
            'login'    => sprintf('Trop de tentatives de connexion. Réessayez dans %d min.', ceil($retryAfter / 60)),
            'register' => 'Trop de tentatives d\'inscription. Réessayez dans 1 heure.',
            default    => sprintf('Limite de requêtes dépassée. Réessayez dans %ds.', $retryAfter),
        };

        if ($isApi) {
            return new JsonResponse(
                ['error' => $message, 'retry_after' => $retryAfter],
                Response::HTTP_TOO_MANY_REQUESTS,
                ['Retry-After' => (string) $retryAfter]
            );
        }

        return new Response(
            sprintf('<html><body><h2>Trop de requêtes</h2><p>%s</p><a href="/login">Retour</a></body></html>', htmlspecialchars($message)),
            Response::HTTP_TOO_MANY_REQUESTS,
            ['Retry-After' => (string) $retryAfter, 'Content-Type' => 'text/html']
        );
    }
}
