<?php

/**
 * Laravel - A PHP Framework For Web Artisans
 *
 * Emulates Apache mod_rewrite / Nginx try_files with PHP built-in web server.
 * Accurately serves static files (images, CSS, JS, APK) directly from /public directory.
 */

$publicPath = __DIR__ . '/public';

$uri = urldecode(
    parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? ''
);

$filePath = $publicPath . $uri;

// If file exists directly in public/ (images, CSS, JS, APK download), serve it as static file
if ($uri !== '/' && is_file($filePath)) {
    $mimeTypes = [
        'png'   => 'image/png',
        'jpg'   => 'image/jpeg',
        'jpeg'  => 'image/jpeg',
        'gif'   => 'image/gif',
        'svg'   => 'image/svg+xml',
        'webp'  => 'image/webp',
        'ico'   => 'image/x-icon',
        'css'   => 'text/css',
        'js'    => 'application/javascript',
        'json'  => 'application/json',
        'apk'   => 'application/vnd.android.package-archive',
        'pdf'   => 'application/pdf',
        'woff'  => 'font/woff',
        'woff2' => 'font/woff2',
        'ttf'   => 'font/ttf',
    ];
    $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
    $mime = $mimeTypes[$ext] ?? 'application/octet-stream';
    header('Content-Type: ' . $mime);
    header('Content-Length: ' . filesize($filePath));
    header('Cache-Control: public, max-age=86400');
    readfile($filePath);
    exit;
}

require_once $publicPath . '/index.php';
