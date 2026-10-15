<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Encryption\Encrypter;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Throwable;

#[Signature('security:reencrypt-push-tokens {--apply : Re-encrypt tokens; requires maintenance mode and distinct previous keys}')]
#[Description('Audit push-token encryption without writes, or explicitly re-encrypt with the current APP_KEY')]
class ReencryptPushDeviceTokens extends Command
{
    public function handle(Encrypter $encrypter): int
    {
        $apply = (bool) $this->option('apply');
        if ($apply && ! $this->laravel->isDownForMaintenance()) {
            $this->error('Applying requires maintenance mode. No tokens were changed.');

            return self::FAILURE;
        }

        if ($apply && ($encrypter->getPreviousKeys() === [] || in_array($encrypter->getKey(), $encrypter->getPreviousKeys(), true))) {
            $this->error('Configure a new APP_KEY and distinct APP_PREVIOUS_KEYS before applying. No tokens were changed.');

            return self::FAILURE;
        }

        try {
            if ($apply && ! $this->hasTransactionalStorage()) {
                $this->error('Applying requires InnoDB storage for push_devices. No tokens were changed.');

                return self::FAILURE;
            }
            $currentOnly = new Encrypter($encrypter->getKey(), (string) config('app.cipher'));
            $summary = $apply
                ? DB::transaction(function () use ($currentOnly, $encrypter): array {
                    $summary = $this->processTokens($currentOnly, $encrypter, true);
                    if ($summary['invalid'] > 0) {
                        throw new RuntimeException('Token verification failed.');
                    }

                    $verified = $this->processTokens($currentOnly, $currentOnly, false);
                    if ($verified['invalid'] > 0 || $verified['total'] !== $summary['total']) {
                        throw new RuntimeException('Current-key verification failed.');
                    }

                    return $summary;
                })
                : $this->processTokens($currentOnly, $encrypter, false);
        } catch (Throwable) {
            $this->error('Token processing failed. Keep previous keys configured and verify the database before retrying.');

            return self::FAILURE;
        }

        $this->line('Total tokens: '.$summary['total']);
        $this->line('Current-key tokens: '.$summary['current']);
        $this->line('Previous-key tokens: '.$summary['previous']);
        $this->line('Invalid tokens: '.$summary['invalid']);

        if ($summary['invalid'] > 0) {
            $this->error('Unreadable or mismatched tokens found. Do not remove previous keys.');

            return self::FAILURE;
        }

        if ($apply) {
            $this->info('Re-encrypted tokens: '.$summary['changed']);
            $this->info('All '.$summary['total'].' tokens verified using the current key only.');
        } elseif ($summary['previous'] > 0) {
            $this->warn('Read-only check: re-encryption is needed before removing previous keys.');
        } else {
            $this->info('Read-only check: all tokens verified using the current key only.');
        }

        return self::SUCCESS;
    }

    private function hasTransactionalStorage(): bool
    {
        $connection = DB::connection();
        if (! in_array($connection->getDriverName(), ['mysql', 'mariadb'], true)) {
            return true;
        }

        $table = DB::selectOne(
            'SELECT ENGINE AS engine FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?',
            [$connection->getDatabaseName(), $connection->getTablePrefix().'push_devices']
        );

        return is_object($table) && is_string($table->engine ?? null) && strcasecmp($table->engine, 'InnoDB') === 0;
    }

    /** @return array{total: int, current: int, previous: int, invalid: int, changed: int} */
    private function processTokens(Encrypter $currentOnly, Encrypter $withPrevious, bool $apply): array
    {
        $summary = ['total' => 0, 'current' => 0, 'previous' => 0, 'invalid' => 0, 'changed' => 0];
        $query = DB::table('push_devices')->select(['id', 'token', 'token_hash']);
        if ($apply) {
            $query->lockForUpdate();
        }

        foreach ($query->lazyById(100) as $device) {
            $summary['total']++;
            $usesCurrentKey = true;
            try {
                $token = $currentOnly->decryptString((string) $device->token);
            } catch (DecryptException) {
                try {
                    $token = $withPrevious->decryptString((string) $device->token);
                    $usesCurrentKey = false;
                } catch (DecryptException) {
                    $summary['invalid']++;

                    continue;
                }
            }

            if (! is_string($token) || $token === '' || ! hash_equals((string) $device->token_hash, hash('sha256', $token))) {
                $summary['invalid']++;

                continue;
            }

            $summary[$usesCurrentKey ? 'current' : 'previous']++;
            if ($apply && ! $usesCurrentKey) {
                $changed = DB::table('push_devices')->where('id', $device->id)
                    ->where('token', $device->token)->where('token_hash', $device->token_hash)
                    ->update(['token' => $currentOnly->encryptString($token)]);
                if ($changed !== 1) {
                    throw new RuntimeException('A token changed during re-encryption.');
                }
                $summary['changed']++;
            }
        }

        return $summary;
    }
}
