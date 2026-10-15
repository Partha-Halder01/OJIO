<?php

namespace Tests\Unit;

use App\Support\PublicFilePath;
use Illuminate\Filesystem\Filesystem;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class PublicFilePathTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();
        $this->directory = sys_get_temp_dir().DIRECTORY_SEPARATOR.'ojio-public-path-'.bin2hex(random_bytes(8));
        $files = new Filesystem;
        $files->ensureDirectoryExists($this->directory.'/public/images');
        $files->put($this->directory.'/public/images/photo.jpg', 'public-photo');
        $files->put($this->directory.'/public/index.php', '<?php echo "front-controller";');
        $files->put($this->directory.'/public/.hidden.json', 'hidden-fixture');
        $files->put($this->directory.'/private.json', 'private-fixture');
    }

    protected function tearDown(): void
    {
        if (isset($this->directory) && str_starts_with($this->directory, sys_get_temp_dir().DIRECTORY_SEPARATOR.'ojio-public-path-')) {
            (new Filesystem)->deleteDirectory($this->directory);
        }
        parent::tearDown();
    }

    public function test_only_existing_files_within_the_public_root_are_resolved(): void
    {
        $root = $this->directory.'/public';
        $this->assertSame(realpath($root.'/images/photo.jpg'), PublicFilePath::resolve($root, 'images/photo.jpg'));
        $this->assertNull(PublicFilePath::resolve($root, 'images/missing.jpg'));
        $this->assertNull(PublicFilePath::resolve($root, 'images'));
        $this->assertNull(PublicFilePath::resolve($this->directory.'/missing', 'photo.jpg'));
    }

    #[DataProvider('unsafePaths')]
    public function test_unsafe_paths_cannot_resolve_files(string $path): void
    {
        $this->assertFalse(PublicFilePath::isSafeRelativePath($path));
        $this->assertNull(PublicFilePath::resolve($this->directory.'/public', $path));
    }

    public static function unsafePaths(): array
    {
        return [
            ['../private.json'], ['images/../../private.json'], ['images/./photo.jpg'],
            ['.env'], ['images/.hidden/photo.jpg'], ['images\\..\\private.json'],
            ['%2e%2e/private.json'], ['images/%2f../private.json'], ["images/\0photo.jpg"],
            ['C:/private.json'], ['/private.json'], ['php://filter/resource=private.json'],
        ];
    }

    public function test_symlinks_cannot_escape_the_selected_root(): void
    {
        $link = $this->directory.'/public/linked.json';
        if (! @symlink($this->directory.'/private.json', $link)) {
            $this->markTestSkipped('This OS account cannot create symbolic links.');
        }

        try {
            $this->assertNull(PublicFilePath::resolve($this->directory.'/public', 'linked.json'));
        } finally {
            unlink($link);
        }

        foreach (['index.php', '.hidden.json'] as $target) {
            $this->assertTrue(symlink($this->directory.'/public/'.$target, $link));
            try {
                $this->assertNull(PublicFilePath::resolve($this->directory.'/public', 'linked.json'));
            } finally {
                unlink($link);
            }
        }
    }
}
