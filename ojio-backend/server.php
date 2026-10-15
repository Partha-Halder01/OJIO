<?php

use App\Support\PublicFilePath;

/**
 * Laravel - A PHP Framework For Web Artisans
 *
 * Emulates Apache mod_rewrite / Nginx try_files with PHP built-in web server.
 * Accurately serves static files (images, CSS, JS, APK) directly from /public directory.
 */

require_once __DIR__.'/app/Support/PublicFilePath.php';

$publicPath = __DIR__.'/public';
$requestPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
if (! is_string($requestPath) || ! str_starts_with($requestPath, '/')) {
    http_response_code(404);
    exit;
}

$relativePath = substr(rawurldecode($requestPath), 1);
if (! PublicFilePath::isSafeRelativePath($relativePath)) {
    http_response_code(404);
    exit;
}

$isUpload = str_starts_with($relativePath, 'storage/');
$filePath = $isUpload
    ? PublicFilePath::resolve(__DIR__.'/storage/app/public', substr($relativePath, 8))
    : PublicFilePath::resolve($publicPath, $relativePath);

if ($filePath !== null) {
    header('Content-Type: '.PublicFilePath::mimeType($filePath));
    header('Content-Length: '.filesize($filePath));
    header('Cache-Control: public, max-age=86400');
    header('X-Content-Type-Options: nosniff');
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'HEAD') {
        exit;
    }
    readfile($filePath);
    exit;
}

if ($isUpload) {
    http_response_code(404);
    exit;
}

require_once $publicPath.'/index.php';
