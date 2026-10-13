<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Listing;
use App\Models\ListingImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FeedAndApiRoutesTest extends TestCase
{
    use RefreshDatabase;

    private function listing(array $attributes = [], ?User $user = null): Listing
    {
        $category = Category::firstOrCreate(['slug' => 'phones'], ['name' => 'Phones', 'is_active' => true]);

        return Listing::create(array_merge([
            'user_id' => ($user ?? User::factory()->create())->id, 'category_id' => $category->id,
            'title' => 'Phone', 'slug' => Str::uuid(), 'description' => 'Working phone', 'price' => 1000,
            'city' => 'Kolkata', 'latitude' => 22.5726, 'longitude' => 88.3639, 'status' => 'active',
        ], $attributes));
    }

    public function test_embedded_images_become_small_urls_without_changing_stored_photos(): void
    {
        $listing = $this->listing();
        $data = 'data:image/png;base64,'.str_repeat('a', 700000);
        $image = $listing->images()->create(['image_path' => $data, 'is_primary' => true, 'sort_order' => 0]);
        $url = route('listing-images.show', ['id' => $image->id]);
        $feed = $this->getJson('/api/v1/listings?feed=recommended');
        $feed->assertOk()->assertJsonPath('data.data.0.images.0.image_path', $url);
        $this->assertLessThan(10000, strlen($feed->getContent()));
        $this->getJson('/api/v1/listings/'.$listing->id)->assertOk()->assertJsonPath('data.images.0.image_path', $url);
        Sanctum::actingAs($listing->user);
        $this->getJson('/api/v1/user/my-ads')->assertOk()->assertJsonPath('data.0.images.0.image_path', $url);
        $this->assertSame($data, $image->fresh()->getRawOriginal('image_path'));
    }

    public function test_image_url_serves_original_bytes_and_supports_cached_revalidation(): void
    {
        $encoded = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4l8AAAAASUVORK5CYII=';
        $image = $this->listing()->images()->create(['image_path' => 'data:image/png;base64,'.$encoded]);
        $response = $this->get($image->image_path)->assertOk()
            ->assertHeader('Content-Type', 'image/png')
            ->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->assertSame(base64_decode($encoded), $response->getContent());
        $this->assertStringContainsString('max-age=86400', $response->headers->get('Cache-Control'));
        $this->get($image->image_path, ['If-None-Match' => $response->headers->get('ETag')])->assertStatus(304);
    }

    public function test_image_urls_preserve_external_and_storage_paths_and_reject_malformed_embedded_data(): void
    {
        $listing = $this->listing();
        $external = $listing->images()->create(['image_path' => 'https://example.com/item.jpg']);
        $this->assertSame('https://example.com/item.jpg', $external->image_path);
        $this->get(route('listing-images.show', ['id' => $external->id]))->assertRedirect('https://example.com/item.jpg');
        $stored = $listing->images()->create(['image_path' => 'listings/item.jpg']);
        $this->assertSame(asset('storage/listings/item.jpg'), $stored->image_path);
        foreach (['data:image/png;base64,!!!', 'data:image/png;base64,'.base64_encode('<script>bad</script>'), 'data:image/svg+xml;base64,'.base64_encode('<svg/>')] as $data) {
            $image = ListingImage::create(['listing_id' => $listing->id, 'image_path' => $data]);
            $this->get($image->image_path)->assertNotFound();
        }
        $this->get('/api/v1/images/999999')->assertNotFound();
    }

    public function test_editing_an_ad_retains_image_urls_and_original_bytes(): void
    {
        $encoded = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4l8AAAAASUVORK5CYII=';
        $data = 'data:image/png;base64,'.$encoded;
        $listing = $this->listing();
        $removed = $listing->images()->create(['image_path' => $data, 'sort_order' => 0, 'is_primary' => true]);
        $retained = $listing->images()->create(['image_path' => $data, 'sort_order' => 1]);
        $url = $retained->image_path;
        Sanctum::actingAs($listing->user);
        $this->putJson('/api/v1/listings/'.$listing->id, [
            'title' => 'Updated phone', 'description' => 'Updated details', 'price' => 1200, 'city' => 'Kolkata',
            'images' => [$url, $data],
        ])->assertOk()->assertJsonPath('data.images.0.image_path', $url);
        $this->assertSame($data, $retained->fresh()->getRawOriginal('image_path'));
        $this->assertTrue($retained->fresh()->is_primary);
        $this->assertSame(2, $listing->images()->count());
        $this->assertDatabaseMissing('listing_images', ['id' => $removed->id]);
        $this->get($url)->assertOk()->assertContent(base64_decode($encoded));
        Sanctum::actingAs(User::factory()->create());
        $this->putJson('/api/v1/listings/'.$listing->id, [
            'title' => 'Wrong owner', 'description' => 'Wrong owner', 'price' => 1, 'city' => 'Kolkata', 'images' => [$url],
        ])->assertNotFound();
        $this->assertSame(2, $listing->images()->count());
    }

    public function test_wallet_and_payment_guests_get_json_without_accept_headers(): void
    {
        $this->get('/api/v1/wallet')->assertUnauthorized()->assertJsonPath('message', 'Unauthenticated.');
        $this->post('/api/v1/monetization/order', ['package_id' => 1])->assertUnauthorized();
        $this->post('/api/v1/wallet/topup', ['amount_paise' => 10000])->assertUnauthorized();
        $this->post('/api/v1/monetization/wallet', ['package_id' => 1])->assertUnauthorized();
        $this->post('/api/v1/payments/1/reconcile')->assertUnauthorized();
    }

    public function test_authenticated_wallet_returns_balance_and_transactions(): void
    {
        Sanctum::actingAs(User::factory()->create(['wallet_balance_paise' => 12345]));
        $this->get('/api/v1/wallet')->assertOk()->assertJsonPath('data.balance_paise', 12345)
            ->assertJsonPath('data.transactions', [])->assertJsonPath('data.pending_orders', []);
    }

    public function test_location_update_is_saved_to_profile_without_changing_identity_or_other_users(): void
    {
        $this->postJson('/api/v1/user/location', ['city' => 'Hyderabad'])->assertUnauthorized();
        $other = User::factory()->create(['city' => 'Mumbai']);
        $seller = User::factory()->create(['city' => 'Kolkata', 'phone' => null, 'role' => 'user']);
        Sanctum::actingAs($seller);
        $this->postJson('/api/v1/user/location', [
            'city' => 'Hyderabad', 'state' => 'Telangana', 'country' => 'India',
            'latitude' => 17.385, 'longitude' => 78.4867,
            'name' => 'Changed name', 'role' => 'admin',
        ])->assertOk()->assertJsonPath('user.city', 'Hyderabad')
            ->assertJsonPath('user.latitude', 17.385)->assertJsonPath('user.name', $seller->name);
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.city', 'Hyderabad')
            ->assertJsonPath('user.longitude', 78.4867);
        $this->assertSame('Mumbai', $other->fresh()->city);
        $this->assertSame($seller->role, $seller->fresh()->role);
        $this->postJson('/api/v1/user/location', ['city' => 'Pune'])->assertOk()
            ->assertJsonPath('user.latitude', null)->assertJsonPath('user.longitude', null);
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->get('/admin/users')->assertOk()->assertSee('Pune');
    }

    public function test_location_update_validates_city_and_paired_coordinates(): void
    {
        Sanctum::actingAs(User::factory()->create(['city' => 'Kolkata']));
        $this->postJson('/api/v1/user/location', ['city' => ' '])->assertUnprocessable();
        $this->postJson('/api/v1/user/location', ['city' => 'Pune', 'latitude' => 18.52])->assertUnprocessable();
        $this->postJson('/api/v1/user/location', ['city' => 'Pune', 'latitude' => 100, 'longitude' => 73])->assertUnprocessable();
        $this->getJson('/api/v1/user/profile')->assertJsonPath('user.city', 'Kolkata');
    }

    public function test_identity_edits_preserve_location_but_legacy_city_edits_clear_old_coordinates(): void
    {
        $seller = User::factory()->create(['phone' => '9876543210', 'city' => 'Hyderabad', 'latitude' => 17.385, 'longitude' => 78.4867]);
        Sanctum::actingAs($seller);
        $this->postJson('/api/v1/user/profile', ['name' => 'New name', 'phone' => $seller->phone])
            ->assertOk()->assertJsonPath('user.city', 'Hyderabad')->assertJsonPath('user.latitude', 17.385);
        $this->postJson('/api/v1/user/profile', ['name' => 'New name', 'phone' => $seller->phone, 'city' => 'Pune'])
            ->assertOk()->assertJsonPath('user.city', 'Pune')->assertJsonPath('user.latitude', null);
    }

    public function test_nearby_defaults_to_fifty_km_and_excludes_distant_missing_and_inactive_items(): void
    {
        $near = $this->listing(['latitude' => 22.93]);
        $this->listing(['latitude' => 23.2]);
        $this->listing(['latitude' => null, 'longitude' => null]);
        $this->listing(['status' => 'sold']);
        $this->listing([], User::factory()->create(['is_blocked' => true]));
        $response = $this->getJson('/api/v1/listings?feed=nearby&latitude=22.5726&longitude=88.3639');
        $response->assertOk()->assertJsonPath('data.total', 1)->assertJsonPath('data.data.0.id', $near->id);
        $this->assertGreaterThan(30, $response->json('data.data.0.distance'));
        $this->assertLessThan(50, $response->json('data.data.0.distance'));
    }

    public function test_recommendations_include_other_cities_and_prefer_selected_city(): void
    {
        $far = $this->listing(['city' => 'Mumbai', 'latitude' => 19.076, 'longitude' => 72.8777, 'is_featured' => true]);
        $near = $this->listing();
        $response = $this->getJson('/api/v1/listings?feed=recommended&city=Kolkata&latitude=22.5726&longitude=88.3639');
        $response->assertOk()->assertJsonPath('data.total', 2)->assertJsonPath('data.data.0.id', $near->id);
        $this->assertContains($far->id, array_column($response->json('data.data'), 'id'));
    }

    public function test_nearby_is_nearest_first_even_when_further_items_are_newer_or_featured(): void
    {
        $far = $this->listing(['latitude' => 22.97, 'is_featured' => true]);
        $middle = $this->listing(['latitude' => 22.70]);
        $near = $this->listing(['latitude' => 22.58]);
        $tie = $this->listing(['latitude' => 22.58, 'is_featured' => true]);
        $this->listing(['latitude' => 23.1, 'is_featured' => true]);
        $response = $this->getJson('/api/v1/listings?feed=nearby&latitude=22.5726&longitude=88.3639&radius=50')
            ->assertOk()->assertJsonPath('data.total', 4);
        $this->assertSame([$near->id, $tie->id, $middle->id, $far->id], array_column($response->json('data.data'), 'id'));
        $this->getJson('/api/v1/listings?feed=nearby&latitude=22.5726&longitude=88.3639&radius=10')
            ->assertJsonPath('data.total', 2)->assertJsonPath('data.data.0.id', $near->id);
    }

    public function test_city_only_fallback_matches_aliases_without_substring_leakage(): void
    {
        $match = $this->listing(['city' => 'Calcutta', 'latitude' => null, 'longitude' => null]);
        $this->listing(['city' => 'New Kolkata', 'latitude' => null, 'longitude' => null]);
        $this->getJson('/api/v1/listings?feed=nearby&city=Kolkata')->assertOk()
            ->assertJsonPath('data.total', 1)->assertJsonPath('data.data.0.id', $match->id);
    }

    public function test_coordinate_validation_and_zero_coordinates(): void
    {
        $this->getJson('/api/v1/listings?latitude=100&longitude=20')->assertUnprocessable();
        $this->getJson('/api/v1/listings?latitude=20')->assertUnprocessable();
        $this->getJson('/api/v1/listings?latitude=20&longitude=20&radius=99999')->assertUnprocessable();
        $this->getJson('/api/v1/listings?feed=nearby')->assertUnprocessable();
        $zero = $this->listing(['latitude' => 0, 'longitude' => 0]);
        $this->getJson('/api/v1/listings?feed=nearby&latitude=0&longitude=0')->assertOk()->assertJsonPath('data.data.0.id', $zero->id);
    }

    public function test_nearby_pagination_is_stable_and_distance_ordered(): void
    {
        $ids = [];
        for ($index = 0; $index < 21; $index++) {
            $ids[] = $this->listing(['latitude' => 22.5726 + $index / 1000])->id;
        }
        $this->getJson('/api/v1/listings?feed=nearby&latitude=22.5726&longitude=88.3639&page=1')
            ->assertOk()->assertJsonPath('data.total', 21)->assertJsonCount(20, 'data.data')->assertJsonPath('data.data.0.id', $ids[0]);
        $this->getJson('/api/v1/listings?feed=nearby&latitude=22.5726&longitude=88.3639&page=2')
            ->assertOk()->assertJsonCount(1, 'data.data')->assertJsonPath('data.data.0.id', $ids[20]);
    }
}
