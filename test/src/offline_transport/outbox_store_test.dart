import 'dart:convert';
import 'dart:io';

import 'package:faro/src/offline_transport/outbox_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late DateTime now;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('faro_outbox_store_');
    now = DateTime.utc(2026, 11, 12);
  });
  tearDown(() async => root.delete(recursive: true));

  OutboxStore store({int count = 1000, int bytes = 100000, File? legacy}) {
    return OutboxStore(
      directory: Directory('${root.path}/outbox'),
      maxCount: count,
      maxBytes: bytes,
      maxAge: const Duration(days: 3),
      legacyFile: legacy,
      clock: () => now,
    );
  }

  group('OutboxStore:', () {
    test(
      'an interrupted legacy import does not duplicate committed entries',
      () async {
        final legacy = File('${root.path}/rum_log.json');
        final record = {
          'timestamp': now.millisecondsSinceEpoch,
          'payload': {'id': 1},
        };
        await legacy.writeAsString(jsonEncode(record));
        final cache = store(legacy: legacy);
        await cache.directory.create();
        final stamp = now.millisecondsSinceEpoch.toString().padLeft(16, '0');
        await File(
          '${cache.directory.path}/$stamp-legacy-0.batch.json',
        ).writeAsString(jsonEncode({'version': 1, ...record}));
        expect(await cache.pending(), hasLength(1));
        expect(legacy.existsSync(), isFalse);
      },
    );

    test('invalid timestamps cannot block valid stored batches', () async {
      final cache = store();
      await cache.enqueue('{"id":1}');
      await File('${cache.directory.path}/bad.batch.json').writeAsString(
        '{"version":1,"timestamp":-9223372036854775808,"payload":{}}',
      );
      expect(await store().pending(), hasLength(1));
    });

    test('recovers the exact committed payload after recreation', () async {
      final payload = {
        'unknown': {'original': true},
        'meta': {'session': 'old'},
      };
      final entry = await store().enqueue(jsonEncode(payload));
      expect(entry, isNotNull);
      final recovered = await store().pending();
      expect(recovered, hasLength(1));
      expect(await recovered.single.readPayload(), payload);
    });

    test('serializes concurrent writes without losing any batches', () async {
      final cache = store();
      await Future.wait(
        List.generate(20, (index) => cache.enqueue('{"id":$index}')),
      );
      final entries = await cache.pending();
      expect(entries, hasLength(20));
      final payloads = await Future.wait(
        entries.map((entry) => entry.readPayload()),
      );
      expect(
        payloads.map((payload) => payload['id']),
        unorderedEquals(List.generate(20, (index) => index)),
      );
    });

    test('evicts the oldest batch at the count limit', () async {
      final cache = store(count: 2);
      await cache.enqueue('{"id":1}');
      now = now.add(const Duration(seconds: 1));
      await cache.enqueue('{"id":2}');
      now = now.add(const Duration(seconds: 1));
      await cache.enqueue('{"id":3}');
      final entries = await cache.pending();
      expect(await entries.first.readPayload(), {'id': 2});
      expect(await entries.last.readPayload(), {'id': 3});
    });

    test(
      'enforces actual encoded bytes including unicode and envelope',
      () async {
        final cache = store(bytes: 160);
        await cache.enqueue('{"id":"\u00e9\u00e9\u00e9\u00e9"}');
        now = now.add(const Duration(seconds: 1));
        await cache.enqueue('{"id":"second"}');
        final entries = await cache.pending();
        expect(
          entries.fold(0, (sum, entry) => sum + entry.bytes),
          lessThanOrEqualTo(160),
        );
        for (final entry in entries) {
          expect(entry.bytes, await entry.file.length());
        }
      },
    );

    test('rejects an oversized batch without evicting saved data', () async {
      final cache = store(bytes: 150);
      await cache.enqueue('{"id":1}');
      expect(await cache.enqueue(jsonEncode({'large': 'x' * 200})), isNull);
      expect(await cache.pending(), hasLength(1));
    });

    test('expires batches without attempting network delivery', () async {
      final cache = store();
      await cache.enqueue('{"id":1}');
      now = now.add(const Duration(days: 4));
      expect(await cache.pending(), isEmpty);
      expect(await store().pending(), isEmpty);
    });

    test('skips corrupt records and uncommitted temporary files', () async {
      final cache = store();
      await cache.enqueue('{"id":1}');
      await File(
        '${cache.directory.path}/corrupt.batch.json',
      ).writeAsString('broken');
      await File(
        '${cache.directory.path}/partial.batch.json.tmp',
      ).writeAsString('partial');
      final recovered = await store().pending();
      expect(recovered, hasLength(1));
      expect(await recovered.single.readPayload(), {'id': 1});
    });

    test(
      'imports valid legacy entries and preserves historical metadata',
      () async {
        final legacy = File('${root.path}/rum_log.json');
        final original = {
          'meta': {
            'session': {'id': 'old'},
          },
          'events': [
            {'name': 'saved'},
          ],
        };
        final line = jsonEncode({
          'timestamp': now.millisecondsSinceEpoch,
          'payload': original,
        });
        await legacy.writeAsString('bad-json\n$line\n');
        final entries = await store(legacy: legacy).pending();
        expect(entries, hasLength(1));
        expect(await entries.single.readPayload(), original);
        expect(legacy.existsSync(), isFalse);
        expect(await store(legacy: legacy).pending(), hasLength(1));
      },
    );

    test('persists retry deadlines across restart', () async {
      final deadline = now.add(const Duration(minutes: 5));
      await store().writeRetryState(deadline, 3);
      expect(await store().readRetryState(), (retryAt: deadline, failures: 3));
      final cache = store();
      await cache.writeRetryState(null, 0);
      expect(await cache.readRetryState(), (retryAt: null, failures: 0));
    });

    test('clear discards legacy data without migrating it', () async {
      final legacy = File('${root.path}/rum_log.json');
      await legacy.writeAsString('sensitive-invalid-data');
      final cache = store(legacy: legacy);
      await cache.clear();
      expect(legacy.existsSync(), isFalse);
      expect(await cache.pending(), isEmpty);
    });

    test(
      'a storage error releases the operation lock for later recovery',
      () async {
        final cache = store();
        await File(cache.directory.path).writeAsString('blocks-directory');
        await expectLater(
          cache.enqueue('{"id":1}'),
          throwsA(isA<FileSystemException>()),
        );
        await File(cache.directory.path).delete();
        await cache.enqueue('{"id":2}');
        expect(await cache.pending(), hasLength(1));
      },
    );
  });
}
