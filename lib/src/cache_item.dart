import 'response.dart';

class APICacheItem {
  final DateTime expireTime;
  final Response response;
  bool inProgress;

  APICacheItem({required this.response, required this.expireTime, this.inProgress = false});
}