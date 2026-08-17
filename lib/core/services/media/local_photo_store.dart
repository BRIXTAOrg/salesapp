import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

abstract final class LocalPhotoStore {
  static Future<String> persist(
    XFile source, {
    String prefix = 'photo',
  }) async {
    final base = await getDatabasesPath();
    final folder = Directory('$base/kamdhenu_photos'); //bucket name in db is kamdhenu_photos - DO NOT CHANGE

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final extension = _extension(source.path);
    final target = File(
      '${folder.path}/'
      '$prefix-${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    await File(source.path).copy(target.path);
    return target.path;
  }

  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '.jpg';

    final ext = path.substring(dot).toLowerCase();
    if (ext.length > 6) return '.jpg';
    return ext;
  }
}
