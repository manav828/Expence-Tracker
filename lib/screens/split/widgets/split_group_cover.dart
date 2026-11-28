import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/pixabay_service.dart';

class SplitGroupCover extends StatelessWidget {
  const SplitGroupCover({super.key, required this.title, this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallbackUrl = PixabayService.getCuratedFallback(title);
    final savedUrl = imageUrl?.trim();
    return Image.network(
      savedUrl == null || savedUrl.isEmpty ? fallbackUrl : savedUrl,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder:
          (_, __, ___) =>
              savedUrl != null && savedUrl.isNotEmpty && savedUrl != fallbackUrl
                  ? Image.network(
                    fallbackUrl,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                  : _placeholder(),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: AppColors.primaryLight,
    child: Image.asset(
      'screen/split/split_home_illustration.png',
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}
