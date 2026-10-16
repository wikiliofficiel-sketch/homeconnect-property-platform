<?php

namespace App\Twig;

use Twig\Extension\AbstractExtension;
use Twig\TwigFilter;
use Twig\TwigFunction;

class AppExtension extends AbstractExtension
{
    public function getFilters(): array
    {
        return [
            new TwigFilter('json_decode', [$this, 'jsonDecode']),
            new TwigFilter('min', fn($arr) => min((array) $arr)),
            new TwigFilter('max', fn($arr) => max((array) $arr)),
        ];
    }

    public function getFunctions(): array
    {
        return [
            new TwigFunction('min', fn(...$args) => min(...$args)),
            new TwigFunction('max', fn(...$args) => max(...$args)),
        ];
    }

    public function jsonDecode(mixed $value): mixed
    {
        if (is_array($value)) return $value;
        if (empty($value)) return [];
        $decoded = json_decode((string) $value, true);
        return is_array($decoded) ? $decoded : [];
    }
}
