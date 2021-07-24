import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'response.dart';
import 'cache_item.dart';

class Api {
  String? _token;
  late String _uri;
  String? _remoteUri;
  bool debug = false;
  bool _headerAuth = true;
  bool _forceRemote = false;
  bool _forceLocal = false;
  Future<bool> Function()? _remoteChecker;
  bool _remote = false;
  bool forceHttps = false;
  //void Function()? poorConnectionCallback;

  Timer? _beaconTimer;
  final Map<String, APICacheItem> _responseCache = {};
  bool _ready = false;
  late DateTime _nextReconnectAllowedTime;

  Api(
      {required String uri,
      String token = '',
      bool autoconnect = false,
      this.debug = false,
      bool autohttps = true,
      bool headerAuth = true,
      String? remoteUri,
      bool forceRemote = false,
      bool forceLocal = false,
      bool forceHttps = false,
      Future<bool> Function()? remoteChecker,
      //this.poorConnectionCallback,
      }) {
    if (debug) print('initializing API');
    if (!(uri.startsWith('http://') || uri.startsWith('https://'))) {
      if (autohttps) {
        uri = 'https://$uri';
      } else {
        uri = 'http://$uri';
      }

      if (forceHttps) {
        if (uri.startsWith('https://')) {
          _uri = uri;
        }
      } else {
        _uri = uri;
      }
    }
    _uri = _addPortIfNotExists(_uri);

    // Remote only supports https
    if (remoteUri != null) {
      if (!(remoteUri.startsWith('https')) && !remoteUri.startsWith('http:')) {
        remoteUri = 'https://$remoteUri';
      }
      if (remoteUri.startsWith('https')) {
        _remoteUri = remoteUri;
      }
      _remoteUri = _addPortIfNotExists(_remoteUri!);
    }

    _forceRemote = forceRemote;
    _forceLocal = forceLocal;

    if (_forceLocal && _forceRemote) {
      throw(Exception("Can't enforce both local and remote APIs"));
    }

    if (debug) print(_uri);

    _token = token;
    _remoteChecker = remoteChecker;
    _headerAuth = headerAuth;
    _nextReconnectAllowedTime = DateTime.now();
    
    if (autoconnect) {
      Future.sync(connect);
    }
  }

