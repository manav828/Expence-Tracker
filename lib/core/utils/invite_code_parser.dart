/// Utility to parse and extract split group invite codes from URLs, fragments, or path segments.
class InviteCodeParser {
  InviteCodeParser._();

  /// Checks if a string looks like an invite code and not an OAuth PKCE token/UUID.
  static bool _isValidInviteCode(String? code) {
    if (code == null) return false;
    final clean = code.trim();
    // OAuth authorization codes are 36-char UUIDs with hyphens (e.g. 938368ff-b387-46f2-b8d2-772d518c29f2)
    if (clean.isEmpty || clean.length > 16 || clean.contains('-')) {
      return false;
    }
    return true;
  }

  /// Extracts invite code from web URL (query param, hash fragment, or path segment).
  static String? extractInviteCode(Uri uri) {
    // 1. Direct query parameter: ?code=... or ?join=... or ?split=...
    String? code = uri.queryParameters['code'] ??
        uri.queryParameters['join'] ??
        uri.queryParameters['split'];
    if (_isValidInviteCode(code)) return code!.trim();

    // 2. Hash fragment query: #/?code=... or #/split?code=...
    if (uri.hasFragment && uri.fragment.contains('?')) {
      final queryPart = uri.fragment.substring(uri.fragment.indexOf('?') + 1);
      final fragUri = Uri(query: queryPart);
      code = fragUri.queryParameters['code'] ??
          fragUri.queryParameters['join'] ??
          fragUri.queryParameters['split'];
      if (_isValidInviteCode(code)) return code!.trim();
    }

    // 3. Path segments: /join/CODE or /split/CODE
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments[0] == 'join' || segments[0] == 'split' || segments[0] == 'code')) {
      final segCode = segments[1].trim();
      if (_isValidInviteCode(segCode)) return segCode;
    }
    return null;
  }
}
