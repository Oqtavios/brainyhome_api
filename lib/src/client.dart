import 'package:http/http.dart' as http;

const packageVersion = '0.12.12';  // TODO: Update version on new release

class BrainyHomeApiClient extends http.BaseClient {
  final String? appName;
  final String? appVersion;
  late final String userAgent;
  final http.Client _realClient = http.Client();

  BrainyHomeApiClient({this.appName, this.appVersion}) {
    var baseUserAgent = '';
    if (appName != null) baseUserAgent = '$appName/${appVersion ?? "any"} ';
    userAgent = '${baseUserAgent}BrainyHomeApi/$packageVersion';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = userAgent;
    return _realClient.send(request);
  }
}