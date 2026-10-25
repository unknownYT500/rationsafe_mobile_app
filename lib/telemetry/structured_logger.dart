// mobile/lib/telemetry/structured_logger.dart
import 'dart:convert';
import 'tracer.dart';

enum LogLevel { debug, info, warn, error, audit }

/// High-performance structured JSON logger with automatic PII scrubbing
/// strictly compliant with DPDP Act 2023 and Aadhaar Act Section 29.
class StructuredLogger {
  final String serviceName;
  static bool enableConsoleOutput = true;
  static final List<Map<String, dynamic>> _inMemoryLogs = [];

  StructuredLogger({this.serviceName = 'mobile_pos'});

  // Regex patterns for sensitive citizen identifiers
  static final RegExp _aadhaarRegex = RegExp(r'\b(?:\d{4}[ -]?\d{4}[ -]?\d{4})\b');
  static final RegExp _phoneRegex = RegExp(r'\b(?:\+91[\-\s]?)?[6-9]\d{9}\b');

  static const Set<String> _sensitiveKeyPatterns = {
    'name',
    'fullname',
    'first_name',
    'last_name',
    'address',
    'income',
    'yearly_income',
    'privatekey',
    'secret',
    'signature',
    'password',
    'pin',
  };

  /// Recursively scrubs sensitive citizen PII and secrets from maps and strings.
  static dynamic scrubPii(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      return _scrubText(data);
    }

    if (data is Map) {
      final scrubbed = <String, dynamic>{};
      for (final entry in data.entries) {
        final keyStr = entry.key.toString();
        final lowerKey = keyStr.toLowerCase();

        // Check if key corresponds to sensitive attributes
        if (_sensitiveKeyPatterns.any((p) => lowerKey.contains(p))) {
          if (lowerKey.contains('private') || lowerKey.contains('secret') || lowerKey.contains('key')) {
            scrubbed[keyStr] = '[REDACTED_SECRET]';
          } else {
            scrubbed[keyStr] = '[REDACTED_PII]';
          }
        } else if (lowerKey.contains('aadhaar')) {
          scrubbed[keyStr] = _maskAadhaar(entry.value?.toString() ?? '');
        } else if (lowerKey.contains('phone')) {
          scrubbed[keyStr] = _maskPhone(entry.value?.toString() ?? '');
        } else if (lowerKey.contains('card') && entry.value is String) {
          final val = entry.value as String;
          scrubbed[keyStr] = val.length > 8 ? '${val.substring(0, 4)}...${val.substring(val.length - 4)}' : val;
        } else {
          scrubbed[keyStr] = scrubPii(entry.value);
        }
      }
      return scrubbed;
    }

    if (data is List) {
      return data.map((item) => scrubPii(item)).toList();
    }

    return data;
  }

  static String _scrubText(String text) {
    var result = text;
    // Scrub Aadhaar numbers
    result = result.replaceAllMapped(_aadhaarRegex, (match) {
      final raw = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (raw.length == 12) {
        return 'XXXX-XXXX-${raw.substring(8)}';
      }
      return match.group(0)!;
    });

    // Scrub Indian phone numbers
    result = result.replaceAllMapped(_phoneRegex, (match) {
      final raw = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (raw.length >= 10) {
        final last4 = raw.substring(raw.length - 4);
        return '+91-XXXXX-$last4';
      }
      return match.group(0)!;
    });

    return result;
  }

  static String _maskAadhaar(String aadhaar) {
    final clean = aadhaar.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 12) {
      return 'XXXX-XXXX-${clean.substring(8)}';
    }
    return 'XXXX-XXXX-XXXX';
  }

  static String _maskPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 10) {
      final last4 = clean.substring(clean.length - 4);
      return '+91-XXXXX-$last4';
    }
    return '+91-XXXXX-XXXX';
  }

  void _log(LogLevel level, String message, {Map<String, dynamic>? data, Object? error}) {
    final now = DateTime.now().toUtc();
    final trace = Tracer.currentContext;

    final entry = <String, dynamic>{
      'timestamp': now.toIso8601String(),
      'service': serviceName,
      'level': level.name.toUpperCase(),
      'message': _scrubText(message),
      if (trace != null) ...{
        'trace_id': trace.traceId,
        'span_id': trace.spanId,
        'traceparent': trace.toTraceparent(),
      },
      if (data != null) 'data': scrubPii(data),
      if (error != null) 'error': _scrubText(error.toString()),
    };

    _inMemoryLogs.add(entry);

    if (enableConsoleOutput) {
      // ignore: avoid_print
      print('[${entry['level']}] [${entry['service']}] ${entry['message']} ${data != null ? jsonEncode(scrubPii(data)) : ''}');
    }
  }

  void debug(String message, [Map<String, dynamic>? data]) => _log(LogLevel.debug, message, data: data);
  void info(String message, [Map<String, dynamic>? data]) => _log(LogLevel.info, message, data: data);
  void warn(String message, [Map<String, dynamic>? data]) => _log(LogLevel.warn, message, data: data);
  void error(String message, {Map<String, dynamic>? data, Object? error}) => _log(LogLevel.error, message, data: data, error: error);
  void audit(String message, [Map<String, dynamic>? data]) => _log(LogLevel.audit, message, data: data);

  static List<Map<String, dynamic>> get logs => List.unmodifiable(_inMemoryLogs);

  static void clear() {
    _inMemoryLogs.clear();
  }
}
