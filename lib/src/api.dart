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
  String _remoteUri;
  bool debug = false;
  bool _headerAuth = true;
  bool _forceRemote = false;
  bool _forceLocal = false;
  Future<bool> Function() _remoteChecker;
  bool _remote = false;

  Timer _beaconTimer;
  final Map<String, APICacheItem> _responseCache = {};
  bool _ready = false;
  DateTime _nextReconnectAllowedTime;

  Api(
      {@required String uri,
      String token = '',
      bool autoconnect = false,
      this.debug = false,
      bool autohttps = true,
      bool headerAuth = true,
      String remoteUri = '',
      bool forceRemote = false,
      bool forceLocal = false,
      Future<bool> Function() remoteChecker,
      }) {
    if (debug) print('initializing API');
    if (!(uri.startsWith('http://') || uri.startsWith('https://'))) {
      if (autohttps) {
        uri = 'https://$uri';
      } else {
        uri = 'http://$uri';
      }
    }

    // Remote only supports https
    if (_remoteUri != null) {
      if (!(remoteUri.startsWith('https')) && !remoteUri.startsWith('http:')) {
        remoteUri = 'https://$remoteUri';
      }
      if (remoteUri.startsWith('https')) {
        _remoteUri = remoteUri;
      }
    }

    _forceRemote = forceRemote;
    _forceLocal = forceLocal;

    _uri = uri;
    if (debug) print(_uri);

    _token = token;
    _remoteChecker = remoteChecker;
    _headerAuth = headerAuth;
    _nextReconnectAllowedTime = DateTime.now();
    
    if (autoconnect) {
      Future.sync(connect);
    }
  }

  void connect() async {
    _remote = false;
    _ready = false;

    if (_forceLocal) {
      _remote = false;

    } else if (_forceRemote) {
      _remote = true;

    } else if (_remoteChecker != null && await _remoteChecker()) {
      // Remote checker determined that we should use remote
      _remote = true;

    } else {
      // Checker not provided, using built-in determination methods
      var retval = await call('', anonymous: true, apiRoute: false, timeout: Duration(seconds: 5));

      if (retval.success) {
        // Connected to local
        _remote = false;

      } else {
        // Turning remote on for a bit to check connection
        _remote = true;
        retval = await call('', anonymous: true, apiRoute: false, timeout: Duration(seconds: 15));
        _remote = false;

        if (retval.success) {
          // Connected to remote
          _remote = true;

        } else {
          // Bad connection
          // Can't connect to remote, switching to local
          _remote = false;
        }
      }
    }

    // Connection type is determined, API is ready
    _ready = true;
    _nextReconnectAllowedTime = DateTime.now().add(Duration(seconds: 20));
  }

  bool get usingRemote => _remote;

  bool get ready => _ready;

  Future<Response> firstConnect() async {
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
    
    var serverUri = _remote ? _remoteUri : _uri;

    String uri;
    if (anonymous || (overriddenHeaderAuth ?? _headerAuth)) {
      uri = '$serverUri$slashApi$slash$method';
    } else {
      uri = '$serverUri$slashApi$slash$method?token=$_token';
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
    Duration cacheMaxAge = const Duration(days: 7),
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

    var notReadyCounter = 0;
    while (!anonymous && !_ready) {
      // ADD FEATURE TO WAIT FOR SOME TIME AND THROW AFTER IF NOT READY
      if (notReadyCounter > 150) {
        throw TimeoutException('API was not ready for a long time');
      }
      await Future.delayed(Duration(milliseconds: 200));
      notReadyCounter++;
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
    } catch (exception) {
      if (debug) print(exception.toString());
      var resp = Response.fail();
      if (cacheErrors) {
        if (cacheName != null) {
          _responseCache[cacheName] = APICacheItem(
              response: resp, expireTime: DateTime.now().add(cacheMaxAge));
        }
      }

      if (exception is TimeoutException && _ready && DateTime.now().isAfter(_nextReconnectAllowedTime)) {
        if (debug) {
          print('Connection timed out, trying to reconnect');
        }
        connect();
      }
      return resp;
    }
  }

  void dispose() {
    if (_beaconTimer != null && _beaconTimer.isActive) _beaconTimer.cancel();
  }
}
