import 'package:drift/drift.dart';

LazyDatabase openConnection() {
  // For web, database is not fully supported
  // Since this app is primarily for mobile/desktop (B2B distribution),
  // web support is mainly for development/testing
  // In a production web app, you'd use IndexedDB via drift's web support
  // For now, we'll throw an error to prevent compilation issues
  // The app should primarily run on mobile/desktop where SQLite works
  throw UnsupportedError(
    'Database is not fully supported on web. '
    'This app is designed for mobile/desktop platforms. '
    'Please run on iOS, Android, macOS, Windows, or Linux.',
  );
}
