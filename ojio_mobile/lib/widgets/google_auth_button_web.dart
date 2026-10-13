import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget googleWebButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    size: web.GSIButtonSize.large,
    shape: web.GSIButtonShape.pill,
    text: web.GSIButtonText.continueWith,
  ),
);
