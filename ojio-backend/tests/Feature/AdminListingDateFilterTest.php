<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

class AdminListingDateFilterTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): void
    {
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->travelTo(Carbon::parse('2026-10-09 00:15:00', 'Asia/Kolkata'));
    }

    private function listing(Carbon $postedAt, ?Category $category = null, string $status = 'active'): Listing
    {
        $listing = Listing::create([
            'user_id' => User::factory()->create()->id,
            'category_id' => ($category ?? Category::factory()->create())->id,
            'title' => 'Date filter item', 'slug' => (string) Str::uuid(),
            'description' => 'Working item', 'price' => 100, 'city' => 'Kolkata', 'status' => $status,
        ]);
        $listing->forceFill(['created_at' => $postedAt->copy()->setTimezone(config('app.timezone'))])->save();

        return $listing;
    }

    public function test_filters_use_indian_calendar_days_and_correct_inclusive_start_exclusive_end_boundaries(): void
    {
        $this->admin();
        $today = Carbon::now('Asia/Kolkata')->startOfDay();
        $todayFirst = $this->listing($today);
        $todayLast = $this->listing($today->copy()->addDay()->subSecond());
        $tomorrow = $this->listing($today->copy()->addDay());
        $yesterdayFirst = $this->listing($today->copy()->subDay());
        $yesterdayLast = $this->listing($today->copy()->subSecond());
        $weekFirst = $this->listing($today->copy()->subDays(6));
        $beforeWeek = $this->listing($today->copy()->subDays(6)->subSecond());
        $monthFirst = $this->listing($today->copy()->subDays(29));
        $beforeMonth = $this->listing($today->copy()->subDays(29)->subSecond());
        $cases = [
            'today' => [$todayFirst->id, $todayLast->id],
            'yesterday' => [$yesterdayFirst->id, $yesterdayLast->id],
            '7_days' => [$todayFirst->id, $todayLast->id, $yesterdayFirst->id, $yesterdayLast->id, $weekFirst->id],
            '30_days' => [$todayFirst->id, $todayLast->id, $yesterdayFirst->id, $yesterdayLast->id, $weekFirst->id, $beforeWeek->id, $monthFirst->id],
        ];
        foreach ($cases as $period => $expected) {
            $response = $this->get('/admin/listings?period='.$period)->assertOk()->assertViewHas('period', $period);
            $this->assertEqualsCanonicalizing($expected, $response->viewData('listings')->pluck('id')->all(), $period);
            $this->assertDatabaseCount('listings', 9);
        }
        $this->get('/admin/listings?period=all')->assertOk()->assertViewHas('listings', fn ($listings) => $listings->total() === 9);
        $this->get('/admin/listings')->assertOk()->assertViewHas('period', 'all')
            ->assertViewHas('listings', fn ($listings) => $listings->total() === 9);
    }

    public function test_date_filter_combines_with_status_and_categories_and_survives_pagination_and_filter_switches(): void
    {
        $this->admin();
        $root = Category::factory()->create();
        $child = Category::factory()->create(['parent_id' => $root->id]);
        $today = Carbon::now('Asia/Kolkata')->startOfDay();
        for ($index = 0; $index < 16; $index++) {
            $this->listing($today->copy()->addSeconds($index), $child);
        }
        $this->listing($today, $child, 'rejected');
        $this->listing($today, Category::factory()->create());
        $this->listing($today->copy()->subDay(), $child);
        $url = '/admin/listings?period=today&status=active&parent_id='.$root->id.'&category_id='.$child->id;
        $response = $this->get($url)->assertOk();
        $response->assertViewHas('listings', fn ($listings) => $listings->total() === 16 && $listings->count() === 15)
            ->assertSee('page=2', false)->assertSee('period=today', false)
            ->assertSee('name="period" value="today"', false)
            ->assertSee('Today')->assertSee('Yesterday')->assertSee('Last 7 Days')->assertSee('Last 30 Days');
        foreach (['all', 'pending', 'rejected', 'sold'] as $status) {
            $response->assertSee(route('admin.listings', ['parent_id' => $root->id, 'category_id' => $child->id, 'period' => 'today', 'status' => $status]));
        }
        $this->get($url.'&page=2')->assertOk()->assertViewHas('listings', fn ($listings) => $listings->count() === 1);
        $this->get('/admin/listings?period=today&parent_id='.$root->id)->assertOk()
            ->assertViewHas('listings', fn ($listings) => $listings->total() === 17);
    }

    public function test_rejection_from_filtered_list_still_works_and_keeps_the_filter(): void
    {
        $this->admin();
        $item = $this->listing(Carbon::now());
        $url = route('admin.listings', ['period' => 'today', 'status' => 'active']);
        $this->from($url)->post('/admin/listings/'.$item->id.'/status', ['status' => 'rejected', 'rejection_reason' => 'Invalid content'])
            ->assertRedirect($url)->assertSessionHas('success');
        $this->assertSame('rejected', $item->fresh()->status);
        $this->assertSame('Invalid content', $item->fresh()->rejection_reason);
        $this->assertSame(1, $item->fresh()->admin_update_version);
        $this->get($url)->assertOk()->assertViewHas('listings', fn ($listings) => $listings->total() === 0);
        $this->get('/admin/listings?period=today&status=rejected')->assertOk()
            ->assertViewHas('listings', fn ($listings) => $listings->first()->id === $item->id);
    }

    public function test_invalid_dates_are_rejected_and_guests_cannot_access_the_filters(): void
    {
        $this->get('/admin/listings?period=today')->assertRedirect('/admin/login');
        $this->admin();
        $this->getJson('/admin/listings?period=invalid')->assertUnprocessable()->assertJsonValidationErrors('period');
        $this->getJson('/admin/listings?period[]=today')->assertUnprocessable()->assertJsonValidationErrors('period');
    }
}
