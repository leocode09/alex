/// Central config for the "Share App" / download-QR feature.
///
/// Change [downloadUrl] to the public URL where users can grab the app
/// (landing page, Play Store listing, direct APK link, etc.). The same
/// URL is encoded in the in-app QR screen and in the web landing banner.
class AppShareConfig {
  AppShareConfig._();

  /// Public URL the QR code points at. Update once hosting is live.
  static const String downloadUrl = 'https://alex-pos.web.app';

  /// Friendly copy shown above the QR code.
  static const String appName = 'ALEX POS';

  /// Message used by the native share sheet.
  static const String shareMessage =
      'Get $appName — scan or open: $downloadUrl';
}
