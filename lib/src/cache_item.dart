import 'response.dart';

class APICacheItem {
  final DateTime expireTime;
  final Response response;

  APICacheItem({required this.response, required this.expireTime});
}