// ration_safe_mobile_app/lib/models/provisional_token.dart

class ProvisionalTokenPayload {
  final int v; // version 1
  final String tid; // txn_uuid
  final String nid; // node_uuid
  final String lid; // lot_uuid
  final String gid; // grant_uuid
  final String qid; // quota_res_uuid
  final String sub; // sha256_hash_of_card_id
  final String n; // unique_nonce
  final int c; // counter
  final double qty; // quantity in kg
  final String unit; // 'kg'
  final int iat; // issued at (unix seconds)
  final int exp; // expires at (unix seconds)
  final String kid; // key id / node public key id

  const ProvisionalTokenPayload({
    this.v = 1,
    required this.tid,
    required this.nid,
    required this.lid,
    required this.gid,
    required this.qid,
    required this.sub,
    required this.n,
    required this.c,
    required this.qty,
    this.unit = 'kg',
    required this.iat,
    required this.exp,
    required this.kid,
  });

  Map<String, dynamic> toJson() {
    return {
      'c': c,
      'exp': exp,
      'gid': gid,
      'iat': iat,
      'kid': kid,
      'lid': lid,
      'n': n,
      'nid': nid,
      'qid': qid,
      'qty': qty,
      'sub': sub,
      'tid': tid,
      'unit': unit,
      'v': v,
    };
  }

  factory ProvisionalTokenPayload.fromJson(Map<String, dynamic> json) {
    return ProvisionalTokenPayload(
      v: (json['v'] as num?)?.toInt() ?? 1,
      tid: json['tid']?.toString() ?? '',
      nid: json['nid']?.toString() ?? '',
      lid: json['lid']?.toString() ?? '',
      gid: json['gid']?.toString() ?? '',
      qid: json['qid']?.toString() ?? '',
      sub: json['sub']?.toString() ?? '',
      n: json['n']?.toString() ?? '',
      c: (json['c'] as num?)?.toInt() ?? 1,
      qty: (json['qty'] as num?)?.toDouble() ?? 5.0,
      unit: json['unit']?.toString() ?? 'kg',
      iat: (json['iat'] as num?)?.toInt() ?? 0,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      kid: json['kid']?.toString() ?? '',
    );
  }
}

class SignedProvisionalToken {
  final String id;
  final String txnId;
  final ProvisionalTokenPayload payload;
  final String signature;
  final String keyId;
  final String createdAt;

  const SignedProvisionalToken({
    required this.id,
    required this.txnId,
    required this.payload,
    required this.signature,
    required this.keyId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'txn_id': txnId,
      'payload': payload.toJson(),
      'signature': signature,
      'key_id': keyId,
      'created_at': createdAt,
    };
  }

  factory SignedProvisionalToken.fromJson(Map<String, dynamic> json) {
    return SignedProvisionalToken(
      id: json['id']?.toString() ?? '',
      txnId: json['txn_id']?.toString() ?? '',
      payload: ProvisionalTokenPayload.fromJson(
        json['payload'] is Map<String, dynamic>
            ? json['payload']
            : Map<String, dynamic>.from(json['payload'] ?? {}),
      ),
      signature: json['signature']?.toString() ?? '',
      keyId: json['key_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
