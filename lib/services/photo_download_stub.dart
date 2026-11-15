import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Downloads a photo by URL and saves/shares it on mobile or desktop platforms.
Future<bool> saveOrSharePhoto({
  required String url,
  required String fileName,
}) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return false;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes);

    // Share or trigger native save
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Saved from ExpenCircle Trip Vault',
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// Downloads multiple photos and shares/saves them in batch.
Future<int> saveOrShareMultiplePhotos({
  required List<String> urls,
  required String groupName,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final List<XFile> xFiles = [];

    for (int i = 0; i < urls.length; i++) {
      try {
        final res = await http.get(Uri.parse(urls[i]));
        if (res.statusCode == 200) {
          final file = File('${dir.path}/${groupName}_photo_${i + 1}.jpg');
          await file.writeAsBytes(res.bodyBytes);
          xFiles.add(XFile(file.path));
        }
      } catch (_) {}
    }

    if (xFiles.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          text: 'Saved ${xFiles.length} photos from $groupName Trip Vault',
        ),
      );
    }
    return xFiles.length;
  } catch (_) {
    return 0;
  }
}
