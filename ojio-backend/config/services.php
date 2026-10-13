<?php

return [
    'admin_bootstrap' => [
        'name' => env('OJIO_ADMIN_NAME', 'OJIO Admin'),
        'email' => env('OJIO_ADMIN_EMAIL'),
        'phone' => env('OJIO_ADMIN_PHONE'),
        'password' => env('OJIO_ADMIN_PASSWORD'),
        'city' => env('OJIO_ADMIN_CITY'),
    ],
    'fcm' => [
        'enabled' => env('FCM_ENABLED', false),
        'project_id' => env('FCM_PROJECT_ID'),
        'credentials_json' => env('FCM_SERVICE_ACCOUNT_JSON'),
        'credentials_file' => env('GOOGLE_APPLICATION_CREDENTIALS'),
        'queue_connection' => env('FCM_QUEUE_CONNECTION', 'database'),
    ],
    'razorpay' => [
        'key_id' => env('RAZORPAY_KEY_ID'),
        'key_secret' => env('RAZORPAY_KEY_SECRET'),
    ],
    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID', '893178945153-tvaejgs71t83so9pj747kq03smp2q888.apps.googleusercontent.com'),
    ],
    'geocoding' => [
        'url' => env('GEOCODING_URL', 'https://photon.komoot.io/reverse'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Resend, Postmark, AWS, and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
