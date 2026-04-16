import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class UniversalImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl.startsWith('data:image')) {
      imageWidget = _buildMemoryImage(context);
    } else if (imageUrl.startsWith('http')) {
      imageWidget = _buildNetworkImage(context);
    } else if (imageUrl.isNotEmpty) {
      final file = File(imageUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.medium, // 提高缩放时的过滤质量
          // 优化快速滑动时的体验：淡入效果
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) => _errorWidget(context),
        );
      } else {
        imageWidget = _errorWidget(context);
      }
    } else {
      imageWidget = _errorWidget(context);
    }

    return _applyBorderRadius(imageWidget);
  }

  Widget _buildMemoryImage(BuildContext context) {
    try {
      final base64String = imageUrl.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => _errorWidget(context),
      );
    } catch (e) {
      return _errorWidget(context);
    }
  }

  Widget _buildNetworkImage(BuildContext context) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _loadingPlaceholder(context, loadingProgress);
      },
      errorBuilder: (context, error, stackTrace) => _errorWidget(context),
    );
  }

  Widget _loadingPlaceholder(
    BuildContext context,
    ImageChunkEvent? loadingProgress,
  ) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: CircularProgressIndicator(
          value: loadingProgress?.expectedTotalBytes != null
              ? loadingProgress!.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
              : null,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _applyBorderRadius(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _errorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
