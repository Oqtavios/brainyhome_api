bool validateServerVersion(String? serverVersion) {
  if (serverVersion == null) return true;
  final split = serverVersion.split('.');
  if (split.length != 2) return false;
  if (int.tryParse(split.last) == null) return false;
  return true;
}


/// Adds server port to base URI if it wasn't specified during initialization
String addPortIfNotExists(String uri) {
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

    uri =
        '${uri.substring(0, loc)}:32768${loc < uri.length ? uri.substring(loc, uri.length) : ""}';
  }
  return uri;
}