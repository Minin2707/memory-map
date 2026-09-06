import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android network security config', () {
    test('shouldAllowCleartextOnlyForLocalDebugAndPerformanceBuilds', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final mainConfig = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      ).readAsStringSync();
      final debugConfig = File(
        'android/app/src/debug/res/xml/network_security_config.xml',
      ).readAsStringSync();
      final localPerformanceConfig = File(
        'android/app/src/localPerformance/res/xml/network_security_config.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android:networkSecurityConfig="@xml/network_security_config"'),
      );
      expect(
        manifest,
        isNot(contains('android:usesCleartextTraffic="true"')),
      );
      expect(
        mainConfig,
        contains('<base-config cleartextTrafficPermitted="false" />'),
      );
      expect(
        debugConfig,
        contains('<base-config cleartextTrafficPermitted="true" />'),
      );
      expect(
        localPerformanceConfig,
        contains('<base-config cleartextTrafficPermitted="true" />'),
      );
    });
  });
}
