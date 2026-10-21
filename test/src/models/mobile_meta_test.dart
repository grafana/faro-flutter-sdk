import 'package:faro/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mobile meta models:', () {
    test('Device serializes to Faro spec field names', () {
      final device = Device(
        manufacturer: 'apple',
        modelIdentifier: 'iPhone16,1',
        modelName: 'iPhone 15 Pro',
        brand: 'iPhone',
        isPhysical: true,
        type: 'mobile',
      );

      expect(device.toJson(), {
        'manufacturer': 'apple',
        'model_identifier': 'iPhone16,1',
        'model_name': 'iPhone 15 Pro',
        'brand': 'iPhone',
        'is_physical': true,
        'type': 'mobile',
      });
    });

    test('Device serializes static fields to RFC 004 field names', () {
      final device = Device(
        arch: 'arm64',
        screenWidth: 1080,
        screenHeight: 2400,
        screenDensity: 2.625,
        memoryTotal: 7612,
      );

      final json = device.toJson();

      expect(json, {
        'arch': 'arm64',
        'screen_width': 1080,
        'screen_height': 2400,
        'screen_density': 2.625,
        'memory_total': 7612,
      });
      expect(Device.fromJson(json).toJson(), json);
    });

    test('Device omits static fields it does not have', () {
      expect(Device(manufacturer: 'apple').toJson(), {'manufacturer': 'apple'});
    });

    test('Os serializes the Android API level', () {
      final os = Os(name: 'Android', apiLevel: 35);

      final json = os.toJson();

      expect(json, {'name': 'Android', 'api_level': 35});
      expect(Os.fromJson(json).toJson(), json);
    });

    test('Os serializes to Faro spec field names', () {
      final os = Os(
        name: 'iOS',
        version: '18.1',
        buildId: '22B83',
        detail: 'iOS 18.1',
      );

      expect(os.toJson(), {
        'name': 'iOS',
        'version': '18.1',
        'build_id': '22B83',
        'detail': 'iOS 18.1',
      });
    });

    test('App serializes installationId', () {
      final app = App(
        name: 'QuickPizza',
        version: '1.0.0',
        environment: 'prod',
        namespace: 'flutter',
        installationId: 'install-id',
      );

      expect(app.toJson()['installationId'], 'install-id');
    });

    test('Meta includes structured device and OS fields', () {
      final meta = Meta(
        device: Device(
          manufacturer: 'Google',
          modelIdentifier: 'Pixel 8',
          modelName: 'Pixel 8',
          brand: 'google',
          isPhysical: false,
          type: 'mobile',
        ),
        os: Os(
          name: 'Android',
          version: '15',
          buildId: 'BP1A',
          detail: 'Android 15 (SDK 35)',
        ),
      );

      expect(meta.toJson()['device']['model_identifier'], 'Pixel 8');
      expect(meta.toJson()['os']['build_id'], 'BP1A');
    });

    test(
      'Payload serializes structured mobile meta with legacy attributes',
      () {
        final payload = Payload(
          Meta(
            app: App(name: 'QuickPizza', installationId: 'install-id'),
            session: Session(
              'session-id',
              attributes: {'device_id': 'install-id'},
            ),
            device: Device(
              manufacturer: 'apple',
              modelIdentifier: 'iPad14,3',
              modelName: 'iPad Pro',
              brand: 'iPad',
              isPhysical: false,
              type: 'tablet',
            ),
            os: Os(name: 'iOS', version: '18.1', detail: 'iOS 18.1'),
          ),
        );

        final meta = payload.toJson()['meta'];

        expect(meta['app']['installationId'], 'install-id');
        expect(meta['session']['attributes']['device_id'], 'install-id');
        expect(meta['device'], {
          'manufacturer': 'apple',
          'model_identifier': 'iPad14,3',
          'model_name': 'iPad Pro',
          'brand': 'iPad',
          'is_physical': false,
          'type': 'tablet',
        });
        expect(meta['os'], {
          'name': 'iOS',
          'version': '18.1',
          'detail': 'iOS 18.1',
        });
      },
    );
  });
}
