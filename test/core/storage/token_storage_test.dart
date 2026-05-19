import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/core/storage/token_storage.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

void main() {
  late TokenStorage tokenStorage;
  late FakeSecureStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    tokenStorage = TokenStorage(storage: fakeStorage);
  });

  group('TokenStorage', () {
    test('save 후 getAccessToken이 저장된 값을 반환한다', () async {
      await tokenStorage.save(accessToken: 'acc', refreshToken: 'ref');
      expect(await tokenStorage.getAccessToken(), 'acc');
    });

    test('save 후 getRefreshToken이 저장된 값을 반환한다', () async {
      await tokenStorage.save(accessToken: 'acc', refreshToken: 'ref');
      expect(await tokenStorage.getRefreshToken(), 'ref');
    });

    test('save 후 hasToken이 true를 반환한다', () async {
      await tokenStorage.save(accessToken: 'acc', refreshToken: 'ref');
      expect(await tokenStorage.hasToken(), isTrue);
    });

    test('clear 후 hasToken이 false를 반환한다', () async {
      await tokenStorage.save(accessToken: 'acc', refreshToken: 'ref');
      await tokenStorage.clear();
      expect(await tokenStorage.hasToken(), isFalse);
    });

    test('초기 상태에서 hasToken이 false를 반환한다', () async {
      expect(await tokenStorage.hasToken(), isFalse);
    });
  });
}
