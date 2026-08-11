import 'main.dart';

/// Entry point for the standalone Driver (Mitra) app.
///   flutter run   -t lib/main_driver.dart --flavor driver
///   flutter build apk -t lib/main_driver.dart --flavor driver --release
void main() => bootstrap(AppFlavor.driver);
