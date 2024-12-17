import 'package:uuid/uuid.dart';

class UuidProvider {
  UuidProvider({required Uuid uuid}) : _uuid = uuid;

  final Uuid _uuid;

  String getUuidV4() {
    return _uuid.v4();
  }
}

class UuidProviderFactory {
  static UuidProvider create() {
    return UuidProvider(uuid: const Uuid());
  }
}
