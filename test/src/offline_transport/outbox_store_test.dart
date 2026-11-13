import 'dart:convert';
import 'dart:io';

import 'package:faro/src/offline_transport/outbox_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFile extends Mock implements File {}

class _MockDirectory extends Mock implements Directory {}

final class _FailingWrites extends IOOverrides {
  _FailingWrites(this.stage);

  final String stage;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    if (!path.endsWith('.batch.json.tmp')) return file;
    final failing = _MockFile();
    when(() => failing.writeAsString(any(), flush: true)).thenAnswer((call) {
      if (stage == 'write') {
        throw FileSystemException('Injected write failure', path);
      }
      return file.writeAsString(
        call.positionalArguments.single as String,
        flush: true,
      );
    });
    when(
      () => failing.rename(any()),
    ).thenThrow(FileSystemException('Injected rename failure', path));
    when(failing.delete).thenAnswer((_) => file.delete());
    return failing;
  }
}

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
    test('retries only failed files after indexing a full outbox', () async {
      final directory = _MockDirectory();
      final files = <File>[];
      final deleted = <String>{};
      final reads = <String, int>{};
      var blocked = true;
      for (var index = 0; index < 1000; index++) {
        final file = _MockFile();
        final path = '${root.path}/$index.batch.json';
        final contents = jsonEncode({
          'version': 1,
          'timestamp': now.millisecondsSinceEpoch + index,
          'payload': {'id': index},
        });
        when(() => file.path).thenReturn(path);
        when(() => file.uri).thenReturn(Uri.file(path));
        when(file.length).thenAnswer((_) async => utf8.encode(contents).length);
        when(file.readAsString).thenAnswer((_) async {
          reads[path] = (reads[path] ?? 0) + 1;
          if (index == 0 && blocked) {
            throw const FileSystemException('Injected read failure');
          }
          return contents;
        });
        when(file.delete).thenAnswer((_) async {
          deleted.add(path);
          return file;
        });
        files.add(file);
      }
      when(() => directory.path).thenReturn(root.path);
      when(
        () => directory.create(recursive: true),
      ).thenAnswer((_) async => directory);
      when(() => directory.list(followLinks: false)).thenAnswer(
        (_) => Stream.fromIterable(
          files.where((file) => !deleted.contains(file.path)),
        ),
      );
      final cache = OutboxStore(
        directory: directory,
        maxCount: 1000,
        maxBytes: 1000000,
        maxAge: const Duration(days: 3),
        clock: () => now,
      );
      await cache.retryUnreadableFiles();
      final entries = await cache.pending();
      expect(entries, hasLength(999));
      for (final entry in entries) {
        await cache.pending();
        await cache.remove(entry);
      }
      expect(reads.values.every((count) => count == 1), isTrue);
      expect(await cache.pending(), isEmpty);
      expect(cache.hasUnreadableFiles, isTrue);
      await cache.retryUnreadableFiles();
      expect(reads[files.first.path], 2);
      expect(reads[files.last.path], 1);
      blocked = false;
      await cache.retryUnreadableFiles();
      expect(await cache.pending(), hasLength(1));
      expect(reads[files.first.path], 3);
      expect(cache.hasUnreadableFiles, isFalse);
      await cache.retryUnreadableFiles();
      expect(reads[files.first.path], 3);
      verify(() => directory.list(followLinks: false)).called(1);
    });

    for (final recovery in [
      'deleted',
      'corrupt',
      'expired',
      'oversized',
      'clear',
    ]) {
      test('handles $recovery files after a failed startup read', () async {
        final directory = _MockDirectory();
        final realDirectory = Directory('${root.path}/outbox');
        await realDirectory.create();
        final file = File('${realDirectory.path}/blocked.batch.json');
        await file.writeAsString(
          jsonEncode({
            'version': 1,
            'timestamp': now.millisecondsSinceEpoch,
            'payload': {'id': 'blocked'},
          }),
        );
        final wrapped = _MockFile();
        when(() => wrapped.path).thenReturn(file.path);
        when(() => wrapped.uri).thenReturn(file.uri);
        when(wrapped.length).thenAnswer((_) => file.length());
        var blocked = true;
        when(wrapped.readAsString).thenAnswer((_) {
          if (blocked) throw const FileSystemException('Injected read failure');
          return file.readAsString();
        });
        when(wrapped.delete).thenAnswer((_) => file.delete());
        when(() => directory.path).thenReturn(realDirectory.path);
        when(
          () => directory.create(recursive: true),
        ).thenAnswer((_) async => realDirectory);
        when(
          () => directory.list(followLinks: false),
        ).thenAnswer((_) => Stream.fromIterable([wrapped]));
        final cache = OutboxStore(
          directory: directory,
          maxCount: 1000,
          maxBytes: 1000,
          maxAge: const Duration(days: 3),
          clock: () => now,
        );
        expect(await cache.pending(), isEmpty);
        expect(cache.hasUnreadableFiles, isTrue);
        blocked = false;
        switch (recovery) {
          case 'deleted':
            await file.delete();
          case 'corrupt':
            await file.writeAsString('broken');
          case 'expired':
            now = now.add(const Duration(days: 4));
          case 'oversized':
            await file.writeAsString('x' * 1001);
          case 'clear':
            await cache.clear();
        }
        await cache.retryUnreadableFiles();
        expect(cache.hasUnreadableFiles, isFalse);
        expect(await cache.pending(), isEmpty);
        expect(file.existsSync(), isFalse);
      });
    }

    for (final (limit, stage) in [
      ('count', 'write'),
      ('count', 'rename'),
      ('bytes', 'write'),
      ('bytes', 'rename'),
    ]) {
      test('failed $stage preserves batches at the $limit cap', () async {
        final cache = store(
          count: limit == 'count' ? 1 : 1000,
          bytes: limit == 'bytes' ? 100 : 100000,
        );
        final original = await cache.enqueue('{"id":1}');
        now = now.add(const Duration(seconds: 1));
        await IOOverrides.runWithIOOverrides(() async {
          await expectLater(
            cache.enqueue('{"id":2}'),
            throwsA(isA<FileSystemException>()),
          );
        }, _FailingWrites(stage));
        expect(original?.file.existsSync(), isTrue);
        final retained = await store().pending();
        expect(await retained.single.readPayload(), {'id': 1});
        await cache.enqueue('{"id":3}');
        expect(await (await cache.pending()).single.readPayload(), {'id': 3});
      });
    }

    test('unreadable startup file does not block valid batches', () async {
      final cache = store();
      final first = await cache.enqueue('{"id":1}');
      now = now.add(const Duration(seconds: 1));
      final second = await cache.enqueue('{"id":2}');
      if (first == null || second == null) fail('Expected two saved batches.');
      final unreadable = _MockFile();
      when(() => unreadable.path).thenReturn(first.file.path);
      when(unreadable.length).thenAnswer((_) => first.file.length());
      var blocked = true;
      when(unreadable.readAsString).thenAnswer((_) {
        if (blocked) throw const FileSystemException('Injected read failure');
        return first.file.readAsString();
      });
      final directory = _MockDirectory();
      when(() => directory.path).thenReturn(cache.directory.path);
      when(
        () => directory.create(recursive: true),
      ).thenAnswer((_) async => cache.directory);
      when(
        () => directory.list(followLinks: false),
      ).thenAnswer((_) => Stream.fromIterable([unreadable, second.file]));
      final recovered = OutboxStore(
        directory: directory,
        maxCount: 1000,
        maxBytes: 100000,
        maxAge: const Duration(days: 3),
        clock: () => now,
      );
      expect(await (await recovered.pending()).single.readPayload(), {'id': 2});
      expect(recovered.hasUnreadableFiles, isTrue);
      expect(first.file.existsSync(), isTrue);
      for (var index = 0; index < 10; index++) {
        expect(await recovered.pending(), hasLength(1));
      }
      verify(() => directory.list(followLinks: false)).called(1);
      blocked = false;
      await recovered.retryUnreadableFiles();
      expect(await recovered.pending(), hasLength(2));
      expect(recovered.hasUnreadableFiles, isFalse);
    });

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
