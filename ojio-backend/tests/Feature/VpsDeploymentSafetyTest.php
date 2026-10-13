<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\AdminUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Symfony\Component\Yaml\Yaml;
use Tests\TestCase;

class VpsDeploymentSafetyTest extends TestCase
{
    use RefreshDatabase;

    public function test_existing_admin_password_is_never_reset_by_seeding(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'password' => Hash::make('ExistingStrongPassword123!')]);
        $originalHash = $admin->password;
        $this->seed(AdminUserSeeder::class);

        $this->assertSame($originalHash, $admin->fresh()->password);
        $this->assertDatabaseCount('users', 1);
    }

    public function test_admin_creation_requires_explicit_private_credentials(): void
    {
        config()->set('services.admin_bootstrap', ['name' => 'Admin', 'email' => null, 'phone' => null, 'password' => null, 'city' => null]);

        try {
            $this->seed(AdminUserSeeder::class);
            $this->fail('Seeding must reject missing admin credentials.');
        } catch (ValidationException $exception) {
            $this->assertArrayHasKey('email', $exception->errors());
            $this->assertArrayHasKey('password', $exception->errors());
        }

        $this->assertDatabaseCount('users', 0);
    }

    public function test_admin_is_created_using_configured_credentials_only(): void
    {
        config()->set('services.admin_bootstrap', [
            'name' => 'Client Admin', 'email' => 'client-admin@example.com',
            'phone' => '+919123456789', 'password' => 'PrivateBootstrapPassword123!', 'city' => 'Kolkata',
        ]);
        $this->seed(AdminUserSeeder::class);
        $admin = User::where('role', 'admin')->sole();

        $this->assertSame('client-admin@example.com', $admin->email);
        $this->assertTrue(Hash::check('PrivateBootstrapPassword123!', $admin->password));
        $this->assertNotSame('PrivateBootstrapPassword123!', $admin->password);
    }

    public function test_encryption_key_has_no_embedded_fallback(): void
    {
        $source = file_get_contents(config_path('app.php'));
        $this->assertStringContainsString("'key' => env('APP_KEY'),", $source);
        $this->assertStringNotContainsString("env('APP_KEY',", $source);
    }

    public function test_database_configuration_contains_no_remote_or_password_fallbacks(): void
    {
        $source = file_get_contents(config_path('database.php'));
        $this->assertSame(4, substr_count($source, "env('DB_PASSWORD', '')"));
        $this->assertStringNotContainsString('rlwy.net', $source);
        $this->assertStringNotContainsString('57165', $source);
    }

    public function test_vps_build_excludes_secrets_and_serves_only_public_files(): void
    {
        $ignore = file_get_contents(base_path('Dockerfile.vps.dockerignore'));
        foreach (['.env', '.env.*', '.vps-*', 'storage', '*firebase-adminsdk*.json'] as $pattern) {
            $this->assertContains($pattern, explode("\n", str_replace("\r", '', $ignore)));
        }

        $dockerfile = file_get_contents(base_path('Dockerfile.vps'));
        $this->assertStringContainsString('php:8.4-fpm-', $dockerfile);
        $this->assertStringContainsString('USER www-data', $dockerfile);
        $this->assertStringNotContainsString('chmod -R 777', $dockerfile);
        $this->assertStringNotContainsString('php -S', $dockerfile);

        $nginx = file_get_contents(base_path('nginx.vps.conf'));
        $this->assertStringContainsString('root /var/www/html/public;', $nginx);
        $this->assertStringContainsString('location = /index.php', $nginx);
        $this->assertStringContainsString('deny all;', $nginx);
    }

    public function test_vps_startup_has_no_automatic_financial_data_mutations_or_public_database(): void
    {
        $entrypoint = file_get_contents(base_path('vps-entrypoint.sh'));
        $this->assertStringContainsString('if [ -z "${APP_KEY:-}" ]', $entrypoint);
        $this->assertDoesNotMatchRegularExpression('/php artisan (migrate|db:seed|key:generate)/', $entrypoint);

        $compose = file_get_contents(base_path('compose.vps.yaml'));
        $services = Yaml::parse($compose)['services'];
        $this->assertArrayNotHasKey('ports', $services['db']);
        $this->assertArrayNotHasKey('ports', $services['app']);
        $this->assertArrayNotHasKey('ports', $services['worker']);
        $this->assertArrayNotHasKey('ports', $services['scheduler']);
        $this->assertSame(['80:80'], $services['web']['ports']);
        $this->assertStringNotContainsString('3306:3306', $compose);
        $this->assertStringNotContainsString('9000:9000', $compose);
        $this->assertStringContainsString('mysql-data:/var/lib/mysql', $compose);
        $this->assertStringContainsString('--queue=push,default', $compose);
        $this->assertStringContainsString('schedule:work', $compose);
        $this->assertStringContainsString('profiles: ["workers"]', $compose);

        $environment = file_get_contents(base_path('.env.vps.example'));
        $this->assertStringContainsString('APP_DEBUG=false', $environment);
        $this->assertStringContainsString('FCM_ENABLED=false', $environment);
        $this->assertStringContainsString("DB_PASSWORD=\n", $environment);
    }

    public function test_fcm_overlay_mounts_private_credentials_only_in_app_and_worker(): void
    {
        $overlay = Yaml::parseFile(base_path('compose.fcm.yaml'));
        $this->assertSame(['app', 'worker'], array_keys($overlay['services']));

        foreach ($overlay['services'] as $service) {
            $this->assertSame(['firebase_service_account'], $service['secrets']);
            $this->assertSame('/run/secrets/firebase_service_account', $service['environment']['GOOGLE_APPLICATION_CREDENTIALS']);
            $this->assertSame('', $service['environment']['FCM_SERVICE_ACCOUNT_JSON']);
            $this->assertArrayNotHasKey('FCM_ENABLED', $service['environment']);
        }

        $this->assertSame(
            '${FCM_SERVICE_ACCOUNT_FILE:?Set the private JSON host path in .env.vps}',
            $overlay['secrets']['firebase_service_account']['file'],
        );
        $this->assertStringNotContainsString('PRIVATE KEY', file_get_contents(base_path('compose.fcm.yaml')));
        $this->assertStringContainsString('FCM_ENABLED=false', file_get_contents(base_path('.env.vps.example')));
    }

    public function test_admob_authorized_seller_file_matches_the_client_publisher(): void
    {
        $this->assertSame(
            'google.com, pub-9962423610902602, DIRECT, f08c47fec0942fa0',
            trim(file_get_contents(public_path('app-ads.txt'))),
        );
    }
}
