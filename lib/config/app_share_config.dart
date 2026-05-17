/// Central config for the "Share App" / download-QR feature.
///
/// Change [downloadUrl] to the public landing page where users can grab
/// the app. The same URL is encoded in the in-app QR screen and in the
/// web landing banner.
class AppShareConfig {
  AppShareConfig._();

  /// Public URL the QR code points at.
  static const String downloadUrl = 'https://alex-pos.web.app/download/';

  /// Friendly copy shown above the QR code.
  static const String appName = 'ALEX POS';

  /// Message used by the native share sheet.
  static const String shareMessage =
      'Get $appName — scan or open: $downloadUrl';
}
