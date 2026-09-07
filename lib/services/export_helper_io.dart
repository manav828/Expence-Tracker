// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveOrShareFile({
  required String filename,
  required String content,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsString(content);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    subject: 'Apex Spend Export - $filename',
  );
}
