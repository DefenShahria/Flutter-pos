final class Urls {
  Urls._();

  static const String baseUrl = 'http://108.136.142.112:90';

  static String get token => '$baseUrl/token';
  static String get files => '$baseUrl/get';
  static String get upload => '$baseUrl/upload';

  static String download(String fileName) {
    final uri = Uri.parse(files);
    return uri.replace(queryParameters: {'file': fileName}).toString();
  }

  static String delete(String fileName) {
    final uri = Uri.parse('$baseUrl/delete');
    return uri.replace(queryParameters: {'file': fileName}).toString();
  }
}
