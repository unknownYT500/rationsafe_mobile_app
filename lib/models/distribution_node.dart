// ration_safe_mobile_app/lib/models/distribution_node.dart

class NodeItem {
  final String id;
  final String name;
  final String publicKey;
  final String status; // 'ONLINE' | 'OFFLINE' | 'SYNCING'
  final String lastHeartbeat;
  final int outboxDepth;
  final String location;

  const NodeItem({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.status,
    required this.lastHeartbeat,
    required this.outboxDepth,
    required this.location,
  });

  bool get isOnline => status == 'ONLINE';

  factory NodeItem.fromJson(Map<String, dynamic> json) {
    return NodeItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      publicKey: json['public_key']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ONLINE',
      lastHeartbeat: json['last_heartbeat']?.toString() ?? '',
      outboxDepth: (json['outbox_depth'] as num?)?.toInt() ?? 0,
      location: json['location']?.toString() ?? 'Community Depot',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'public_key': publicKey,
      'status': status,
      'last_heartbeat': lastHeartbeat,
      'outbox_depth': outboxDepth,
      'location': location,
    };
  }
}
