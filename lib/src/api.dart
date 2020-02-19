import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'response.dart';
import 'cache_item.dart';

class Api {
  String _token;
  String _uri;
  bool debug = false;
  bool _headerAuth = true;

  Timer _beaconTimer;
  final Map<String, APICacheItem> _responseCache = {};

  Api(
      {@required String uri,
      String token = '',
      bool autoconnect = false,
      bool debug = false,
      bool autohttps = true,
      bool headerAuth = true,
      }) {
    if (this.debug) print('initializing API');
    if (!(uri.startsWith('http://') || uri.startsWith('https://'))) {
      if (autohttps) {
        uri = 'https://$uri';
      } else {
        uri = 'http://$uri';
      }
    }
    _uri = uri;
    if (this.debug) print(_uri);

    _token = token;
    this.debug = debug;
    _headerAuth = headerAuth;
    if (autoconnect) {
      connect();
    }
  }

  Future<Response> connect() async {
    if (_token == '') {
      return await call('tokenRequest');
    } else {
      var retval = await call('');
      if (retval.data != null &&
          retval.data.containsKey('authorized') &&
          !retval.data['authorized']) {
        var newTokenResponse = await call('tokenRequest');
        if (newTokenResponse.success &&
            newTokenResponse.data != null &&
            newTokenResponse.data.containsKey('token')) {
          _token = newTokenResponse.data['token'];
        }
        return newTokenResponse;
      } else {
        return Response.fail();
      }
    }
  }

  void _beacon() async {
    if (_token == '') {
      throw Exception('Empty token');
    }
    call('beacon');
  }

  void startBeacon({Function isForegroundCheck}) {
    _beacon();
    var duration = Duration(seconds: 20);
    _beaconTimer = Timer.periodic(duration, (Timer timer) {
      if (isForegroundCheck != null && isForegroundCheck() ||
          isForegroundCheck == null) _beacon();
    });
  }

  Future<bool> tokenIsActivated({Duration timeout = const Duration(minutes: 2)}) async {
    var status, response;
    var timeToStop = DateTime.now().add(timeout);
    do {
      try {
        response = await call('');
        status = response.data['authorized'];
        sleep(Duration(milliseconds: 250));
      } catch (_) {
        return false;
      }
    } while (!status || timeToStop.isAfter(DateTime.now()));
    return true;
  }

  String generateMethodUri(
      {String method,
      bool anonymous = false,
      bool encodeFull = false,
      bool apiRoute = true,
      Map query = const {},
      bool overriddenHeaderAuth,
      }) {
    var slash = '/';
    if (method == '') {
      slash = '';
    }

    var slashApi = '/api';

    if (!apiRoute) slashApi = '';

    String uri;
    if (anonymous || (overriddenHeaderAuth ?? _headerAuth)) {
      uri = '$_uri$slashApi$slash$method';
    } else {
      uri = '$_uri$slashApi$slash$method?token=$_token';
    }

    if (query.isNotEmpty) {
      query.forEach((key, value) {
        if (!uri.contains('?')) {
          uri = '$uri?$key=$value';
        } else {
          uri = '$uri&$key=$value';
        }
      });
    }

    if (encodeFull) return Uri.encodeFull(uri);

    return uri;
  }

  Future<Response> call(
    String method, {
    Map data = const {},
    bool anonymous = false,
    dynamic binaryData,
    String cacheName,
    bool refreshCache = false,
    bool cacheErrors = false,
    bool apiRoute = true,
    Duration timeout = const Duration(seconds: 30),
    Duration cacheMaxAge = const Duration(days: 30),
  }) async {
    if (cacheName != null) {
      if (_responseCache.containsKey(cacheName) &&
          _responseCache[cacheName] != null &&
          !refreshCache &&
          DateTime.now().isBefore(_responseCache[cacheName].expireTime)) {
        if (debug) print('cached');
        return Response.fromResponse(_responseCache[cacheName].response,
            cached: true);
      }
    }

    if (debug) {
      print(
          'Calling anonymous: $anonymous method: $method with data:\n${data.toString()}');
    }

    var uri = generateMethodUri(
      method: method,
      anonymous: anonymous,
      apiRoute: apiRoute,
    );

    try {
      final response = await http
          .post(Uri.encodeFull(uri),
              headers: _headerAuth ? {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': _token,
              } : {
                'Content-Type': 'application/json; charset=utf-8',
              },
              body: binaryData ?? json.encode(data))
          .timeout(timeout);

      if (response.statusCode < 400) {
        if (response.headers['content-type'] == 'application/x-download') {
          var resp =
              Response(success: true, data: response.bodyBytes, isBinary: true);
          if (cacheName != null) {
            _responseCache[cacheName] = APICacheItem(
                response: resp, expireTime: DateTime.now().add(cacheMaxAge));
          }
          return resp;
        }

        var responseData = json.decode(response.body);
        var resp = Response.fromJson(responseData);
        if (cacheName != null) {
          _responseCache[cacheName] = APICacheItem(
              response: resp, expireTime: DateTime.now().add(cacheMaxAge));
        }
        return resp;
      } else {
        var resp = Response.fail('statusCode_${response.statusCode}');
        if (cacheName != null) {
          _responseCache[cacheName] = APICacheItem(
              response: resp, expireTime: DateTime.now().add(cacheMaxAge));
        }
        return resp;
      }
    } catch (Exception) {
      if (debug) print(Exception.toString());
      var resp = Response.fail();
      if (cacheErrors) {
        if (cacheName != null) {
          _responseCache[cacheName] = APICacheItem(
              response: resp, expireTime: DateTime.now().add(cacheMaxAge));
        }
      }
      return resp;
    }
  }

  void dispose() {
    if (_beaconTimer != null) _beaconTimer.cancel();
  }
}
