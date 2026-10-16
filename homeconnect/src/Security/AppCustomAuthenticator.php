<?php

namespace App\Security;

use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Generator\UrlGeneratorInterface;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Http\Authenticator\AbstractLoginFormAuthenticator;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\CsrfTokenBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\RememberMeBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;
use Symfony\Component\Security\Http\Authenticator\Passport\Credentials\PasswordCredentials;
use Symfony\Component\Security\Http\Authenticator\Passport\Passport;
use Symfony\Component\Security\Http\SecurityRequestAttributes;
use Symfony\Component\Security\Http\Util\TargetPathTrait;
use Symfony\Component\HttpFoundation\JsonResponse;
class AppCustomAuthenticator extends AbstractLoginFormAuthenticator
{
    use TargetPathTrait;

    public const LOGIN_ROUTE = 'app_login';

    public function __construct(
        private UrlGeneratorInterface $urlGenerator,
        private \Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface $jwtManager
    )
    {
    }

    public function authenticate(Request $request): Passport
    {
        // Support both form-encoded and JSON login payloads
        $payload = $request->getContent();
        $data = [];
        if (0 !== strpos($request->headers->get('Content-Type') ?? '', 'application/json')) {
            // Form data
            $data['email'] = $request->request->get('email');
            $data['password'] = $request->request->get('password');
            $data['_csrf_token'] = $request->request->get('_csrf_token');
        } else {
            // JSON payload
            $data = json_decode($payload, true) ?? [];
        }

        $email = $data['email'] ?? '';
        $password = $data['password'] ?? '';
        $csrfToken = $data['_csrf_token'] ?? '';

        $request->getSession()->set(SecurityRequestAttributes::LAST_USERNAME, $email);

        $badges = [
            new RememberMeBadge(),
        ];

        // Add CSRF badge only for form-encoded requests (web)
        if (0 !== strpos($request->headers->get('Content-Type') ?? '', 'application/json')) {
            $badges[] = new CsrfTokenBadge('authenticate', $csrfToken);
        }

        return new Passport(
            new UserBadge($email),
            new PasswordCredentials($password),
            $badges
        );
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token, string $firewallName): ?Response
    {
        // Si la requête provient d'une API (Accept: application/json), on renvoie le JWT
        if (0 === strpos($request->headers->get('Accept') ?? '', 'application/json')) {
            $user = $token->getUser();
            $jwt = $this->jwtManager->create($user);
            return new JsonResponse(['token' => $jwt]);
        }

        // Sinon, comportement de redirection pour les requêtes web classiques
        $user = $token->getUser();
        $roles = $user->getRoles();

        if (in_array('ROLE_ADMIN', $roles)) {
            return new RedirectResponse($this->urlGenerator->generate('admin_dashboard'));
        }

        if (in_array('ROLE_LOCATAIRE', $roles)) {
            return new RedirectResponse($this->urlGenerator->generate('app_tenant_dashboard'));
        }

        if (in_array('ROLE_PROPRIETAIRE', $roles)) {
            return new RedirectResponse($this->urlGenerator->generate('app_owner_dashboard'));
        }

        return new RedirectResponse($this->urlGenerator->generate('app_home'));
    }

    protected function getLoginUrl(Request $request): string
    {
        return $this->urlGenerator->generate(self::LOGIN_ROUTE);
    }
}