  /// Determines connection method (local/remote) by checking connection status and server availability.
  /// Could be called multiple times after initialization to reestablish connection
  void connect({bool forceLocal = false, bool forceRemote = false, bool resetEnforcements = false}) async {
    if (resetEnforcements) {
      _forceLocal = false;
      _forceRemote = false;
    }

    if (forceLocal) {
      _forceRemote = false;
      _forceLocal = true;
    } else if (forceRemote) {
      _forceLocal = false;
      _forceRemote = true;
    }

    _remote = false;
    _ready = false;

    if (_forceLocal || _remoteUri == null) {
      _remote = false;

    } else if (_forceRemote) {
      _remote = true;

    } else if (_remoteChecker != null && await _remoteChecker!()) {
      // Remote checker determined that we should use remote
      _remote = true;

    } else {
      // Checker not provided, using built-in determination methods
      var retval = await call('', anonymous: true, apiRoute: false, localTimeout: Duration(seconds: 5));

      if (retval.success) {
        // Connected to local
        _remote = false;

      } else {
        // Turning remote on for a bit to check connection
        _remote = true;
        retval = await call('', anonymous: true, apiRoute: false, remoteTimeout: Duration(seconds: 15));
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

  /// Specifies whether API is connected using remote address
  bool get usingRemote => _remote;

  /// Specifies whether API module is fully initialized and ready to make requests
  bool get ready => _ready;

  /// Method used for getting a new token
  /// (i.e, first run of an app)
  Future<Response> firstConnect() async {
    if (_token == '') {
       var response = await call('tokenRequest');

       if (response.success && response.data.containsKey('token')) {
         _token = response.data['token'];
       }
       return response;
    } else {
      return Response.fail();
    }
  }

  void _beacon() async {
    if (_token == '') {
      throw Exception('Empty token');
    }
    call('beacon');
  }

  /// Starts periodically (every 20 seconds) sending online beacon to the server
  void startBeacon({Function? isForegroundCheck}) {
    _beacon();
    var duration = Duration(seconds: 20);
    _beaconTimer = Timer.periodic(duration, (Timer timer) {
      if (isForegroundCheck != null && isForegroundCheck() ||
          isForegroundCheck == null) _beacon();
    });
  }

  /// Continuously (respecting the given timeout) check whether is current token is activated.
  /// Used for waiting for token activation.
  Future<bool> tokenIsActivated({Duration timeout = const Duration(minutes: 2)}) async {
    var status, response;
    var timeToStop = DateTime.now().add(timeout);
    do {
      try {
        response = await call('');
        status = response.data['authorized'];
        await Future.delayed(Duration(milliseconds: 250));
      } catch (_) {
        return false;
      }
    } while (!status || timeToStop.isAfter(DateTime.now()));
    return true;
  }

  /// Generate complete request URI used in API calls
  String generateMethodUri(
      {required String method,
      bool anonymous = false,
      bool encodeFull = false,
      bool apiRoute = true,
      Map query = const {},
      bool? overriddenHeaderAuth,
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

  /// API call
  Future<Response> call(
    String method, {
    Map data = const {},
    bool anonymous = false,
    dynamic binaryData,
    String? cacheName,
    bool refreshCache = false,
    bool cacheErrors = false,
    bool apiRoute = true,
    Duration localTimeout = const Duration(seconds: 20),
    Duration remoteTimeout = const Duration(seconds: 30),
    Duration cacheMaxAge = const Duration(days: 7),
    String contentType = 'application/json; charset=utf-8',
  }) async {
    if (cacheName != null) {
      if (_responseCache.containsKey(cacheName) && _responseCache[cacheName] != null && !refreshCache && DateTime.now().isBefore(_responseCache[cacheName]!.expireTime)) {
        var inProgressCounter = 0;
        while (_responseCache[cacheName]!.inProgress) {
          if (debug) print('cached (in progress): $cacheName');
          if (inProgressCounter > 150) {
            // skip waiting and make a new request
            break;
          }
          await Future.delayed(Duration(milliseconds: 100));
        }
        if (inProgressCounter <= 150) {
          if (debug) print('cached (ready): $cacheName');
          return Response.fromResponse(_responseCache[cacheName]!.response,
              cached: true);
        } else {
          if (debug) print('cache in progress wait exceeded, making a new request: $cacheName');
        }
      } else {
        if (debug) print('item not in cache, adding inProgress placeholder: $cacheName');
        _responseCache[cacheName] = APICacheItem(
            inProgress: true, response: Response(success: false), expireTime: DateTime.now().add(cacheMaxAge + (usingRemote ? remoteTimeout : localTimeout)));
      }
    }

    var notReadyCounter = 0;
    while (!anonymous && !_ready) {
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
          .post(Uri.parse(Uri.encodeFull(uri)),
              headers: _headerAuth ? {
                'Content-Type': binaryData != null ? contentType : 'application/json; charset=utf-8',
                'Authorization': _token ?? '',
              } : {
                'Content-Type': binaryData != null ? contentType : 'application/json; charset=utf-8',
              },
              body: binaryData ?? json.encode(data))
          .timeout(usingRemote ? remoteTimeout : localTimeout);

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
        if (cacheErrors) {
          if (cacheName != null) {
            _responseCache[cacheName] = APICacheItem(
                response: resp, expireTime: DateTime.now().add(cacheMaxAge));
          }
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

  /// Adds currently non-existent items to cache (will not overwrite already existing data)
  bool appendCache ({
    required String cacheName,
    required Response response,
    Duration cacheMaxAge = const Duration(days: 7),
  }) {
    if (_responseCache.containsKey(cacheName)) {
      return false;
    }

    _responseCache[cacheName] = APICacheItem(
      response: response,
      expireTime: DateTime.now().add(cacheMaxAge),
    );
    return true;
  }

  /// Adds server port to base URI if it wasn't specified during initialization
  String _addPortIfNotExists(String uri) {
    if (!uri.contains(':') || uri.contains(':') && uri.lastIndexOf(':') < 6) {
      var loc = uri.indexOf(':');
      if (loc == -1) {
        loc = 0;
      } else {
        loc += 3;
      }
      loc = uri.indexOf('/', loc);
      if (loc == -1) {
        loc = uri.length;
      }
      
      uri = '${uri.substring(0, loc)}:32768${loc < uri.length ? uri.substring(loc, uri.length) : ""}';
    }
    return uri;
  }

  void dispose() {
    if (_beaconTimer != null && _beaconTimer!.isActive) _beaconTimer!.cancel();
  }

  void clearCache() => _responseCache.clear();
}
