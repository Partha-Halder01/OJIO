import 'package:flutter/services.dart';

String? googleSignInErrorMessage(Object error) {
  if (error is PlatformException) {
    if (error.code == 'sign_in_canceled' || error.code == 'sign_in_cancelled') {
      return null;
    }
    if (error.code == 'network_error') {
      return 'Google sign-in could not connect. Check your internet and try again.';
    }
    if (error.code == 'sign_in_failed' || error.code == 'sign_in_required') {
      return 'Google sign-in is unavailable. Please try again or sign in with email and password.';
    }
    return 'Google sign-in could not complete. Please try again.';
  }
  return 'Google sign-in could not complete. Please try again.';
}
