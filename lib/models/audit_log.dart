// ration_safe_mobile_app/lib/models/audit_log.dart

class AuditLogItem {
  final String id;
  final String actorId;
  final String action;
  final String resourceType;
  final String resourceId;
  final Map<String, dynamic> details;
  final String timestamp;

  const AuditLogItem({
    required this.id,
    required this.actorId,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogItem.fromJson(Map<String, dynamic> json) {
    return AuditLogItem(
      id: json['id']?.toString() ?? '',
      actorId: json['actor_id']?.toString() ?? 'system',
      action: json['action']?.toString() ?? 'SYSTEM_EVENT',
      resourceType: json['resource_type']?.toString() ?? 'SYSTEM',
      resourceId: json['resource_id']?.toString() ?? '',
      details: json['details'] is Map<String, dynamic>
          ? json['details']
          : (json['details'] is Map ? Map<String, dynamic>.from(json['details']) : {}),
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actor_id': actorId,
      'action': action,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'details': details,
      'timestamp': timestamp,
    };
  }
}
