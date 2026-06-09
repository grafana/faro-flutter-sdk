import 'package:faro/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstallationId:', () {
    test('should return the value when printed', () {
      final installationId = InstallationId('test_installation_id');
      final printedInstallationId = '$installationId';
      expect(printedInstallationId, 'test_installation_id');
    });
  });
}
