import 'dart:typed_data';

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
  // Mobile / Desktop stub without native plugin requirement
  return null;
}
