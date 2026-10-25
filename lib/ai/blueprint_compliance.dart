import '../models/beneficiary.dart';
import '../crypto/hash_utils.dart';

/// Statutory Ration Card Categorization under the National Food Security Act (NFSA 2013).
enum CardCategory {
  phh, // Priority Household (5 kg / member / month)
  aay, // Antyodaya Anna Yojana (Poorest of poor, 35 kg / household / month)
  ay,  // Annapurna (Senior citizens, 10 kg free)
  gen, // General / State specific
}

/// Regulatory Compliance Validation Result issued by the Blueprint Policy Engine.
class BlueprintComplianceResult {
  final bool isCompliant;
  final double maxStatutoryAllowanceKg;
  final double requestedQuantityKg;
  final List<String> violations;
  final String policyName;
  final String maskedCardId;
  final String maskedAadhaar;
  final DateTime validatedAt;

  const BlueprintComplianceResult({
    required this.isCompliant,
    required this.maxStatutoryAllowanceKg,
    required this.requestedQuantityKg,
    required this.violations,
    this.policyName = 'NFSA_Statutory_Compliance_2026',
    required this.maskedCardId,
    required this.maskedAadhaar,
    required this.validatedAt,
  });

  Map<String, dynamic> toJson() => {
    'is_compliant': isCompliant,
    'max_statutory_allowance_kg': maxStatutoryAllowanceKg,
    'requested_quantity_kg': requestedQuantityKg,
    'violations': violations,
    'policy_name': policyName,
    'masked_card_id': maskedCardId,
    'masked_aadhaar': maskedAadhaar,
    'validated_at': validatedAt.toIso8601String(),
  };
}

/// Blueprint Statutory Rule Enforcement Engine (NFSA 2013 & PII Data Protection).
class BlueprintComplianceEngine {
  static const double nfsaPhhPerMemberKg = 5.0;
  static const double nfsaAayFixedHouseholdKg = 35.0;
  static const double nfsaAnnapurnaKg = 10.0;
  static const double maximumSingleTransactionLimitKg = 35.0;

  /// Calculates statutory entitlement under NFSA 2013 rules.
  static double calculateStatutoryEntitlement(CardCategory category, int familyCount) {
    switch (category) {
      case CardCategory.aay:
        return nfsaAayFixedHouseholdKg;
      case CardCategory.ay:
        return nfsaAnnapurnaKg;
      case CardCategory.phh:
      case CardCategory.gen:
        final members = familyCount > 0 ? familyCount : 1;
        return members * nfsaPhhPerMemberKg;
    }
  }

  /// Validates a grain dispensing request against statutory NFSA quotas and PII protection rules.
  static Future<BlueprintComplianceResult> validateDispense({
    required CardBeneficiary card,
    required double requestedQuantityKg,
    CardCategory category = CardCategory.phh,
    String? aadhaarNumber,
  }) async {
    final violations = <String>[];
    final now = DateTime.now().toUtc();

    // 1. Calculate Maximum Statutory Allowance based on Card Category
    final statutoryAllowance = calculateStatutoryEntitlement(category, card.familyCount);

    // 2. Check: Requested Quantity <= 0
    if (requestedQuantityKg <= 0) {
      violations.add('INVALID_QUANTITY: Dispense quantity must be greater than 0 kg.');
    }

    // 3. Check: Requested Quantity > Statutory Allowance
    if (requestedQuantityKg > statutoryAllowance) {
      violations.add(
        'STATUTORY_QUOTA_EXCEEDED: Requested quantity (${requestedQuantityKg}kg) exceeds statutory NFSA limit (${statutoryAllowance}kg) for category ${category.name.toUpperCase()}.',
      );
    }

    // 4. Check: Requested Quantity > Card Remaining Balance
    if (requestedQuantityKg > card.remainingQty) {
      violations.add(
        'CARD_BALANCE_EXCEEDED: Requested quantity (${requestedQuantityKg}kg) exceeds card remaining balance (${card.remainingQty}kg).',
      );
    }

    // 5. Check: Single Transaction Limit
    if (requestedQuantityKg > maximumSingleTransactionLimitKg) {
      violations.add(
        'TRANSACTION_CEILING_BREACH: Single transaction cannot exceed ${maximumSingleTransactionLimitKg}kg without District Civil Supplies Officer authorization.',
      );
    }

    // 6. Cryptographic PII Masking
    final maskedCard = await maskIdentifier(card.id);
    final maskedAadhaar = maskAadhaar(aadhaarNumber ?? card.phoneNumber);

    return BlueprintComplianceResult(
      isCompliant: violations.isEmpty,
      maxStatutoryAllowanceKg: statutoryAllowance,
      requestedQuantityKg: requestedQuantityKg,
      violations: violations,
      maskedCardId: maskedCard,
      maskedAadhaar: maskedAadhaar,
      validatedAt: now,
    );
  }

  /// Cryptographically masks card identifiers using SHA-256 for privacy-preserving telemetry.
  static Future<String> maskIdentifier(String id) async {
    if (id.isEmpty) return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
    return await hashCardId(id);
  }

  /// Masks sensitive Aadhaar/phone numbers, retaining only the last 4 characters for operator verification.
  static String maskAadhaar(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.length <= 4) return 'XXXX-XXXX-${clean.padLeft(4, '0')}';
    final last4 = clean.substring(clean.length - 4);
    return 'XXXX-XXXX-$last4';
  }
}
