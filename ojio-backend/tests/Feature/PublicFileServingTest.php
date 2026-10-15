<?php

namespace Tests\Feature;

use Illuminate\Filesystem\Filesystem;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\Process\Process;
use Tests\TestCase;

class PublicFileServingTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directory = sys_get_temp_dir().DIRECTORY_SEPARATOR.'ojio-public-serving-'.bin2hex(random_bytes(8));
        $files = new Filesystem;
        foreach (['public/assets', 'public/downloads', 'storage/app/public/listings/nested', 'storage/app/private', 'app/Support'] as $path) {
            $files->ensureDirectoryExists($this->directory.'/'.$path);
        }
        $files->copy(base_path('server.php'), $this->directory.'/server.php');
        $files->copy(app_path('Support/PublicFilePath.php'), $this->directory.'/app/Support/PublicFilePath.php');
        $files->put($this->directory.'/public/index.php', '<?php echo "front-controller";');
        $files->put($this->directory.'/public/app-ads.txt', 'public-admob-entry');
        $files->put($this->directory.'/public/assets/logo.png', 'public-logo');
        $files->put($this->directory.'/public/assets/a+b.css', 'public-style');
        $files->put($this->directory.'/public/downloads/client.apk', 'public-apk');
        $files->put($this->directory.'/public/.env', 'hidden-fixture');
        $files->put($this->directory.'/composer.json', '{"private_fixture":true}');
        $files->put($this->directory.'/storage/app/private/secret.json', '{"private_fixture":true}');
        $files->put($this->directory.'/storage/app/public/listings/nested/photo.webp', 'public-upload');
        $files->put($this->directory.'/storage/app/public/listings/script.php', '<?php echo "must-not-serve-source";');
        $files->put($this->directory.'/storage/app/public/listings/.hidden.json', 'hidden-upload');
    }

    protected function tearDown(): void
    {
        if (isset($this->directory) && str_starts_with($this->directory, sys_get_temp_dir().DIRECTORY_SEPARATOR.'ojio-public-serving-')) {
            (new Filesystem)->deleteDirectory($this->directory);
        }
        parent::tearDown();
    }

    public function test_router_preserves_assets_uploads_apk_and_front_controller_dispatch(): void
    {
        foreach ([
            '/app-ads.txt' => 'public-admob-entry',
            '/assets/logo.png' => 'public-logo',
            '/assets/a+b.css' => 'public-style',
            '/assets/a%2Bb.css?version=1' => 'public-style',
            '/downloads/client.apk' => 'public-apk',
            '/storage/listings/nested/photo.webp' => 'public-upload',
            '/api/v1/categories' => 'front-controller',
            '/index.php' => 'front-controller',
        ] as $uri => $body) {
            $response = $this->routerResponse($uri);
            $this->assertSame(200, $response['status'], $uri);
            $this->assertSame($body, $response['body'], $uri);
        }
    }

    public function test_router_rejects_encoded_traversal_hidden_files_and_scripts(): void
    {
        foreach ([
            '/../composer.json', '/%2e%2e/composer.json', '/%252e%252e/composer.json',
            '/storage/%2e%2e/%2e%2e/%2e%2e/composer.json',
            '/storage/../private/secret.json', '/storage/%2e%2e/private/secret.json',
            '/assets/%5c..%5ccomposer.json', '/assets/%00logo.png',
            '/.env', '/storage/listings/.hidden.json', '/storage/listings/script.php',
        ] as $uri) {
            $response = $this->routerResponse($uri);
            $this->assertSame(404, $response['status'], $uri);
            $this->assertSame('', $response['body'], $uri);
        }
    }

    public function test_static_head_requests_return_no_body(): void
    {
        $response = $this->routerResponse('/app-ads.txt', 'HEAD');
        $this->assertSame(['status' => 200, 'body' => ''], $response);
    }

    public function test_storage_fallback_serves_only_public_uploads(): void
    {
        $this->app->useStoragePath($this->directory.'/storage');
        config(['filesystems.disks.public.root' => $this->directory.'/storage/app/public']);
        $response = $this->get('/storage/listings/nested/photo.webp')->assertOk();
        $this->assertInstanceOf(BinaryFileResponse::class, $response->baseResponse);
        $this->assertSame(realpath($this->directory.'/storage/app/public/listings/nested/photo.webp'), $response->baseResponse->getFile()->getRealPath());

        foreach ([
            '/storage/%2e%2e/private/secret.json',
            '/storage/listings/%2e%2e/%2e%2e/private/secret.json',
            '/storage/listings/.hidden.json', '/storage/listings/script.php',
            '/storage/listings/missing.webp',
        ] as $uri) {
            $this->get($uri)->assertNotFound();
        }
    }

    /** @return array{status: int, body: string} */
    private function routerResponse(string $uri, string $method = 'GET'): array
    {
        $bootstrap = <<<'PHP'
$_SERVER['REQUEST_URI'] = $argv[1];
$_SERVER['REQUEST_METHOD'] = $argv[2];
http_response_code(200);
register_shutdown_function(static function (): void {
    fwrite(STDERR, json_encode(['status' => http_response_code()], JSON_THROW_ON_ERROR));
});
require $argv[3];
PHP;
        $process = new Process([PHP_BINARY, '-r', $bootstrap, $uri, $method, $this->directory.'/server.php'], $this->directory);
        $process->mustRun();
        $status = json_decode($process->getErrorOutput(), true, 512, JSON_THROW_ON_ERROR);

        return ['status' => $status['status'], 'body' => $process->getOutput()];
    }
}
