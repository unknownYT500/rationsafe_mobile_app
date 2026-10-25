// mobile/lib/telemetry/tracer.dart
import 'dart:math';

/// W3C Trace Context (RFC standard for distributed tracing).
class TraceContext {
  final String version;
  final String traceId; // 16 bytes = 32 hex chars
  final String spanId;  // 8 bytes = 16 hex chars
  final String traceFlags; // 1 byte = 2 hex chars ('01' = sampled)

  const TraceContext({
    this.version = '00',
    required this.traceId,
    required this.spanId,
    this.traceFlags = '01',
  });

  /// Formats W3C traceparent header: 00-{trace_id}-{span_id}-{trace_flags}
  String toTraceparent() {
    return '$version-$traceId-$spanId-$traceFlags';
  }

  /// Parses an incoming W3C traceparent header.
  static TraceContext? parse(String? traceparent) {
    if (traceparent == null || traceparent.isEmpty) return null;
    final parts = traceparent.trim().split('-');
    if (parts.length != 4) return null;
    if (parts[0] != '00') return null; // Only version 00 supported
    if (parts[1].length != 32 || parts[1] == '00000000000000000000000000000000') return null;
    if (parts[2].length != 16 || parts[2] == '0000000000000000') return null;
    return TraceContext(
      version: parts[0],
      traceId: parts[1],
      spanId: parts[2],
      traceFlags: parts[3],
    );
  }

  /// Creates a new child TraceContext preserving the traceId but allocating a new spanId.
  TraceContext createChild() {
    return TraceContext(
      version: version,
      traceId: traceId,
      spanId: Tracer.generateSpanId(),
      traceFlags: traceFlags,
    );
  }
}

/// In-memory representation of an OpenTelemetry span.
class Span {
  final String name;
  final TraceContext context;
  final String? parentSpanId;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, dynamic> attributes;
  String status; // 'OK', 'ERROR', 'UNSET'
  String? errorMessage;

  Span({
    required this.name,
    required this.context,
    this.parentSpanId,
    DateTime? startTime,
    Map<String, dynamic>? attributes,
    this.status = 'OK',
  })  : startTime = startTime ?? DateTime.now().toUtc(),
        attributes = attributes ?? {};

  void setAttribute(String key, dynamic value) {
    attributes[key] = value;
  }

  void end({String? status, String? error}) {
    endTime = DateTime.now().toUtc();
    if (status != null) this.status = status;
    if (error != null) {
      this.status = 'ERROR';
      errorMessage = error;
    }
  }

  Duration get duration {
    final end = endTime ?? DateTime.now().toUtc();
    return end.difference(startTime);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'trace_id': context.traceId,
    'span_id': context.spanId,
    'parent_span_id': parentSpanId,
    'traceparent': context.toTraceparent(),
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': status,
    if (errorMessage != null) 'error_message': errorMessage,
    'attributes': attributes,
  };
}

/// OpenTelemetry-compatible Distributed Tracer for Mobile POS terminals.
class Tracer {
  static final _random = Random.secure();
  static final List<Span> _exportedSpans = [];
  static TraceContext? _currentContext;

  /// Generates a cryptographically secure 16-byte (32-character hex) traceId.
  static String generateTraceId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // Ensure non-zero
    if (bytes.every((b) => b == 0)) bytes[0] = 1;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a cryptographically secure 8-byte (16-character hex) spanId.
  static String generateSpanId() {
    final bytes = List<int>.generate(8, (_) => _random.nextInt(256));
    if (bytes.every((b) => b == 0)) bytes[0] = 1;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Starts a new active span.
  static Span startSpan(
    String name, {
    TraceContext? parentContext,
    Map<String, dynamic>? attributes,
  }) {
    final parent = parentContext ?? _currentContext;
    TraceContext ctx;
    String? parentSpanId;

    if (parent != null) {
      ctx = parent.createChild();
      parentSpanId = parent.spanId;
    } else {
      ctx = TraceContext(
        traceId: generateTraceId(),
        spanId: generateSpanId(),
      );
    }

    _currentContext = ctx;

    final span = Span(
      name: name,
      context: ctx,
      parentSpanId: parentSpanId,
      attributes: attributes,
    );
    _exportedSpans.add(span);
    return span;
  }

  /// Returns the current active trace context.
  static TraceContext? get currentContext => _currentContext;

  /// Sets the active trace context.
  static void setCurrentContext(TraceContext? context) {
    _currentContext = context;
  }

  /// Returns all spans recorded in the current session.
  static List<Span> get spans => List.unmodifiable(_exportedSpans);

  /// Clears in-memory spans (useful between tests).
  static void clear() {
    _exportedSpans.clear();
    _currentContext = null;
  }
}
