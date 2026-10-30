// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

class PickedFileData {
  final Uint8List bytes;
  final String name;
  final String extension;

  PickedFileData({
    required this.bytes,
    required this.name,
    required this.extension,
  });
}

Future<PickedFileData?> pickImageFile() async {
  final completer = Completer<PickedFileData?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((e) {
      final result = reader.result;
      if (result is Uint8List) {
        final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
        if (!completer.isCompleted) {
          completer.complete(PickedFileData(bytes: result, name: file.name, extension: ext));
        }
      } else if (result is List<int>) {
        final bytes = Uint8List.fromList(result);
        final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
        if (!completer.isCompleted) {
          completer.complete(PickedFileData(bytes: bytes, name: file.name, extension: ext));
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
  });

  return completer.future;
}
