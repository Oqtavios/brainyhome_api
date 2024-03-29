import 'package:brainyhome_api/brainyhome_api.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    Api? api;

    setUp(() {
      api = Api(uri: 'localhost:32768', autohttps: true, autoconnect: false, debug: true);
    });

    test('generateMethodUri test', () {
      expect(api!.generateMethodUri(method: 'users', overriddenHeaderAuth: false) == 'https://localhost:32768/api/users?token=', isTrue);
    });
  });
}
