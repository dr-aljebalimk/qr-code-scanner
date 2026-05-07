import 'package:url_launcher/url_launcher.dart';

class UrlService {
  static bool isValidUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
