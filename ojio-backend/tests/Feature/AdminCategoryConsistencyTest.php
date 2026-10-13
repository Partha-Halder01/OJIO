<?php

namespace Tests\Feature;

use App\Models\Banner;
use App\Models\Category;
use App\Models\Coupon;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminCategoryConsistencyTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_blocked' => false]);
        $this->actingAs($admin, 'web');

        return $admin;
    }

    private function listing(Category $category, string $status = 'active', int $price = 100): Listing
    {
        return Listing::create([
            'user_id' => User::factory()->create(['phone' => fake()->unique()->numerify('9#########')])->id,
            'category_id' => $category->id, 'slug' => (string) Str::uuid(),
            'title' => 'Test item', 'description' => 'Working item', 'price' => $price,
            'city' => 'Kolkata', 'status' => $status,
        ]);
    }

    public function test_category_reads_never_create_others_or_other_records(): void
    {
        $this->getJson('/api/v1/categories')->assertOk()->assertJsonCount(0, 'data');
        $this->assertDatabaseCount('categories', 0);
    }

    public function test_only_actual_admin_listing_changes_create_unread_revisions(): void
    {
        $this->admin();
        $listing = $this->listing(Category::factory()->create());
        $url = '/admin/listings/'.$listing->id.'/status';
        $this->post($url, ['status' => 'active'])->assertRedirect();
        $this->assertEquals(0, $listing->fresh()->admin_update_version);
        $this->post($url, ['status' => 'rejected', 'rejection_reason' => 'Improve photos'])->assertRedirect();
        $this->assertEquals(1, $listing->fresh()->admin_update_version);
        $this->post($url, ['status' => 'rejected', 'rejection_reason' => 'Improve photos'])->assertRedirect();
        $this->assertEquals(1, $listing->fresh()->admin_update_version);
        $this->post($url, ['status' => 'rejected', 'rejection_reason' => 'Wrong category'])->assertRedirect();
        $this->assertEquals(2, $listing->fresh()->admin_update_version);
        $listing->update(['title' => 'Seller edited title']);
        $this->assertEquals(2, $listing->fresh()->admin_update_version);
    }

    public function test_active_tree_excludes_disabled_ancestors_and_preserves_legacy_nested_ids(): void
    {
        $root = Category::factory()->create(['name' => 'Vehicles']);
        $child = Category::factory()->create(['parent_id' => $root->id]);
        $legacy = Category::factory()->create(['parent_id' => $child->id]);
        $disabled = Category::factory()->create(['is_active' => false]);
        $hidden = Category::factory()->create(['parent_id' => $disabled->id]);
        $this->getJson('/api/v1/categories')->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonCount(2, 'data.0.subcategories')
            ->assertJsonFragment(['id' => $legacy->id]);
        $this->getJson('/api/v1/categories/'.$hidden->id)->assertNotFound();
        $this->assertDatabaseCount('categories', 5);
    }

    public function test_admin_rejects_self_parent_deeper_parent_and_moving_a_root_with_children(): void
    {
        $this->admin();
        $root = Category::factory()->create();
        $child = Category::factory()->create(['parent_id' => $root->id]);
        $other = Category::factory()->create();
        $payload = ['name' => $root->name, 'slug' => $root->slug];
        $this->post('/admin/categories/'.$root->id.'/update', $payload + ['parent_id' => $root->id])->assertSessionHasErrors('parent_id');
        $this->post('/admin/categories/'.$root->id.'/update', $payload + ['parent_id' => $other->id])->assertSessionHasErrors('parent_id');
        $this->post('/admin/categories', ['name' => 'Nested', 'slug' => 'nested', 'parent_id' => $child->id])->assertSessionHasErrors('parent_id');
        $this->assertDatabaseCount('categories', 3);
    }

    public function test_admin_brand_configuration_preserves_other_attributes_and_deduplicates(): void
    {
        $this->admin();
        $category = Category::factory()->create(['custom_attributes_schema' => ['year' => ['2025']]]);
        $this->post('/admin/categories/'.$category->id.'/update', [
            'name' => "Seller's Devices", 'slug' => $category->slug,
            'parent_id' => null, 'sort_order' => 7, 'brands' => "Samsung, Apple, Samsung\nXiaomi",
        ])->assertSessionHasNoErrors();
        $category->refresh();
        $this->assertSame(['Samsung', 'Apple', 'Xiaomi'], $category->custom_attributes_schema['brand']);
        $this->assertSame(['2025'], $category->custom_attributes_schema['year']);
        $this->assertSame(7, $category->sort_order);
        $this->get('/admin/categories')->assertOk()->assertSee('data-category=', false)->assertSee('Brands (comma-separated)');
    }

    public function test_disabled_parent_prevents_new_posting_without_spending_quota(): void
    {
        $root = Category::factory()->create(['is_active' => false]);
        $category = Category::factory()->create(['parent_id' => $root->id]);
        $seller = User::factory()->create(['phone' => '9876543210']);
        Sanctum::actingAs($seller);
        $this->postJson('/api/v1/listings', [
            'category_id' => $category->id, 'title' => 'Phone', 'description' => 'Working',
            'price' => 100, 'city' => 'Kolkata', 'images' => ['https://example.com/photo.jpg'],
        ])->assertUnprocessable();
        $this->assertDatabaseCount('listings', 0);
        $this->assertSame(0, $seller->fresh()->free_ads_posted);
    }

    public function test_legacy_descendants_are_included_in_search_and_admin_filters(): void
    {
        $root = Category::factory()->create();
        $child = Category::factory()->create(['parent_id' => $root->id]);
        $legacy = Category::factory()->create(['parent_id' => $child->id]);
        $listing = $this->listing($legacy);
        $this->getJson('/api/v1/listings?category_id='.$root->id)->assertOk()->assertJsonFragment(['id' => $listing->id, 'title' => 'Test item']);
        $this->admin();
        $this->get('/admin/listings?parent_id='.$root->id)->assertOk()->assertSee('Test item');
    }

    public function test_price_filter_is_applied_before_pagination(): void
    {
        $category = Category::factory()->create();
        for ($index = 0; $index < 21; $index++) {
            $this->listing($category, 'active', 10);
        }
        $match = $this->listing($category, 'active', 500);
        $this->getJson('/api/v1/listings?min_price=400&max_price=600')->assertOk()
            ->assertJsonCount(1, 'data.data')->assertJsonPath('data.data.0.id', $match->id);
    }

    public function test_admin_pages_render_without_categories_or_manual_banners_navigation(): void
    {
        $this->admin();
        $category = Category::factory()->create(['name' => 'Mobiles', 'slug' => 'mobiles', 'custom_attributes_schema' => ['brand' => ['Apple', 'Samsung']]]);
        Category::factory()->create(['parent_id' => $category->id, 'name' => 'Smartphones']);
        $this->listing($category);
        $this->listing($category, 'pending');
        foreach (['', '/categories', '/listings', '/users', '/coupons', '/monetization', '/profile'] as $path) {
            $response = $this->get('/admin'.$path)->assertOk()->assertDontSee('<span>Categories</span>', false)
                ->assertDontSee('<span>Banners</span>', false)->assertSee('<span>Listings</span>', false);
            if (getenv('OJIO_ADMIN_PREVIEW') === '1') {
                $directory = storage_path('framework/testing/admin-preview');
                File::ensureDirectoryExists($directory);
                $html = $response->getContent();
                if (is_file(public_path('assets/images/logo.png'))) {
                    $html = str_replace('src="/assets/images/logo.png"', 'src="data:image/png;base64,'.base64_encode(file_get_contents(public_path('assets/images/logo.png'))).'"', $html);
                }
                File::put($directory.'/'.($path ? ltrim($path, '/') : 'overview').'.html', $html);
            }
        }
    }

    public function test_manual_banner_management_is_removed_without_deleting_existing_banner_data(): void
    {
        $this->admin();
        $banner = Banner::create(['title' => 'Existing banner', 'image_url' => 'https://example.com/banner.jpg',
            'placement' => 'home_top', 'is_active' => true]);
        $this->get('/admin/banners')->assertNotFound();
        $this->post('/admin/banners', ['title' => 'New banner', 'image_url' => 'https://example.com/new.jpg', 'placement' => 'home_top'])->assertNotFound();
        $this->post('/admin/banners/'.$banner->id.'/delete')->assertNotFound();
        $this->assertDatabaseCount('banners', 1);
        $this->assertDatabaseHas('banners', ['id' => $banner->id, 'title' => 'Existing banner']);
        $this->getJson('/api/v1/banners')->assertOk();
    }

    public function test_sold_and_pending_labels_are_correct_and_sold_cannot_be_reapproved(): void
    {
        $this->admin();
        $category = Category::factory()->create();
        $sold = $this->listing($category, 'sold');
        $this->listing($category, 'pending');
        $this->get('/admin/listings')->assertOk()->assertSee('Sold')->assertSee('Pending')->assertSee('Closed');
        $this->post('/admin/listings/'.$sold->id.'/status', ['status' => 'active'])->assertUnprocessable();
        $this->assertSame('sold', $sold->fresh()->status);
    }

    public function test_listing_pagination_retains_filters(): void
    {
        $this->admin();
        $category = Category::factory()->create();
        for ($index = 0; $index < 16; $index++) {
            $this->listing($category);
        }
        $response = $this->get('/admin/listings?status=active&parent_id='.$category->id)->assertOk();
        $response->assertSee('status=active', false)->assertSee('parent_id='.$category->id, false)->assertSee('page=2', false);
    }

    public function test_coupon_delete_form_matches_route_and_zero_means_unlimited(): void
    {
        $this->admin();
        $this->post('/admin/coupons', ['code' => ' save10 ', 'description' => 'Save', 'type' => 'percentage', 'value' => 10, 'usage_limit' => 0])->assertSessionHasNoErrors();
        $coupon = Coupon::firstOrFail();
        $this->assertSame('SAVE10', $coupon->code);
        $this->assertNull($coupon->usage_limit);
        $this->assertTrue($coupon->isValid());
        $this->assertSame(1, Coupon::valid()->count());
        $this->get('/admin/coupons')->assertOk()->assertSee(route('admin.coupons.delete', $coupon->id));
        $this->post(route('admin.coupons.delete', $coupon->id))->assertRedirect();
        $this->assertDatabaseCount('coupons', 0);
    }

    public function test_coupon_rejects_percent_over_100_and_negative_limits(): void
    {
        $this->admin();
        $this->post('/admin/coupons', ['code' => 'BAD', 'description' => 'Bad', 'type' => 'percentage', 'value' => 101, 'usage_limit' => -1])
            ->assertSessionHasErrors(['value', 'usage_limit']);
        $this->assertDatabaseCount('coupons', 0);
    }

    public function test_existing_zero_limit_coupon_is_valid_in_both_code_paths(): void
    {
        $coupon = Coupon::create(['code' => 'LEGACY', 'description' => 'Legacy', 'type' => 'fixed', 'value' => 10, 'usage_limit' => 0, 'is_active' => true]);
        $this->assertTrue($coupon->isValid());
        $this->assertTrue(Coupon::valid()->whereKey($coupon->id)->exists());
    }

    public function test_blocked_admin_is_denied_and_admin_accounts_cannot_be_suspended_here(): void
    {
        $blocked = User::factory()->create(['role' => 'admin', 'is_blocked' => true]);
        $this->actingAs($blocked, 'web')->get('/admin')->assertRedirect(route('admin.login'));
        $admin = $this->admin();
        $this->post('/admin/users/'.$admin->id.'/toggle-block')->assertUnprocessable();
        $this->assertFalse($admin->fresh()->is_blocked);
    }

    public function test_admin_login_is_throttled_and_does_not_accept_blocked_accounts(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_blocked' => true]);
        $this->post('/admin/login', ['email' => $admin->email, 'password' => 'password'])->assertRedirect();
        $this->assertGuest('web');
        for ($index = 0; $index < 4; $index++) {
            $this->post('/admin/login', ['email' => $admin->email, 'password' => 'wrong'])->assertRedirect();
        }
        $this->post('/admin/login', ['email' => $admin->email, 'password' => 'wrong'])->assertStatus(429);
    }

    public function test_exhausted_free_quota_is_not_labelled_paid_and_landing_hides_disabled_categories(): void
    {
        User::factory()->create(['free_ads_posted' => 2, 'paid_ads_quota' => 0]);
        $category = Category::factory()->create(['name' => 'Disabled Selection', 'is_active' => false]);
        $this->get('/')->assertOk()->assertDontSee($category->name);
        $this->admin();
        $this->get('/admin/users')->assertOk()->assertSee('Free quota used')->assertDontSee('Paid Tier');
    }
}
