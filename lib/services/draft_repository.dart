import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Demo ini hanya menyimpan satu draft pada SATU perangkat.
/// Tidak memerlukan login, tabel database, maupun Worksheet 9.
class DraftRepository {
  static const _draftKey = 'kosfinder_device_demo_draft_v1';
  static const _photoFolderName = 'kosfinder_photos';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<Map<String, dynamic>> load() async {
    final raw = await _prefs.getString(_draftKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  Future<void> save(Map<String, dynamic> draft) async {
    await _prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<Directory> _photoDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/$_photoFolderName');
    await folder.create(recursive: true);
    return folder;
  }

  /// Memastikan path target benar-benar berada di dalam folder foto milik
  /// aplikasi (mencegah penghapusan file di luar direktori yang diizinkan).
  static bool isPathInsideDirectory(String targetPath, String baseDirPath) {
    final normalizedBase = _normalizePath(baseDirPath);
    final normalizedTarget = _normalizePath(targetPath);
    if (normalizedTarget.contains('..')) return false;
    final prefix = normalizedBase.endsWith('/')
        ? normalizedBase
        : '$normalizedBase/';
    return normalizedTarget.startsWith(prefix) &&
        normalizedTarget.length > prefix.length;
  }

  static String _normalizePath(String path) =>
      path.replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');

  Future<String> savePermanentPhoto(XFile selected) async {
    final ext = selected.name.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png'}.contains(ext)) {
      throw const FormatException('Foto harus berupa JPG/JPEG/PNG.');
    }
    if (await selected.length() > 5 * 1024 * 1024) {
      throw const FormatException('Ukuran foto maksimal 5 MB.');
    }

    final folder = await _photoDirectory();
    final output = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    await selected.saveTo(output.path);
    return output.path;
  }

  /// Pengayaan: menghapus file foto lokal lama hanya jika path tervalidasi
  /// berada di dalam folder `kosfinder_photos` milik aplikasi.
  Future<bool> deleteSafeLocalPhoto(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty) return false;
    final folder = await _photoDirectory();
    final resolvedBase = folder.resolveSymbolicLinksSync();
    final candidate = File(photoPath);
    if (!await candidate.exists()) return false;

    final resolvedTarget = candidate.resolveSymbolicLinksSync();
    if (!isPathInsideDirectory(resolvedTarget, resolvedBase)) {
      throw const FileSystemException(
        'Path foto berada di luar direktori penyimpanan aplikasi.',
      );
    }

    await candidate.delete();
    return true;
  }
}
