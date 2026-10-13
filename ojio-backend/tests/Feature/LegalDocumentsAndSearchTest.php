<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\LegalDocument;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class LegalDocumentsAndSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_both_documents_have_draft_defaults_without_writing_on_public_reads(): void
    {
        foreach (['terms', 'privacy'] as $slug) {
            $this->getJson('/api/v1/legal/'.$slug)->assertOk()->assertJsonPath('data.slug', $slug)
                ->assertJsonPath('data.is_draft', true)->assertJsonMissingPath('data.edited_by');
        }
        $this->assertDatabaseCount('legal_documents', 0);
        $this->getJson('/api/v1/legal/unknown')->assertNotFound();
    }

    public function test_only_admin_can_read_and_change_the_legal_editor(): void
    {
        $this->get('/admin/legal')->assertRedirect(route('admin.login'));
        $this->post('/admin/legal/terms', [])->assertRedirect(route('admin.login'));
        $this->actingAs(User::factory()->create(['role' => 'user']), 'web');
        $this->post('/admin/legal/terms', [])->assertRedirect(route('admin.login'));
        $this->assertDatabaseCount('legal_documents', 0);
    }

    public function test_admin_saved_content_is_immediately_available_to_the_app_and_escaped_in_editor(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin, 'web');
        $this->get('/admin/legal')->assertOk()->assertSee('Legal Pages')->assertSee('Terms &amp; Conditions', false);
        foreach (['terms', 'privacy'] as $slug) {
            $content = 'Client-approved '.$slug.' content. '.str_repeat('Use OJIO responsibly. ', 3).'<script>alert(1)</script>';
            $this->post('/admin/legal/'.$slug, ['title' => 'Client '.$slug, 'content' => $content, 'is_draft' => false])
                ->assertRedirect(route('admin.legal'))->assertSessionHasNoErrors();
            $this->getJson('/api/v1/legal/'.$slug)->assertOk()->assertJsonPath('data.content', $content)->assertJsonPath('data.is_draft', false);
            $this->assertSame($admin->id, LegalDocument::where('slug', $slug)->first()->edited_by);
        }
        $this->get('/admin/legal')->assertSee('&lt;script&gt;', false)->assertDontSee('<script>alert(1)</script>', false);
        $this->assertDatabaseCount('legal_documents', 2);
    }

    public function test_empty_or_oversized_content_and_unknown_documents_cannot_be_saved(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        foreach (['', str_repeat('a', 30001)] as $content) {
            $this->post('/admin/legal/terms', ['title' => 'Terms', 'content' => $content, 'is_draft' => true])
                ->assertSessionHasErrors('content');
        }
        $this->post('/admin/legal/unknown', [])->assertNotFound();
        $this->assertDatabaseCount('legal_documents', 0);
    }

    public function test_registration_requires_a_valid_unique_phone_and_normalises_country_prefix(): void
    {
        $data = ['name' => 'Seller', 'email' => 'seller@example.com', 'password' => 'Password123'];
        $this->postJson('/api/v1/auth/register', $data)->assertUnprocessable()->assertJsonValidationErrors('phone');
        $this->assertDatabaseCount('users', 0);
        $this->postJson('/api/v1/auth/register', [...$data, 'phone' => '+919876543210'])->assertCreated()->assertJsonPath('user.phone', '9876543210');
        $this->postJson('/api/v1/auth/register', [...$data, 'email' => 'other@example.com', 'phone' => '9876543210'])
            ->assertUnprocessable()->assertJsonPath('errors.phone.0', 'This mobile number is already used by another account.');
        $this->assertDatabaseCount('users', 1);
    }

    public function test_suggestions_and_search_only_show_matching_active_unblocked_items_in_selected_category_and_city(): void
    {
        $seller = User::factory()->create();
        $category = Category::factory()->create();
        $child = Category::factory()->create(['parent_id' => $category->id]);
        $other = Category::factory()->create();
        foreach ([
            ['Phone 128GB', $child->id, 'Kolkata', 'active', $seller->id],
            ['Phone pending', $child->id, 'Kolkata', 'pending', $seller->id],
            ['Phone other category', $other->id, 'Kolkata', 'active', $seller->id],
            ['Phone other city', $child->id, 'Mumbai', 'active', $seller->id],
            ['Phone blocked', $child->id, 'Kolkata', 'active', User::factory()->create(['is_blocked' => true])->id],
        ] as [$title, $categoryId, $city, $status, $userId]) {
            Listing::create(['title' => $title, 'category_id' => $categoryId, 'city' => $city, 'status' => $status,
                'user_id' => $userId, 'slug' => (string) Str::uuid(), 'description' => 'Working phone', 'price' => 100]);
        }
        $params = '?query=Phone&city=Kolkata&category_id='.$category->id;
        $this->getJson('/api/v1/listings/suggestions'.$params)->assertOk()->assertExactJson(['status' => 'success', 'data' => ['Phone 128GB']]);
        $this->getJson('/api/v1/listings'.$params)->assertOk()->assertJsonCount(1, 'data.data')->assertJsonPath('data.data.0.title', 'Phone 128GB');
        $this->getJson('/api/v1/listings/suggestions?query=P')->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/listings/suggestions?query='.str_repeat('a', 201))->assertUnprocessable();
    }
}
