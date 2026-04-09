import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpTrackingFilter:', () {
    late HttpTrackingFilter filter;

    setUp(() {
      filter = HttpTrackingFilter();
    });

    group('before configure', () {
      test('should track all URLs by default', () {
        expect(
          filter.shouldTrack(Uri.parse('https://example.com/api')),
          isTrue,
        );
      });
    });

    group('collector URL filtering', () {
      test('should not track the collector URL', () {
        filter.configure(
          collectorUrl: 'https://collector.grafana.net/collect',
          ignoreUrls: null,
        );

        expect(
          filter.shouldTrack(
            Uri.parse('https://collector.grafana.net/collect'),
          ),
          isFalse,
        );
      });

      test('should track URLs that differ from the collector URL', () {
        filter.configure(
          collectorUrl: 'https://collector.grafana.net/collect',
          ignoreUrls: null,
        );

        expect(
          filter.shouldTrack(Uri.parse('https://api.example.com/data')),
          isTrue,
        );
      });

      test('should track all URLs when collector URL is null', () {
        filter.configure(collectorUrl: null, ignoreUrls: null);

        expect(
          filter.shouldTrack(Uri.parse('https://anything.com')),
          isTrue,
        );
      });
    });

    group('ignoreUrls pattern filtering', () {
      test('should not track URLs matching an ignore pattern', () {
        filter.configure(
          collectorUrl: null,
          ignoreUrls: [RegExp(r'analytics\.example\.com')],
        );

        expect(
          filter.shouldTrack(
            Uri.parse('https://analytics.example.com/track'),
          ),
          isFalse,
        );
      });

      test('should track URLs not matching any ignore pattern', () {
        filter.configure(
          collectorUrl: null,
          ignoreUrls: [RegExp(r'analytics\.example\.com')],
        );

        expect(
          filter.shouldTrack(Uri.parse('https://api.example.com/data')),
          isTrue,
        );
      });

      test('should support multiple ignore patterns', () {
        filter.configure(
          collectorUrl: null,
          ignoreUrls: [
            RegExp(r'analytics\.example\.com'),
            RegExp(r'tracking\.vendor\.io'),
          ],
        );

        expect(
          filter.shouldTrack(
            Uri.parse('https://analytics.example.com/event'),
          ),
          isFalse,
        );
        expect(
          filter.shouldTrack(
            Uri.parse('https://tracking.vendor.io/pixel'),
          ),
          isFalse,
        );
        expect(
          filter.shouldTrack(Uri.parse('https://api.myapp.com/users')),
          isTrue,
        );
      });

      test('should track all URLs when ignoreUrls is null', () {
        filter.configure(collectorUrl: null, ignoreUrls: null);

        expect(
          filter.shouldTrack(Uri.parse('https://anything.com')),
          isTrue,
        );
      });

      test('should track all URLs when ignoreUrls is empty', () {
        filter.configure(collectorUrl: null, ignoreUrls: []);

        expect(
          filter.shouldTrack(Uri.parse('https://anything.com')),
          isTrue,
        );
      });
    });

    group('combined filtering', () {
      test('should filter both collector URL and ignore patterns', () {
        filter.configure(
          collectorUrl: 'https://collector.grafana.net/collect',
          ignoreUrls: [RegExp(r'analytics\.example\.com')],
        );

        expect(
          filter.shouldTrack(
            Uri.parse('https://collector.grafana.net/collect'),
          ),
          isFalse,
        );
        expect(
          filter.shouldTrack(
            Uri.parse('https://analytics.example.com/track'),
          ),
          isFalse,
        );
        expect(
          filter.shouldTrack(Uri.parse('https://api.myapp.com/data')),
          isTrue,
        );
      });
    });
  });
}
