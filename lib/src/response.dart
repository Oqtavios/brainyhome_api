class Response {
  final bool success;
  final dynamic data;
  final dynamic error;
  final bool isBinary;
  final bool cached;
  //final bool? sameAsCached;
  final int dataHashCode;
  final String? binaryFileName;
  final String? serverVersion;

  Response({required this.success,
    this.data,
    this.error = false,
    this.isBinary = false,
    this.cached = false,
    //this.sameAsCached,
    int? dataHashCode,
    this.binaryFileName,
    this.serverVersion,
  }) : dataHashCode = dataHashCode ?? data.toString().hashCode;

  factory Response.fail([String error = 'networkError']) {
    return Response(success: false, data: null, error: error, isBinary: false);
  }

  factory Response.fromJson(Map<String, dynamic> json, {bool cached = false/*, bool? sameAsCached*/}) {
    final success = json['success'] ?? (json['error'] == null ? true : false);
    final error = json['error'];
    
    return Response(
      success: success,
      data: json,
      error: error,
      isBinary: false,
      cached: cached,
      //sameAsCached: sameAsCached,
    );
  }

  factory Response.fromResponse(Response response, {bool? cached}) {
    return Response(
      success: response.success,
      data: response.data,
      error: response.error,
      isBinary: response.isBinary,
      cached: cached ?? response.cached,
      dataHashCode: response.dataHashCode,
      binaryFileName: response.binaryFileName,
      serverVersion: response.serverVersion,
    );
  }
}