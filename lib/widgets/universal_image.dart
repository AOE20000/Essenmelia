import 'dart:convert';
import 'package:flutter/material.dart';

class UniversalImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: _errorBuilder,
        );
      } catch (e) {
        imageWidget = _errorWidget();
      }
    } else if (imageUrl.startsWith('http')) {
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: _errorBuilder,
      );
    } else {
      imageWidget = _errorWidget();
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return _errorWidget();
  }

  Widget _errorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white24),
      ),
    );
  }
}
