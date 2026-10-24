// ration_safe_mobile_app/lib/models/registration.dart

class RegistrationData {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String dob;
  final int familyCount;
  final double yearlyIncome;
  final String address;
  final String city;
  final String state;
  final bool consentOptIn;

  const RegistrationData({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.dob,
    required this.familyCount,
    required this.yearlyIncome,
    required this.address,
    required this.city,
    required this.state,
    required this.consentOptIn,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory RegistrationData.fromJson(Map<String, dynamic> json) {
    return RegistrationData(
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      dob: json['dob']?.toString() ?? '1992-05-14',
      familyCount: (json['family_count'] as num?)?.toInt() ?? 1,
      yearlyIncome: (json['yearly_income'] as num?)?.toDouble() ?? 50000.0,
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      consentOptIn: json['consent_opt_in'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'dob': dob,
      'family_count': familyCount,
      'yearly_income': yearlyIncome,
      'address': address,
      'city': city,
      'state': state,
      'consent_opt_in': consentOptIn,
    };
  }
}

class RegistrationItem {
  final String id;
  final String status; // 'SUBMITTED' | 'VERIFIED' | 'APPROVED'
  final String? nodeId;
  final RegistrationData data;
  final String? personId;
  final String? cardId;
  final String createdAt;
  final String updatedAt;

  const RegistrationItem({
    required this.id,
    required this.status,
    this.nodeId,
    required this.data,
    this.personId,
    this.cardId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RegistrationItem.fromJson(Map<String, dynamic> json) {
    return RegistrationItem(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SUBMITTED',
      nodeId: json['node_id']?.toString(),
      data: RegistrationData.fromJson(
        json['data'] is Map<String, dynamic>
            ? json['data']
            : (json['data'] is Map ? Map<String, dynamic>.from(json['data']) : {}),
      ),
      personId: json['person_id']?.toString(),
      cardId: json['card_id']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'node_id': nodeId,
      'data': data.toJson(),
      'person_id': personId,
      'card_id': cardId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
