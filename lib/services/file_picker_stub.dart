import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
    if (!kIsWeb) {
      if (useCamera) {
        final status = await Permission.camera.status;
        if (!status.isGranted) {
          final res = await Permission.camera.request();
          if (!res.isGranted) return null;
        }
      } else {
        final status = await Permission.photos.status;
        if (!status.isGranted && !status.isLimited) {
          final storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            final res = await Permission.photos.request();
            if (!res.isGranted && !res.isLimited) {
              final sRes = await Permission.storage.request();
              if (!sRes.isGranted) return null;
            }
          }
        }
      }
    }

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
    if (!kIsWeb) {
      final status = await Permission.photos.status;
      if (!status.isGranted && !status.isLimited) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          final res = await Permission.photos.request();
          if (!res.isGranted && !res.isLimited) {
            final sRes = await Permission.storage.request();
            if (!sRes.isGranted) return <PickedFileData>[];
          }
        }
      }
    }

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
