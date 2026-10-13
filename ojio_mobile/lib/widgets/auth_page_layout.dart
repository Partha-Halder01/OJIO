import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Fixed branding above an independently scrollable authentication form.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.children,
    this.dark = false,
    this.busy = false,
  });

  final List<Widget> children;
  final bool dark;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: !busy,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: dark ? AppColors.darkBrand : const Color(0xFFD8EDFF),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/auth_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                excludeFromSemantics: true,
              ),
              if (dark)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xED03172D),
                        Color(0x66032957),
                        Color(0xF003172D),
                      ],
                      stops: [0, 0.48, 1],
                    ),
                  ),
                ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 500;
                    return Column(
                      children: [
                        SizedBox(
                          height: compact ? 116 : 180,
                          child: Padding(
                            padding: EdgeInsets.only(top: compact ? 32 : 48),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ColorFiltered(
                                  // Preserve the blue accent and darken white letters on the light background.
                                  colorFilter: dark
                                      ? const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.dst,
                                        )
                                      : const ColorFilter.matrix([
                                          -0.02024,
                                          0,
                                          0,
                                          0,
                                          8.162,
                                          -0.40891,
                                          0,
                                          0,
                                          0,
                                          127.271,
                                          -0.80972,
                                          0,
                                          0,
                                          0,
                                          251.478,
                                          0,
                                          0,
                                          0,
                                          1,
                                          0,
                                        ]),
                                  child: Image.asset(
                                    'assets/images/logo_tight.png',
                                    width: compact ? 130 : 180,
                                    height: compact ? 48 : 72,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(height: compact ? 4 : 8),
                                SizedBox(
                                  height: compact ? 24 : 36,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text.rich(
                                      const TextSpan(
                                        children: [
                                          TextSpan(text: 'Buy'),
                                          TextSpan(
                                            text: ' • ',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          TextSpan(text: 'Sell'),
                                          TextSpan(
                                            text: ' • ',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          TextSpan(text: 'Connect'),
                                        ],
                                      ),
                                      style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: dark
                                            ? Colors.white
                                            : AppColors.darkBrand,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.viewInsetsOf(context).bottom,
                            ),
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  child: _form(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: busy
                          ? null
                          : () => Navigator.maybePop(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: dark ? Colors.white : AppColors.darkBrand,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD7E3F1), width: 1.3),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppColors.darkBrand.withAlpha(18), blurRadius: 24),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          key: const Key('auth-frosted-form'),
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFF8FBFF).withAlpha(135),
                  const Color(0xFFF8FBFF).withAlpha(205),
                ],
                stops: const [0, 0.5],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withAlpha(145)),
            ),
            child: Theme(
              data: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  bodyColor: AppColors.darkBrand,
                  displayColor: AppColors.darkBrand,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white.withAlpha(170),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  labelStyle: GoogleFonts.outfit(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIconColor: AppColors.darkBrand,
                  suffixIconColor: AppColors.darkBrand,
                  border: outline,
                  enabledBorder: outline,
                  focusedBorder: outline.copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                dividerTheme: const DividerThemeData(color: Color(0xFFD7E3F1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
