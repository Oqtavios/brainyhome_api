# Brainy Home API
Connector module for the Brainy Home API written in Dart.
You can use this package in your Flutter/Dart app for making requests to your smart home server.

## Usage

A simple usage example:

```dart
import 'package:brainyhome_api/brainyhome_api.dart';

main() async {
  var api = Api(uri: "path_to_your_server:PORT");

  var response = await api.call("aboutme");
  if (response.success) {
    print(response.data);
  } else {
    print("Unsuccessful request");
  }
}
```

## Getting started
More usage samples you can find in the `example` directory.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Oqtavios/brainyhome_api/issues/new
