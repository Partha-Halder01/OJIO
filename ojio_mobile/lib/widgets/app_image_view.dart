import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';

class AppImageView extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? categorySlug;
  final String? title;

  const AppImageView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.categorySlug,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    final fallbackUrl = ListingModel.defaultCategoryPlaceholder(categorySlug, title: title);
    final raw = url?.trim() ?? '';

    if (raw.startsWith('data:image')) {
      try {
        final commaIdx = raw.indexOf(',');
        final b64 = commaIdx != -1 ? raw.substring(commaIdx + 1) : raw;
        final bytes = base64Decode(b64);
        child = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildNetworkFallback(fallbackUrl),
        );
      } catch (e) {
        child = _buildNetworkFallback(fallbackUrl);
      }
    } else if (raw.startsWith('http://') || raw.startsWith('https://')) {
      child = CachedNetworkImage(
        imageUrl: raw,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, _) => Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF087CF5)),
          ),
        ),
        errorWidget: (_, __, ___) => _buildNetworkFallback(fallbackUrl),
      );
    } else {
      child = _buildNetworkFallback(fallbackUrl);
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildNetworkFallback(String fallbackUrl) {
    return CachedNetworkImage(
      imageUrl: fallbackUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(color: const Color(0xFFF1F5F9)),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
