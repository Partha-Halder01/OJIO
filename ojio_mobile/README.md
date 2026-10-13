# ojio_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android release signing

The Android package is `com.ojio.app.ojio_mobile`. Release builds use the dedicated
`ojio-release` signing key, configured privately in `android/key.properties`.
The keystore is `android/keystore/ojio-release.p12`. Both files are excluded from
source control; securely back up both together and retain them for future updates.
`android/key.properties.example` documents the required local configuration.
Release signing never falls back to the shared Android debug key.

Register this release certificate's SHA-1 and SHA-256 in the client's Firebase
Android app, then replace `android/app/google-services.json` with the downloaded
configuration and rebuild the release APK. Debug builds retain the development
debug certificate and require their own Firebase registration if used for testing.
The first installation signed with the new release key cannot update an existing
debug-signed installation; uninstalling the old test app clears its local app data.
