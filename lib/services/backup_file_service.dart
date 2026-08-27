import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

class BackupFileService {
  const BackupFileService();

  static const XTypeGroup _jsonType = XTypeGroup(
    label: 'ไฟล์สำรอง KeepKapook',
    extensions: <String>['json'],
    mimeTypes: <String>['application/json'],
    uniformTypeIdentifiers: <String>['public.json'],
  );

  Future<String> appVersion() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.trim();
    return build.isEmpty ? info.version : '${info.version}+$build';
  }

  Future<String?> pickBackupJson() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_jsonType],
      confirmButtonText: 'เลือกไฟล์สำรอง',
    );
    return file?.readAsString();
  }

  Future<void> shareBackup({
    required String json,
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'สำรองข้อมูล KeepKapook',
        subject: 'ไฟล์สำรองข้อมูล KeepKapook',
        files: <XFile>[
          XFile.fromData(
            Uint8List.fromList(utf8.encode(json)),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: <String>[fileName],
        sharePositionOrigin: sharePositionOrigin,
        downloadFallbackEnabled: true,
      ),
    );
  }
}
