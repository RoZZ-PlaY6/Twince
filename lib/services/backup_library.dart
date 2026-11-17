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
  static const _folderChannel = MethodChannel('twince/backup_folder');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Requests a persistent Documents grant when one is not already available.
  Future<void> ensureAndroidFolder() async {
    if (!_android) return;
    try {
      if (await _folderChannel.invokeMethod<bool>('prepare') == true) return;
      if (await _folderChannel.invokeMethod<bool>('authorize') == true) return;
      throw const BackupNameException(
          'Backup folder access was cancelled. Select Documents to save backups.');
    } on PlatformException catch (error) {
      throw BackupNameException(
          error.message ?? 'Cannot access Documents/Twince.');
    }
  }

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
    if (_android) {
      await ensureAndroidFolder();
      try {
        final uri = await _folderChannel.invokeMethod<String>('create', {
          'name': safe,
          'contents': contents,
        });
        if (uri == null || uri.isEmpty) {
          throw const BackupNameException('Could not create the backup file.');
        }
        await _store(name: safe, path: null, sourceUri: uri);
        return ActiveBackup(name: safe, sourceUri: uri);
      } on PlatformException catch (error) {
        throw BackupNameException(
            error.message ?? 'Could not create the backup file.');
      }
    }
    final path = await writeBackupCopy(safe, contents);
    if (path == null || path.isEmpty) {
      throw const BackupNameException(
        'Could not create the backup file. Check storage availability and try again.',
      );
    }
    await _store(name: safe, path: path, sourceUri: null);
    return ActiveBackup(name: safe, path: path);
  }

  Future<BackupWriteResult> saveCurrent(String contents) async {
    final active = await current();
    if (active == null || !active.canUpdate) {
      return const BackupWriteResult(saved: false, updatedOriginal: false);
    }
    if (_android) {
      await ensureAndroidFolder();
      try {
        final saved =
            await _folderChannel.invokeMapMethod<String, String>('save', {
          'name': active.name,
          'path': active.path,
          'uri': active.sourceUri,
          'contents': contents,
        });
        final uri = saved?['uri'];
        final name = saved?['name'];
        if (uri == null || uri.isEmpty || name == null || name.isEmpty) {
          throw const BackupNameException('Could not save the backup file.');
        }
        await _store(name: name, path: null, sourceUri: uri);
        return BackupWriteResult(
            saved: true, updatedOriginal: uri == active.sourceUri, name: name);
      } on PlatformException catch (error) {
        throw BackupNameException(
            error.message ?? 'Could not save the backup file.');
      }
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
      final renamedUri = await _renameSourceUri(active.sourceUri!, safe);
      if (renamedUri == null || renamedUri.isEmpty) {
        throw const BackupNameException(
          'This file provider cannot rename the original backup. Create a new backup with the desired filename instead.',
        );
      }
      await _store(name: safe, path: null, sourceUri: renamedUri);
      return ActiveBackup(name: safe, path: null, sourceUri: renamedUri);
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

  Future<String?> _renameSourceUri(String uri, String name) async {
    if (kIsWeb || uri.isEmpty) return null;
    try {
      return await _channel.invokeMethod<String>('renameBackup', {
        'uri': uri,
        'name': name,
      });
    } on PlatformException catch (error) {
      debugPrint('Could not rename the imported backup: ${error.message}');
      return null;
    } catch (error) {
      debugPrint('Could not rename the imported backup: $error');
      return null;
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
