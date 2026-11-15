import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

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

Future<PickedFileData?> pickImageFile({bool useCamera = false}) async {
  try {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return PickedFileData(bytes: bytes, name: name, extension: ext);
  } catch (_) {
    return null;
  }
}

Future<List<PickedFileData>> pickMultipleImageFiles() async {
  try {
    final picker = ImagePicker();
    final List<XFile> files = await picker.pickMultiImage();
    if (files.isEmpty) return <PickedFileData>[];
    final List<PickedFileData> results = [];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final name = f.name;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
      results.add(PickedFileData(bytes: bytes, name: name, extension: ext));
    }
    return results;
  } catch (_) {
    return <PickedFileData>[];
  }
}
