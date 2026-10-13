import 'package:flutter/material.dart';
import 'api_config.dart';

class AppColors {
  // --- Exact UI Brand Palette (Blue Base Theme) ---
  static const Color primary = Color(0xFF087CF5);      // Electric Blue (Signature Base Brand Color)
  static const Color primaryAccent = Color(0xFF38BDF8);// Sky Blue
  static const Color darkBrand = Color(0xFF03172D);    // Deep Navy
  static const Color background = Color(0xFFF7F9FC);   // Off-white / Cool Grey Background
  static const Color card = Color(0xFFFFFFFF);         // Pure White Cards
  static const Color textMain = Color(0xFF071A2F);     // Dark High-Contrast Main Text
  static const Color textSecondary = Color(0xFF6B7785);// Muted Cool Grey Secondary Text
  static const Color border = Color(0xFFE5EAF0);       // Subtle Border
  
  // Status Colors
  static const Color success = Color(0xFF16A673);      // Emerald Green
  static const Color warning = Color(0xFFF5A623);      // Amber / Gold for Featured
  static const Color error = Color(0xFFE94B5F);        // Vibrant Crimson
  
  // Shading & Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF087CF5), Color(0xFF025DC2)],    // Electric Blue -> Deep Royal Blue Gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF087CF5), Color(0xFF025DC2)],    // Electric Blue -> Deep Royal Blue Gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softBlueFadeGradient = LinearGradient(
    colors: [Color(0xFFE8F2FE), Color(0xFFF3F8FF), Color(0xFFF7F9FC)], // Very subtle soft blue fading to white
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient navyGradient = LinearGradient(
    colors: [Color(0xFF03172D), Color(0xFF07294D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppConstants {
  static const String appName = 'OJIO';
  
  // Base URLs
  static const String baseApiUrl = ApiConfig.baseUrl;
  static const String webBaseApiUrl = ApiConfig.baseUrl;

  // Free quota rules
  static const int maxFreeAds = 2;
  static const double paidAdFee = 49.00;
}

