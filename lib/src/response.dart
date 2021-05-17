class Response {
  final bool success;
  final dynamic? data;
  final dynamic? error;
  final bool isBinary;
  final bool cached;

  Response({required this.success,
    this.data,
    this.error = false,
    this.isBinary = false,
    this.cached = false});

  factory Response.fail([String error = 'networkError']) {
    return Response(success: false, data: null, error: error, isBinary: false);
  }

  factory Response.fromJson(Map<String, dynamic> json, {bool cached = false}) {
    bool success;
    dynamic error;
    // ignore: prefer_if_null_operators
    success = json['success'] != null
        ? json['success']
        : json['error'] == null ? true : false;
    if (json.containsKey('error')) {
      error = json['error'];
    } else {
      error = null;
    }
    return Response(
      success: success,
      data: json,
      error: error,
      isBinary: false,
      cached: cached,
    );
  }

  factory Response.fromResponse(Response response, {bool? cached}) {
    return Response(
      success: response.success,
      data: response.data,
      error: response.error,
      isBinary: response.isBinary,
      cached: cached ?? response.cached,
    );
  }
}