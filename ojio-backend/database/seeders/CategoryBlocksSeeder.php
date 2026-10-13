<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Category;
use Illuminate\Support\Str;

class CategoryBlocksSeeder extends Seeder
{
    public function run(): void
    {
        Category::query()->delete();

                $categories = [
            [
                'slug' => 'cars',
                'name' => 'Cars',
                'icon' => 'directions_car',
                'description' => 'Cars, SUVs, Luxury Cars, Electric Cars, Commercial Cars, Vintage & Classic Cars, Car Parts & Accessories, Other Cars',
                'sort_order' => 1,
                'subcategories' => [
                    'Cars', 'SUVs', 'Luxury Cars', 'Electric Cars', 'Commercial Cars', 'Vintage & Classic Cars', 'Car Parts & Accessories', 'Other Cars'
                ],
            ],
            [
                'slug' => 'commercial-vehicles',
                'name' => 'Commercial Vehicles',
                'icon' => 'local_shipping',
                'description' => 'Trucks, Pickups, Vans, Buses, Tempos, Tractors, Construction Vehicles, Other Commercial Vehicles, Commercial Vehicle Parts',
                'sort_order' => 2,
                'subcategories' => [
                    'Trucks', 'Pickups', 'Vans', 'Buses', 'Tempos', 'Tractors', 'Construction Vehicles', 'Other Commercial Vehicles', 'Commercial Vehicle Parts'
                ],
            ],
            [
                'slug' => 'bikes-scooters',
                'name' => 'Bikes & Scooters',
                'icon' => 'two_wheeler',
                'description' => 'Motorcycles, Scooters, Electric Bikes, Electric Scooters, Bicycles, Sports Bikes, Cruiser Bikes, Other Bikes, Bike Parts & Accessories',
                'sort_order' => 3,
                'subcategories' => [
                    'Motorcycles', 'Scooters', 'Electric Bikes', 'Electric Scooters', 'Bicycles', 'Sports Bikes', 'Cruiser Bikes', 'Other Bikes', 'Bike Parts & Accessories'
                ],
            ],
            [
                'slug' => 'mobiles-tablets',
                'name' => 'Mobiles & Tablets',
                'icon' => 'smartphone',
                'description' => 'iPhones, Android Phones, Tablets, iPads, Smartwatches, Mobile Accessories, Mobile Parts, Other Mobiles',
                'sort_order' => 4,
                'subcategories' => [
                    'iPhones', 'Android Phones', 'Tablets', 'iPads', 'Smartwatches', 'Mobile Accessories', 'Mobile Parts', 'Other Mobiles'
                ],
            ],
            [
                'slug' => 'electronics',
                'name' => 'Electronics',
                'icon' => 'laptop_mac',
                'description' => 'TVs, Computers, Laptops, Cameras, Speakers, Headphones, Gaming Consoles, Printers, Computer Accessories, Home Electronics, Other Electronics',
                'sort_order' => 5,
                'subcategories' => [
                    'TVs', 'Computers', 'Laptops', 'Cameras', 'Speakers', 'Headphones', 'Gaming Consoles', 'Printers', 'Computer Accessories', 'Home Electronics', 'Other Electronics'
                ],
            ],
            [
                'slug' => 'real-estate',
                'name' => 'Real Estate',
                'icon' => 'apartment',
                'description' => 'Apartments / Flats, Houses, Villas, Rooms, PG / Hostels, Land & Plots, Commercial Property, Shops, Offices, Warehouses, Property for Rent, Property for Sale',
                'sort_order' => 6,
                'subcategories' => [
                    'Apartments / Flats', 'Houses', 'Villas', 'Rooms', 'PG / Hostels', 'Land & Plots', 'Commercial Property', 'Shops', 'Offices', 'Warehouses', 'Property for Rent', 'Property for Sale'
                ],
            ],
            [
                'slug' => 'jobs',
                'name' => 'Jobs',
                'icon' => 'work',
                'description' => 'Full-Time Jobs, Part-Time Jobs, Work From Home, Freelance Jobs, Internship, IT Jobs, Sales & Marketing, Finance & Accounting, Education Jobs, Driver & Delivery Jobs, Other Jobs',
                'sort_order' => 7,
                'subcategories' => [
                    'Full-Time Jobs', 'Part-Time Jobs', 'Work From Home', 'Freelance Jobs', 'Internship', 'IT Jobs', 'Sales & Marketing', 'Finance & Accounting', 'Education Jobs', 'Driver & Delivery Jobs', 'Other Jobs'
                ],
            ],
            [
                'slug' => 'furniture',
                'name' => 'Furniture',
                'icon' => 'chair',
                'description' => 'Sofa & Seating, Beds, Tables, Chairs, Wardrobes, Cabinets & Storage, Dining Furniture, Office Furniture, Kids Furniture, Home Décor, Other Furniture',
                'sort_order' => 8,
                'subcategories' => [
                    'Sofa & Seating', 'Beds', 'Tables', 'Chairs', 'Wardrobes', 'Cabinets & Storage', 'Dining Furniture', 'Office Furniture', 'Kids Furniture', 'Home Décor', 'Other Furniture'
                ],
            ],
            [
                'slug' => 'fashion',
                'name' => 'Fashion',
                'icon' => 'checkroom',
                'description' => 'Men\'s Clothing, Women\'s Clothing, Kids\' Clothing, Shoes, Bags, Watches, Jewellery, Sunglasses, Traditional Wear, Fashion Accessories, Other Fashion',
                'sort_order' => 9,
                'subcategories' => [
                    'Men\'s Clothing', 'Women\'s Clothing', 'Kids\' Clothing', 'Shoes', 'Bags', 'Watches', 'Jewellery', 'Sunglasses', 'Traditional Wear', 'Fashion Accessories', 'Other Fashion'
                ],
            ],
            [
                'slug' => 'sports-fitness',
                'name' => 'Sports & Fitness',
                'icon' => 'sports_soccer',
                'description' => 'Cricket, Football, Badminton, Tennis, Cycling, Gym & Fitness, Sports Equipment, Sports Shoes, Sportswear, Outdoor & Camping, Other Sports',
                'sort_order' => 10,
                'subcategories' => [
                    'Cricket', 'Football', 'Badminton', 'Tennis', 'Cycling', 'Gym & Fitness', 'Sports Equipment', 'Sports Shoes', 'Sportswear', 'Outdoor & Camping', 'Other Sports'
                ],
            ],
            [
                'slug' => 'home-appliances',
                'name' => 'Home & Appliances',
                'icon' => 'kitchen',
                'description' => 'Refrigerators, Washing Machines, ACs, Coolers, Fans, TVs & Entertainment, Kitchen Appliances, Water Purifiers, Microwave & Ovens, Home Appliances, Other Appliances',
                'sort_order' => 11,
                'subcategories' => [
                    'Refrigerators', 'Washing Machines', 'ACs', 'Coolers', 'Fans', 'TVs & Entertainment', 'Kitchen Appliances', 'Water Purifiers', 'Microwave & Ovens', 'Home Appliances', 'Other Appliances'
                ],
            ],
            [
                'slug' => 'services',
                'name' => 'Services',
                'icon' => 'handyman',
                'description' => 'Car & Bike Services, Home Services, Repair Services, Cleaning Services, Education & Tutoring, Beauty & Salon, Photography, Event Services, Computer & Mobile Repair, Professional Services, Other Services',
                'sort_order' => 12,
                'subcategories' => [
                    'Car & Bike Services', 'Home Services', 'Repair Services', 'Cleaning Services', 'Education & Tutoring', 'Beauty & Salon', 'Photography', 'Event Services', 'Computer & Mobile Repair', 'Professional Services', 'Other Services'
                ],
            ],
            [
                'slug' => 'books-education',
                'name' => 'Books & Education',
                'icon' => 'menu_book',
                'description' => 'Books, School Books, College Books, Competitive Exam Books, Study Materials, Courses & Training, Musical Instruments, Stationery, Other Education',
                'sort_order' => 13,
                'subcategories' => [
                    'Books', 'School Books', 'College Books', 'Competitive Exam Books', 'Study Materials', 'Courses & Training', 'Musical Instruments', 'Stationery', 'Other Education'
                ],
            ],
            [
                'slug' => 'pets-animals',
                'name' => 'Pets & Animals',
                'icon' => 'pets',
                'description' => 'Dogs, Cats, Birds, Fish, Other Pets, Pet Food, Pet Accessories, Pet Care, Pet Services',
                'sort_order' => 14,
                'subcategories' => [
                    'Dogs', 'Cats', 'Birds', 'Fish', 'Other Pets', 'Pet Food', 'Pet Accessories', 'Pet Care', 'Pet Services'
                ],
            ],
            [
                'slug' => 'agriculture',
                'name' => 'Agriculture',
                'icon' => 'agriculture',
                'description' => 'Tractors, Farm Machinery, Farming Equipment, Seeds, Fertilizers, Farming Tools, Livestock, Poultry, Animal Feed, Agricultural Products, Other Agriculture',
                'sort_order' => 15,
                'subcategories' => [
                    'Tractors', 'Farm Machinery', 'Farming Equipment', 'Seeds', 'Fertilizers', 'Farming Tools', 'Livestock', 'Poultry', 'Animal Feed', 'Agricultural Products', 'Other Agriculture'
                ],
            ],
            [
                'slug' => 'gaming',
                'name' => 'Gaming',
                'icon' => 'sports_esports',
                'description' => 'Gaming Consoles, Video Games, Gaming PCs, Gaming Laptops, Controllers, Gaming Accessories, Gaming Chairs, Other Gaming',
                'sort_order' => 16,
                'subcategories' => [
                    'Gaming Consoles', 'Video Games', 'Gaming PCs', 'Gaming Laptops', 'Controllers', 'Gaming Accessories', 'Gaming Chairs', 'Other Gaming'
                ],
            ],
        ];

        foreach ($categories as $catData) {
            $subs = $catData['subcategories'];
            unset($catData['subcategories']);

            $parent = Category::updateOrCreate(
                ['slug' => $catData['slug']],
                $catData
            );

            foreach ($subs as $index => $subName) {
                $subSlug = Str::slug($subName);
                
                // Ensure slug is globally unique by checking the database or appending parent slug
                if (Category::where('slug', $subSlug)->exists() || $subSlug === $catData['slug']) {
                    $subSlug = $subSlug . '-' . $catData['slug'];
                }

                Category::updateOrCreate(
                    [
                        'slug' => $subSlug,
                        'parent_id' => $parent->id
                    ],
                    [
                        'name' => $subName,
                        'icon' => 'arrow_forward_ios',
                        'sort_order' => $index + 1,
                    ]
                );
            }
        }
    }
}
