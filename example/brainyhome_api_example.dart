import 'package:brainyhome_api/brainyhome_api.dart';

bool foregroundCheck() => true;

void main() async {
  var api = Api(
    // Server address
    uri: 'localhost:32768',
    // Automatically execute "connect()" method after API initialization
    autoconnect: false,
    // Toggle debug mode (currently enables verbose logs)
    debug: false,
    // Controls whether use http or https if uri doesn't contain the protocol
    autohttps: false,
    // Header authentication toggle
    headerAuth: true,
  );

  // Checks user authorization status and requests a new token if needed
  var connectResponse = await api.connect();
  if (connectResponse.success) {
    // Check if server needs additional authentication
    if (connectResponse.data['activationKey'] != null) {
      print(
          'Use this activation key on another device to activate API: ${connectResponse.data['activationKey']}');

      // Wait until user activates the token
      await api.tokenIsActivated(
        timeout: Duration(seconds: 30),
      );
    }

    // Start online status beacon. Passed function checks whether app is in foreground (allows to send beacon) or in background (no beacon)
    api.startBeacon(isForegroundCheck: foregroundCheck);

    var response = await api.call(
      // API method
      'light',
      // JSON data to be sent
      data: {'device': 2},
      // Controls sending user's token
      anonymous: false,
      // Binary data (file, etc) to upload
      binaryData: null,
      // Name by which cached response could be found
      cacheName: 'light_data_of_device_2',
      // Refreshes current cached data by making a new request
      refreshCache: true,
      // If set to false then unsuccessful responses won't be saved
      cacheErrors: false,
      // Adds '/api' to the server URI
      apiRoute: true,
      // Request timeout
      timeout: Duration(seconds: 10),
      // The time after which cache will be refreshed during new request
      cacheMaxAge: Duration(days: 1),
    );
    if (response.success) {
      print(response.data);
    } else {
      print('Unsuccessful request');
    }
  } else {
    print("Can't connect to API server");
  }
}
