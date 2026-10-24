// ration_safe_mobile_app/lib/models/beneficiary.dart

class CardBeneficiary {
  final String id;
  final String personId;
  final String status; // 'ACTIVE' | 'SUSPENDED' | 'REVOKED'
  final String issuedAt;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phoneNumber;
  final int familyCount;
  final String address;
  final String city;
  final String state;
  final double allocatedQty;
  final double consumedQty;
  final double remainingQty;

  const CardBeneficiary({
    required this.id,
    required this.personId,
    required this.status,
    required this.issuedAt,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phoneNumber,
    required this.familyCount,
    required this.address,
    required this.city,
    required this.state,
    required this.allocatedQty,
    required this.consumedQty,
    required this.remainingQty,
  });

  factory CardBeneficiary.fromJson(Map<String, dynamic> json) {
    final alloc = (json['allocated_qty'] as num?)?.toDouble() ?? 0.0;
    final cons = (json['consumed_qty'] as num?)?.toDouble() ?? 0.0;
    final rem = (json['remaining_qty'] as num?)?.toDouble() ?? (alloc - cons);

    final fName = json['first_name']?.toString() ?? '';
    final lName = json['last_name']?.toString() ?? '';
    final full = json['full_name']?.toString() ?? '$fName $lName'.trim();

    return CardBeneficiary(
      id: json['id']?.toString() ?? '',
      personId: json['person_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      issuedAt: json['issued_at']?.toString() ?? '',
      firstName: fName,
      lastName: lName,
      fullName: full.isEmpty ? 'Citizen' : full,
      phoneNumber: json['phone_number']?.toString() ?? '',
      familyCount: (json['family_count'] as num?)?.toInt() ?? 1,
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      allocatedQty: alloc,
      consumedQty: cons,
      remainingQty: rem < 0 ? 0 : rem,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'person_id': personId,
      'status': status,
      'issued_at': issuedAt,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'family_count': familyCount,
      'address': address,
      'city': city,
      'state': state,
      'allocated_qty': allocatedQty,
      'consumed_qty': consumedQty,
      'remaining_qty': remainingQty,
    };
  }
}
