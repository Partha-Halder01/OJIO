<?php

namespace Tests\Feature;

use App\Models\PushDevice;
use Illuminate\Contracts\Foundation\MaintenanceMode;
use Illuminate\Encryption\Encrypter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class ReencryptPushDeviceTokensTest extends TestCase
{
    use RefreshDatabase;

    private string $oldKey;

    private string $newKey;

    protected function setUp(): void
    {
        parent::setUp();
        $this->oldKey = Encrypter::generateKey('AES-256-CBC');
        $this->newKey = Encrypter::generateKey('AES-256-CBC');
        $this->useKeys($this->oldKey);
        $this->maintenance(false);
        Http::preventStrayRequests();
        Queue::fake();
    }

    public function test_default_mode_is_read_only_even_in_maintenance(): void
    {
        PushDevice::factory()->count(3)->create();
        $before = $this->rows();
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->maintenance(true);

        $this->artisan('security:reencrypt-push-tokens')
            ->expectsOutput('Total tokens: 3')
            ->expectsOutput('Previous-key tokens: 3')
            ->expectsOutput('Invalid tokens: 0')
            ->assertSuccessful();

        $this->assertSame($before, $this->rows());
        Queue::assertNothingPushed();
    }

    public function test_apply_refuses_to_run_while_the_app_is_live(): void
    {
        PushDevice::factory()->create();
        $before = $this->rows();
        $this->useKeys($this->newKey, [$this->oldKey]);

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])
            ->expectsOutput('Applying requires maintenance mode. No tokens were changed.')
            ->assertFailed();

        $this->assertSame($before, $this->rows());
    }

    public function test_apply_requires_previous_keys_and_a_different_current_key(): void
    {
        PushDevice::factory()->create();
        $before = $this->rows();
        $this->maintenance(true);

        foreach ([[], [$this->oldKey]] as $previous) {
            $this->useKeys($this->oldKey, $previous);
            $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])
                ->expectsOutput('Configure a new APP_KEY and distinct APP_PREVIOUS_KEYS before applying. No tokens were changed.')
                ->assertFailed();
            $this->assertSame($before, $this->rows());
        }
    }

    public function test_apply_preserves_tokens_metadata_and_other_records_and_is_idempotent(): void
    {
        PushDevice::factory()->count(2)->create();
        $olderKey = Encrypter::generateKey('AES-256-CBC');
        $this->useKeys($olderKey);
        PushDevice::factory()->create();
        $this->useKeys($this->newKey, [$this->oldKey, $olderKey]);
        PushDevice::factory()->create();
        $before = $this->rows();
        $usersBefore = DB::table('users')->orderBy('id')->get()->toJson();
        $plaintext = PushDevice::all()->mapWithKeys(fn (PushDevice $device): array => [$device->id => $device->token])->all();
        $this->maintenance(true);

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])
            ->expectsOutput('Re-encrypted tokens: 3')
            ->expectsOutput('All 4 tokens verified using the current key only.')
            ->assertSuccessful();

        $after = $this->rows();
        $currentOnly = new Encrypter($this->newKey, 'AES-256-CBC');
        foreach ($after as $index => $row) {
            $this->assertSame($plaintext[$row['id']], $currentOnly->decryptString($row['token']));
            $this->assertSame(array_diff_key($before[$index], ['token' => true]), array_diff_key($row, ['token' => true]));
            if ($index < 3) {
                $this->assertNotSame($before[$index]['token'], $row['token']);
            } else {
                $this->assertSame($before[$index]['token'], $row['token']);
            }
        }
        $this->assertSame($usersBefore, DB::table('users')->orderBy('id')->get()->toJson());

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])
            ->expectsOutput('Re-encrypted tokens: 0')
            ->assertSuccessful();
        $this->assertSame($after, $this->rows());
        Queue::assertNothingPushed();

        $this->useKeys($this->newKey);
        $this->artisan('security:reencrypt-push-tokens')
            ->expectsOutput('Current-key tokens: 4')
            ->expectsOutput('Previous-key tokens: 0')
            ->expectsOutput('Invalid tokens: 0')
            ->assertSuccessful();
    }

    public function test_apply_refuses_a_nontransactional_mysql_table(): void
    {
        PushDevice::factory()->create();
        $before = $this->rows();
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->maintenance(true);
        $connection = Mockery::mock(DB::connection())->makePartial();
        $connection->shouldReceive('getDriverName')->andReturn('mysql');
        DB::partialMock()->shouldReceive('connection')->withNoArgs()->andReturn($connection);
        DB::shouldReceive('selectOne')->once()->with(
            'SELECT ENGINE AS engine FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?',
            [$connection->getDatabaseName(), $connection->getTablePrefix().'push_devices']
        )->andReturn((object) ['engine' => 'MyISAM']);

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])
            ->expectsOutput('Applying requires InnoDB storage for push_devices. No tokens were changed.')
            ->assertFailed();

        $this->assertSame($before, $this->rows());
    }

    public function test_audit_reports_unreadable_or_mismatched_tokens_without_changing_them(): void
    {
        $unreadable = PushDevice::factory()->create();
        $mismatched = PushDevice::factory()->create();
        DB::table('push_devices')->where('id', $unreadable->id)->update(['token' => 'invalid-ciphertext']);
        DB::table('push_devices')->where('id', $mismatched->id)->update(['token_hash' => str_repeat('0', 64)]);
        $this->useKeys($this->newKey, [$this->oldKey]);
        $before = $this->rows();

        $this->artisan('security:reencrypt-push-tokens')
            ->expectsOutput('Invalid tokens: 2')
            ->assertFailed();

        $this->assertSame($before, $this->rows());
    }

    public function test_apply_rolls_back_earlier_chunks_if_a_later_token_is_invalid(): void
    {
        PushDevice::factory()->count(101)->create();
        $invalid = PushDevice::factory()->create();
        DB::table('push_devices')->where('id', $invalid->id)->update(['token' => 'invalid-ciphertext']);
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->maintenance(true);
        $before = $this->rows();

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])->assertFailed();

        $this->assertSame($before, $this->rows());
    }

    public function test_apply_rolls_back_if_token_hash_verification_fails(): void
    {
        PushDevice::factory()->create();
        $invalid = PushDevice::factory()->create();
        DB::table('push_devices')->where('id', $invalid->id)->update(['token_hash' => str_repeat('0', 64)]);
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->maintenance(true);
        $before = $this->rows();

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])->assertFailed();

        $this->assertSame($before, $this->rows());
    }

    public function test_apply_rolls_back_if_final_current_key_verification_fails(): void
    {
        PushDevice::factory()->create();
        $before = $this->rows();
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->maintenance(true);
        DB::unprepared("CREATE TRIGGER corrupt_rotated_token AFTER UPDATE OF token ON push_devices
            BEGIN UPDATE push_devices SET token = 'invalid-after-write' WHERE id = NEW.id; END");

        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])->assertFailed();

        $this->assertSame($before, $this->rows());
    }

    public function test_empty_table_can_be_checked_and_applied_safely(): void
    {
        $this->artisan('security:reencrypt-push-tokens')
            ->expectsOutput('Total tokens: 0')->assertSuccessful();
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->maintenance(true);
        $this->artisan('security:reencrypt-push-tokens', ['--apply' => true])
            ->expectsOutput('Re-encrypted tokens: 0')->assertSuccessful();
    }

    public function test_output_does_not_expose_keys_tokens_or_database_exception_messages(): void
    {
        $device = PushDevice::factory()->create();
        $plaintext = $device->token;
        $ciphertext = $device->getRawOriginal('token');
        $this->useKeys($this->newKey, [$this->oldKey]);
        $this->assertSame(0, Artisan::call('security:reencrypt-push-tokens'));
        foreach ([$plaintext, $ciphertext, base64_encode($this->oldKey), base64_encode($this->newKey)] as $secret) {
            $this->assertStringNotContainsString($secret, Artisan::output());
        }

        DB::partialMock()->shouldReceive('table')->with('push_devices')
            ->andThrow(new RuntimeException('Sensitive database detail: '.$plaintext));
        $this->assertSame(1, Artisan::call('security:reencrypt-push-tokens'));
        $this->assertStringContainsString('Token processing failed.', Artisan::output());
        $this->assertStringNotContainsString($plaintext, Artisan::output());
        $this->assertStringNotContainsString('Sensitive database detail', Artisan::output());
    }

    /** @param array<int, string> $previous */
    private function useKeys(string $key, array $previous = []): void
    {
        config([
            'app.key' => 'base64:'.base64_encode($key),
            'app.cipher' => 'AES-256-CBC',
            'app.previous_keys' => array_map(fn (string $previousKey): string => 'base64:'.base64_encode($previousKey), $previous),
        ]);
        $this->app->forgetInstance('encrypter');
        Crypt::clearResolvedInstance('encrypter');
    }

    private function maintenance(bool $active): void
    {
        $maintenance = Mockery::mock(MaintenanceMode::class);
        $maintenance->shouldReceive('active')->andReturn($active);
        $this->app->instance(MaintenanceMode::class, $maintenance);
    }

    /** @return array<int, array<string, mixed>> */
    private function rows(): array
    {
        return DB::table('push_devices')->orderBy('id')->get()->map(fn (object $row): array => (array) $row)->all();
    }
}
