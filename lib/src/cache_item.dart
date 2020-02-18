import 'response.dart';

class APICacheItem {
  final DateTime expireTime;
  final Response response;

  APICacheItem({this.response, this.expireTime});
}