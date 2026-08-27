import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android backup rules', () {
    test('shouldExcludePrivateMediaCacheFromBackupAndDeviceTransfer', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final fullBackupContent = File(
        'android/app/src/main/res/xml/full_backup_content.xml',
      ).readAsStringSync();
      final dataExtractionRules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android:fullBackupContent="@xml/full_backup_content"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(manifest, isNot(contains('android:allowBackup="false"')));

      expect(
        fullBackupContent,
        contains('<exclude domain="file" path="private_media_cache/" />'),
      );
      expect(
        fullBackupContent,
        contains('<exclude domain="root" path="private_media_cache/" />'),
      );

      expect(
        dataExtractionRules,
        contains('<cloud-backup>'),
      );
      expect(
        dataExtractionRules,
        contains('<device-transfer>'),
      );
      expect(
        dataExtractionRules,
        contains('<exclude domain="file" path="private_media_cache/" />'),
      );
      expect(
        dataExtractionRules,
        contains('<exclude domain="root" path="private_media_cache/" />'),
      );
    });
  });
}
