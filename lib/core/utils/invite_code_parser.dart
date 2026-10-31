/// Utility to parse and extract split group invite codes from URLs, fragments, or path segments.
class InviteCodeParser {
  InviteCodeParser._();

  /// Extracts invite code from web URL (query param, hash fragment, or path segment).
  static String? extractInviteCode(Uri uri) {
    // 1. Direct query parameter: ?code=... or ?join=... or ?split=...
    String? code = uri.queryParameters['code'] ??
        uri.queryParameters['join'] ??
        uri.queryParameters['split'];
    if (code != null && code.trim().isNotEmpty) return code.trim();

    // 2. Hash fragment query: #/?code=... or #/split?code=...
    if (uri.hasFragment && uri.fragment.contains('?')) {
      final queryPart = uri.fragment.substring(uri.fragment.indexOf('?') + 1);
      final fragUri = Uri(query: queryPart);
      code = fragUri.queryParameters['code'] ??
          fragUri.queryParameters['join'] ??
          fragUri.queryParameters['split'];
      if (code != null && code.trim().isNotEmpty) return code.trim();
    }

    // 3. Path segments: /join/CODE or /split/CODE
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments[0] == 'join' || segments[0] == 'split' || segments[0] == 'code')) {
      return segments[1].trim();
    }
    return null;
  }
}
