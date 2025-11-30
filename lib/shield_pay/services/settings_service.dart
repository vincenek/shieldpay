// Conditional export: use web-backed implementation when available, otherwise use the IO fallback.
export 'settings_service_io.dart'
  if (dart.library.html) 'settings_service_web.dart';
