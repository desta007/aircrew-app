import 'main.dart';

/// Entry point for the standalone Customer (Crew) app.
///   flutter run   -t lib/main_customer.dart --flavor customer
///   flutter build apk -t lib/main_customer.dart --flavor customer --release
void main() => bootstrap(AppFlavor.customer);
