<?php

namespace App\Support;

final class PublicFilePath
{
    private const MIME_TYPES = [
        'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif', 'svg' => 'image/svg+xml', 'webp' => 'image/webp',
        'avif' => 'image/avif', 'ico' => 'image/x-icon', 'css' => 'text/css',
        'js' => 'application/javascript', 'json' => 'application/json',
        'apk' => 'application/vnd.android.package-archive', 'pdf' => 'application/pdf',
        'woff' => 'font/woff', 'woff2' => 'font/woff2', 'ttf' => 'font/ttf',
        'otf' => 'font/otf', 'txt' => 'text/plain', 'xml' => 'application/xml',
    ];

    public static function isSafeRelativePath(string $path): bool
    {
        if (str_starts_with($path, '/') || str_contains($path, '\\')
            || preg_match('/[\x00-\x1F\x7F:]/', $path) || preg_match('/%[0-9a-f]{2}/i', $path)) {
            return false;
        }

        foreach (explode('/', $path) as $segment) {
            if (str_starts_with($segment, '.')) {
                return false;
            }
        }

        return true;
    }

    public static function resolve(string $root, string $relativePath): ?string
    {
        if (! self::isSafeRelativePath($relativePath) || self::mimeType($relativePath) === null) {
            return null;
        }

        $root = realpath($root);
        if ($root === false) {
            return null;
        }

        $candidate = realpath($root.DIRECTORY_SEPARATOR.$relativePath);
        if ($candidate === false || ! is_file($candidate) || self::mimeType($candidate) === null) {
            return null;
        }

        $prefix = rtrim($root, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR;
        $withinRoot = PHP_OS_FAMILY === 'Windows'
            ? strncasecmp($candidate, $prefix, strlen($prefix)) === 0
            : str_starts_with($candidate, $prefix);

        if (! $withinRoot || ! self::isSafeRelativePath(str_replace(DIRECTORY_SEPARATOR, '/', substr($candidate, strlen($prefix))))) {
            return null;
        }

        return $candidate;
    }

    public static function mimeType(string $path): ?string
    {
        return self::MIME_TYPES[strtolower(pathinfo($path, PATHINFO_EXTENSION))] ?? null;
    }
}
