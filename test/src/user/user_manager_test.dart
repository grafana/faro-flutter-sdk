import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/user/user_manager.dart';
import 'package:faro/src/user/user_persistence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserPersistence extends Mock implements UserPersistence {}

void main() {
  group('UserManager:', () {
    late MockUserPersistence mockPersistence;
    late Map<String, dynamic>? appliedUserJson;
    late List<String> pushedEvents;
    late UserManager userManager;

    setUpAll(() {
      registerFallbackValue(const FaroUser(id: 'fallback'));
    });

    setUp(() {
      mockPersistence = MockUserPersistence();
      appliedUserJson = null;
      pushedEvents = [];

      when(() => mockPersistence.loadUser()).thenReturn(null);
      when(() => mockPersistence.saveUser(any())).thenAnswer((_) async {});
      when(() => mockPersistence.clearUser()).thenAnswer((_) async {});

      userManager = UserManager(
        persistence: mockPersistence,
        onUserMetaApplied: (userJson) => appliedUserJson = userJson,
        onPushEvent: (event) => pushedEvents.add(event),
      );
    });

    group('setUser:', () {
      test('applies user and persists when persistUser is true', () async {
        const user = FaroUser(
          id: 'test-user',
          username: 'testuser',
          email: 'test@example.com',
        );

        await userManager.setUser(user, persistUser: true);

        expect(appliedUserJson, {
          'id': 'test-user',
          'username': 'testuser',
          'email': 'test@example.com',
        });
        verify(() => mockPersistence.saveUser(user)).called(1);
        verifyNever(() => mockPersistence.clearUser());
      });

      test('applies user and clears stale data when persistUser is false',
          () async {
        const user = FaroUser(id: 'test-user');

        await userManager.setUser(user, persistUser: false);

        expect(appliedUserJson?['id'], 'test-user');
        verify(() => mockPersistence.clearUser()).called(1);
        verifyNever(() => mockPersistence.saveUser(any()));
      });

      test('clears user when FaroUser.cleared() is passed', () async {
        // First set a user
        await userManager.setUser(
          const FaroUser(id: 'existing'),
          persistUser: true,
        );
        reset(mockPersistence);
        when(() => mockPersistence.clearUser()).thenAnswer((_) async {});

        await userManager.setUser(const FaroUser.cleared(), persistUser: true);

        // FaroUser.cleared() still calls callback with null fields
        expect(appliedUserJson, {'id': null, 'username': null, 'email': null});
        verify(() => mockPersistence.clearUser()).called(1);
      });

      test('emits faro_internal_user_updated event', () async {
        const user = FaroUser(id: 'test-user');

        await userManager.setUser(user, persistUser: true);

        expect(pushedEvents, contains('faro_internal_user_updated'));
      });

      test('emits event even when clearing user', () async {
        // First set a user
        await userManager.setUser(
          const FaroUser(id: 'existing'),
          persistUser: true,
        );
        pushedEvents.clear();

        await userManager.setUser(const FaroUser.cleared(), persistUser: true);

        expect(pushedEvents, contains('faro_internal_user_updated'));
      });

      test('skips update when same user is set again', () async {
        const user = FaroUser(id: 'test-user', username: 'test');

        await userManager.setUser(user, persistUser: true);
        pushedEvents.clear();
        reset(mockPersistence);

        // Set same user again
        await userManager.setUser(user, persistUser: true);

        expect(pushedEvents, isEmpty);
        verifyNever(() => mockPersistence.saveUser(any()));
      });

      test('skips update when cleared is set twice', () async {
        // _currentUser starts as null, so setting cleared should skip
        await userManager.setUser(const FaroUser.cleared(), persistUser: true);

        expect(pushedEvents, isEmpty);
        verifyNever(() => mockPersistence.clearUser());
      });

      test('updates currentUser property', () async {
        const user = FaroUser(id: 'test-user');

        expect(userManager.currentUser, isNull);

        await userManager.setUser(user, persistUser: true);

        expect(userManager.currentUser, user);

        await userManager.setUser(const FaroUser.cleared(), persistUser: true);

        expect(userManager.currentUser, isNull);
      });
    });

    group('initialize:', () {
      group('with persistUser enabled:', () {
        test('restores persisted user when no initialUser', () async {
          const persistedUser = FaroUser(
            id: 'persisted-user',
            username: 'persisted',
            email: 'persisted@example.com',
          );
          when(() => mockPersistence.loadUser()).thenReturn(persistedUser);

          await userManager.initialize(persistUser: true);

          expect(appliedUserJson, {
            'id': 'persisted-user',
            'username': 'persisted',
            'email': 'persisted@example.com',
          });
          verify(() => mockPersistence.loadUser()).called(1);
        });

        test('uses initialUser over persisted user', () async {
          const persistedUser = FaroUser(id: 'persisted-user');
          const initialUser = FaroUser(id: 'initial-user', username: 'initial');
          when(() => mockPersistence.loadUser()).thenReturn(persistedUser);

          await userManager.initialize(
            initialUser: initialUser,
            persistUser: true,
          );

          expect(appliedUserJson?['id'], 'initial-user');
          expect(appliedUserJson?['username'], 'initial');
          verify(() => mockPersistence.saveUser(initialUser)).called(1);
          verifyNever(() => mockPersistence.loadUser());
        });

        test('clears persisted user when initialUser.cleared() is used',
            () async {
          const persistedUser = FaroUser(id: 'persisted-user');
          when(() => mockPersistence.loadUser()).thenReturn(persistedUser);

          await userManager.initialize(
            initialUser: const FaroUser.cleared(),
            persistUser: true,
          );

          // No user applied when cleared
          expect(appliedUserJson, isNull);
          verify(() => mockPersistence.clearUser()).called(1);
        });

        test('has no user when no persisted and no initialUser', () async {
          when(() => mockPersistence.loadUser()).thenReturn(null);

          await userManager.initialize(persistUser: true);

          // No user to apply
          expect(appliedUserJson, isNull);
        });

        test('sets currentUser during initialization', () async {
          const persistedUser = FaroUser(id: 'persisted-user');
          when(() => mockPersistence.loadUser()).thenReturn(persistedUser);

          await userManager.initialize(persistUser: true);

          expect(userManager.currentUser, persistedUser);
        });

        test('sets currentUser from initialUser', () async {
          const initialUser = FaroUser(id: 'initial-user');

          await userManager.initialize(
            initialUser: initialUser,
            persistUser: true,
          );

          expect(userManager.currentUser, initialUser);
        });
      });

      group('with persistUser disabled:', () {
        test('does not load persisted user', () async {
          await userManager.initialize(persistUser: false);

          verifyNever(() => mockPersistence.loadUser());
        });

        test('still uses initialUser when provided', () async {
          const initialUser = FaroUser(id: 'initial-user');

          await userManager.initialize(
            initialUser: initialUser,
            persistUser: false,
          );

          expect(appliedUserJson?['id'], 'initial-user');
          verifyNever(() => mockPersistence.saveUser(any()));
        });

        test('clears stale persisted data', () async {
          await userManager.initialize(persistUser: false);

          verify(() => mockPersistence.clearUser()).called(1);
        });

        test('clears stale data even when initialUser is provided', () async {
          const initialUser = FaroUser(id: 'initial-user');

          await userManager.initialize(
            initialUser: initialUser,
            persistUser: false,
          );

          verify(() => mockPersistence.clearUser()).called(1);
          expect(appliedUserJson?['id'], 'initial-user');
        });
      });
    });

    group('without persistence:', () {
      setUp(() {
        userManager = UserManager(
          persistence: null,
          onUserMetaApplied: (userJson) => appliedUserJson = userJson,
          onPushEvent: (event) => pushedEvents.add(event),
        );
      });

      test('setUser works without persistence', () async {
        const user = FaroUser(id: 'test-user');

        await userManager.setUser(user, persistUser: true);

        expect(appliedUserJson?['id'], 'test-user');
        expect(pushedEvents, contains('faro_internal_user_updated'));
      });

      test('initialize works without persistence', () async {
        const initialUser = FaroUser(id: 'initial-user');

        await userManager.initialize(
          initialUser: initialUser,
          persistUser: true,
        );

        expect(appliedUserJson?['id'], 'initial-user');
      });
    });
  });
}
