import 'package:flutter/material.dart';
import 'api_config.dart';

class AppConstants {
  static const String appName = 'OJIO';
  
  // API Endpoints
  static const String baseApiUrl = ApiConfig.baseUrl;
  static const String webBaseApiUrl = ApiConfig.baseUrl;
  static String get storageBaseUrl => ApiConfig.origin;

  // --- Exact Color Palette Extracted from OJIO_LOGO.png ---
  // Electric / Vibrant Cyan Blue from the logo lettermark & glowing accents
  static const Color primaryColor = Color(0xFF007DFE); 
  static const Color primaryLight = Color(0xFF389BFF);
  static const Color primaryDark = Color(0xFF005EC4);

  // Deep Navy / Midnight Dark tones from the logo background
  static const Color navyDark = Color(0xFF021327);
  static const Color navySurface = Color(0xFF071D36);

  // Functional Accent Colors
  static const Color accentColor = Color(0xFF00D287); // Vibrant Emerald Green for "Post Ad"
  static const Color warningColor = Color(0xFFFFB020); // Amber for "Featured" badges
  
  // Clean Surface & Typography Colors
  static const Color backgroundColor = Color(0xFFF4F7FB);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF091E3A);
  static const Color textSecondary = Color(0xFF5A6E85);
  static const Color borderSubtle = Color(0xFFE2E8F0);
}
