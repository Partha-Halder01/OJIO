<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Category;
use App\Models\Listing;
use App\Models\ListingImage;
use App\Models\Banner;
use Illuminate\Support\Facades\Hash;

class OjioMarketplaceSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Admin & Demo User
        $admin = User::firstOrCreate(
            ['email' => 'admin@ojio.in'],
            [
                'name' => 'OJIO Super Admin',
                'phone' => '+919876543210',
                'password' => Hash::make('Admin@123'),
                'role' => 'admin',
                'city' => 'Kolkata',
                'latitude' => 22.5726,
                'longitude' => 88.3639,
            ]
        );

        $demoUser = User::firstOrCreate(
            ['email' => 'rahul@example.com'],
            [
                'name' => 'Rahul Sharma',
                'phone' => '+919830012345',
                'password' => Hash::make('User@123'),
                'role' => 'user',
                'city' => 'Kolkata',
                'latitude' => 22.5726,
                'longitude' => 88.3639,
                'free_ads_posted' => 1,
            ]
        );

        // 2. Categories: Vehicles & Electronics
        $vehicles = Category::firstOrCreate(
            ['slug' => 'vehicles'],
            [
                'name' => 'Vehicles',
                'icon' => 'directions_car',
                'description' => 'Cars, 2-wheelers, 3-wheelers & commercial vehicles',
                'sort_order' => 1,
            ]
        );

        $twoWheelers = Category::firstOrCreate(
            ['slug' => 'motorcycles-scooters'],
            [
                'parent_id' => $vehicles->id,
                'name' => 'Motorcycles & Scooters',
                'icon' => 'two_wheeler',
                'custom_attributes_schema' => [
                    'brand' => ['Royal Enfield', 'Hero', 'Honda', 'Bajaj', 'Yamaha', 'TVS', 'KTM'],
                    'fuel' => ['Petrol', 'Electric'],
                    'fields' => ['year', 'km_driven', 'brand', 'model'],
                ],
                'sort_order' => 1,
            ]
        );

        $fourWheelers = Category::firstOrCreate(
            ['slug' => 'cars'],
            [
                'parent_id' => $vehicles->id,
                'name' => 'Cars (4 Wheelers)',
                'icon' => 'directions_car',
                'custom_attributes_schema' => [
                    'brand' => ['Maruti Suzuki', 'Hyundai', 'Tata', 'Mahindra', 'Toyota', 'Honda', 'Kia'],
                    'fuel' => ['Petrol', 'Diesel', 'CNG', 'Electric'],
                    'transmission' => ['Manual', 'Automatic'],
                    'fields' => ['year', 'km_driven', 'fuel', 'transmission', 'owners'],
                ],
                'sort_order' => 2,
            ]
        );

        $threeWheelers = Category::firstOrCreate(
            ['slug' => '3-wheelers-autos'],
            [
                'parent_id' => $vehicles->id,
                'name' => '3 Wheelers & Commercial',
                'icon' => 'electric_rickshaw',
                'sort_order' => 3,
            ]
        );

        $electronics = Category::firstOrCreate(
            ['slug' => 'mobiles-electronics'],
            [
                'name' => 'Mobiles & Electronics',
                'icon' => 'smartphone',
                'description' => 'Smartphones, accessories, tablets & consumer electronics',
                'sort_order' => 2,
            ]
        );

        $mobiles = Category::firstOrCreate(
            ['slug' => 'mobile-phones'],
            [
                'parent_id' => $electronics->id,
                'name' => 'Mobile Phones',
                'icon' => 'phone_android',
                'custom_attributes_schema' => [
                    'brand' => ['Apple iPhone', 'Samsung', 'OnePlus', 'Xiaomi', 'Vivo', 'Realme', 'Oppo'],
                    'storage' => ['64 GB', '128 GB', '256 GB', '512 GB', '1 TB'],
                    'condition' => ['Brand New', 'Like New', 'Gently Used', 'Heavily Used'],
                    'fields' => ['brand', 'model', 'storage', 'condition', 'warranty'],
                ],
                'sort_order' => 1,
            ]
        );

        // 3. Sample Promotional Banners
        Banner::firstOrCreate(
            ['title' => 'Sell Fast on OJIO'],
            [
                'image_url' => 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&auto=format&fit=crop&q=80',
                'target_url' => 'https://ojio.in/sell',
                'placement' => 'home_top',
                'sort_order' => 1,
                'is_active' => true,
            ]
        );

        Banner::firstOrCreate(
            ['title' => 'Find Verified Used Cars'],
            [
                'image_url' => 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=800&auto=format&fit=crop&q=60',
                'target_url' => 'https://ojio.in/category/cars',
                'placement' => 'home_top',
                'sort_order' => 2,
                'is_active' => true,
            ]
        );

        // 4. Sample Classified Listings
        $bullet = Listing::firstOrCreate(
            ['slug' => 'royal-enfield-classic-350-stealth-black-2023'],
            [
                'user_id' => $demoUser->id,
                'category_id' => $twoWheelers->id,
                'title' => 'Royal Enfield Classic 350 - Stealth Black (2023)',
                'description' => 'Single owner, pristine condition, full service history from Royal Enfield authorized service center. Extra leg guard and touring seat installed.',
                'price' => 185000,
                'is_negotiable' => true,
                'city' => 'Kolkata',
                'state' => 'West Bengal',
                'locality' => 'Salt Lake Sector 5',
                'latitude' => 22.5735,
                'longitude' => 88.4331,
                'phone_number' => '+919830012345',
                'hide_phone' => false,
                'status' => 'active',
                'is_featured' => true,
                'attributes' => [
                    'brand' => 'Royal Enfield',
                    'model' => 'Classic 350',
                    'year' => 2023,
                    'km_driven' => 9500,
                    'fuel' => 'Petrol',
                ],
            ]
        );

        ListingImage::firstOrCreate(
            ['listing_id' => $bullet->id, 'image_path' => 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=800&auto=format&fit=crop&q=60'],
            ['is_primary' => true, 'sort_order' => 0]
        );

        
        
    }
}
