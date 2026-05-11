import 'package:faro/src/tracing/span_exception_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpanExceptionOptions', () {
    group('mergeWith', () {
      test('mergeWith(null) returns this', () {
        const options = SpanExceptionOptions(recordException: false);

        expect(identical(options, options.mergeWith(null)), isTrue);
      });

      test('single field override preserves others', () {
        final globalOptions = SpanExceptionOptions(
          exceptionSanitizer: (error, stackTrace) {
            return const SanitizedSpanException(
              type: 'Exception',
              message: 'global',
            );
          },
        );

        final merged = globalOptions.mergeWith(
          const SpanExceptionOptions(recordException: false),
        );

        expect(merged.recordException, isFalse);
        expect(merged.setStatusOnException, isTrue);
        expect(
          merged.exceptionSanitizer,
          same(globalOptions.exceptionSanitizer),
        );
      });

      test('per-span sanitizer replaces global sanitizer', () {
        SanitizedSpanException globalSanitizer(
          Object error,
          StackTrace stackTrace,
        ) {
          return const SanitizedSpanException(
            type: 'Exception',
            message: 'global',
          );
        }

        SanitizedSpanException overrideSanitizer(
          Object error,
          StackTrace stackTrace,
        ) {
          return const SanitizedSpanException(
            type: 'Exception',
            message: 'override',
          );
        }

        final merged = SpanExceptionOptions(
          exceptionSanitizer: globalSanitizer,
        ).mergeWith(
          SpanExceptionOptions(exceptionSanitizer: overrideSanitizer),
        );

        expect(merged.exceptionSanitizer, same(overrideSanitizer));
      });

      test('all-defaults merge', () {
        final merged = const SpanExceptionOptions().mergeWith(
          const SpanExceptionOptions(),
        );

        expect(merged.recordException, isTrue);
        expect(merged.setStatusOnException, isTrue);
        expect(merged.exceptionSanitizer, isNull);
      });

      test('full override', () {
        SanitizedSpanException globalSanitizer(
          Object error,
          StackTrace stackTrace,
        ) {
          return const SanitizedSpanException(
            type: 'Exception',
            message: 'global',
          );
        }

        SanitizedSpanException overrideSanitizer(
          Object error,
          StackTrace stackTrace,
        ) {
          return const SanitizedSpanException(
            type: 'Exception',
            message: 'override',
          );
        }

        final merged = SpanExceptionOptions(
          recordException: false,
          setStatusOnException: false,
          exceptionSanitizer: globalSanitizer,
        ).mergeWith(
          SpanExceptionOptions(
            recordException: true,
            setStatusOnException: true,
            exceptionSanitizer: overrideSanitizer,
          ),
        );

        expect(merged.recordException, isTrue);
        expect(merged.setStatusOnException, isTrue);
        expect(merged.exceptionSanitizer, same(overrideSanitizer));
      });

      test('defaults static const has correct values', () {
        expect(SpanExceptionOptions.defaults.recordException, isTrue);
        expect(SpanExceptionOptions.defaults.setStatusOnException, isTrue);
        expect(SpanExceptionOptions.defaults.exceptionSanitizer, isNull);
      });
    });
  });
}
