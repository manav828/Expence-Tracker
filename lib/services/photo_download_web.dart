// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Direct browser download on Web
Future<bool> saveOrSharePhoto({
  required String url,
  required String fileName,
}) async {
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..target = '_blank';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  }
}

/// Downloads multiple photos on Web by triggering browser downloads
Future<int> saveOrShareMultiplePhotos({
  required List<String> urls,
  required String groupName,
}) async {
  int count = 0;
  for (int i = 0; i < urls.length; i++) {
    final success = await saveOrSharePhoto(
      url: urls[i],
      fileName: '${groupName}_photo_${i + 1}.jpg',
    );
    if (success) count++;
  }
  return count;
}
