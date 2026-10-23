import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_files.dart';
import 'backup_policy.dart';

class ActiveBackup {
  const ActiveBackup({
    required this.name,
    this.path,
    this.sourceUri,
  });

  final String name;
  final String? path;
  final String? sourceUri;

  bool get canUpdate =>
      (path != null && path!.isNotEmpty) ||
      (sourceUri != null && sourceUri!.isNotEmpty);
}

class BackupWriteResult {
  const BackupWriteResult({
    required this.saved,
    required this.updatedOriginal,
    this.name,
  });

  final bool saved;
  final bool updatedOriginal;
  final String? name;
}

class BackupLibrary {
  BackupLibrary._();
  static final instance = BackupLibrary._();
  static const _nameKey = 'twince_active_backup_name';
  static const _pathKey = 'twince_active_backup_path';
  static const _uriKey = 'twince_active_backup_uri';
  static const _channel = MethodChannel('twince/import');

  Future<ActiveBackup?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey);
    if (name == null || name.isEmpty) return null;
    return ActiveBackup(
      name: name,
      path: prefs.getString(_pathKey),
      sourceUri: prefs.getString(_uriKey),
    );
  }

  Future<ActiveBackup> rememberImport({
    required String suggestedName,
    required String contents,
    String? externalPath,
    String? sourceUri,
  }) async {
    if (contents.trim().isEmpty) {
      throw const BackupNameException('The selected backup file is empty.');
    }
    final name = normalizeBackupName(suggestedName);
    final uri = sourceUri != null && sourceUri.isNotEmpty ? sourceUri : null;
    final selectedPath =
        externalPath != null && externalPath.isNotEmpty ? externalPath : null;
    await _store(
      name: name,
      path: uri == null ? selectedPath : null,
      sourceUri: uri,
    );
    return ActiveBackup(
      name: name,
      path: uri == null ? selectedPath : null,
      sourceUri: uri,
    );
  }

  Future<ActiveBackup> createNew({
    required String name,
    required String contents,
  }) async {
    final safe = normalizeBackupName(name);
    final path = await writeBackupCopy(safe, contents);
    await _store(name: safe, path: path, sourceUri: null);
    return ActiveBackup(name: safe, path: path);
  }

  Future<BackupWriteResult> saveCurrent(String contents) async {
    final active = await current();
    if (active == null || !active.canUpdate) {
      return const BackupWriteResult(saved: false, updatedOriginal: false);
    }
    if (active.sourceUri != null && active.sourceUri!.isNotEmpty) {
      final updated = await _writeSourceUri(active.sourceUri, contents);
      return BackupWriteResult(
        saved: updated,
        updatedOriginal: updated,
        name: active.name,
      );
    }
    final updated = active.path != null && active.path!.isNotEmpty
        ? await writeExternalBackup(active.path!, contents)
        : false;
    return BackupWriteResult(
      saved: updated,
      updatedOriginal: updated,
      name: active.name,
    );
  }

  Future<ActiveBackup> rename(String requestedName) async {
    final active = await current();
    final safe = normalizeBackupName(requestedName);
    if (active == null) {
      throw const BackupNameException('There is no backup file to rename.');
    }
    if (active.sourceUri != null && active.sourceUri!.isNotEmpty) {
      throw const BackupNameException(
        'This file provider cannot rename the original backup. Create a new backup with the desired filename instead.',
      );
    }
    if (active.path == null || active.path!.isEmpty) {
      throw const BackupNameException(
        'There is no backup file to rename.',
      );
    }
    final renamed = await renameBackupCopy(active.path, safe);
    if (renamed == null) {
      throw const BackupNameException(
        'Could not rename the backup file. The current file is unchanged.',
      );
    }
    await _store(name: safe, path: renamed, sourceUri: active.sourceUri);
    return ActiveBackup(
      name: safe,
      path: renamed,
      sourceUri: active.sourceUri,
    );
  }

  Future<void> _store({
    required String name,
    required String? path,
    required String? sourceUri,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    if (path == null || path.isEmpty) {
      await prefs.remove(_pathKey);
    } else {
      await prefs.setString(_pathKey, path);
    }
    if (sourceUri == null || sourceUri.isEmpty) {
      await prefs.remove(_uriKey);
    } else {
      await prefs.setString(_uriKey, sourceUri);
    }
  }

  Future<bool> _writeSourceUri(String? uri, String contents) async {
    if (kIsWeb || uri == null || uri.isEmpty) return false;
    try {
      final wrote = await _channel.invokeMethod<bool>('writeBackup', {
        'uri': uri,
        'contents': contents,
      });
      return wrote == true;
    } on PlatformException catch (error) {
      debugPrint('Could not update the imported backup: ${error.message}');
      return false;
    } catch (error) {
      debugPrint('Could not update the imported backup: $error');
      return false;
    }
  }
}
