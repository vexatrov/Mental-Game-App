import 'dart:ui' show PlatformDispatcher;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Formats dates in the device's language, falling back to US English when
/// the platform reports a locale intl has no data for (e.g. `en-US@posix`).
Future<void> configureDateLocale() async {
  await initializeDateFormatting();
  final device = PlatformDispatcher.instance.locale;
  final candidates = [
    if (device.countryCode case final country? when country.isNotEmpty)
      '${device.languageCode}_$country',
    device.languageCode,
  ];
  Intl.defaultLocale =
      candidates.firstWhere(DateFormat.localeExists, orElse: () => 'en_US');
}
