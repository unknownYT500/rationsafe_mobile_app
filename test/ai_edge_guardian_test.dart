import 'package:flutter_test/flutter_test.dart';
import 'package:ration_safe/ai/edge_guardian.dart';
import 'package:ration_safe/ai/blueprint_compliance.dart';
import 'package:ration_safe/ai/vernacular_engine.dart';
import 'package:ration_safe/models/beneficiary.dart';

void main() {
  CardBeneficiary createSampleCard({
    String id = 'card-test-001',
    int familyCount = 4,
    double allocatedQty = 20.0,
    double consumedQty = 5.0,
    double remainingQty = 15.0,
  }) {
    return CardBeneficiary(
      id: id,
      personId: 'person-test-001',
      status: 'ACTIVE',
      issuedAt: '2026-01-01T00:00:00Z',
      firstName: 'Sunita',
      lastName: 'Devi',
      fullName: 'Sunita Devi',
      phoneNumber: '+919876543210',
      familyCount: familyCount,
      address: 'Village Rampur',
      city: 'Varanasi',
      state: 'Uttar Pradesh',
      allocatedQty: allocatedQty,
      consumedQty: consumedQty,
      remainingQty: remainingQty,
    );
  }

  setUp(() {
    EdgeGuardianService.resetState();
  });

  group('Edge Guardian AI Anomaly Detection Unit Tests', () {
    test('Normal transaction receives LOW risk and ALLOW action', () async {
      final card = createSampleCard();
      final assessment = await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-001',
        card: card,
        requestedQuantityKg: 5.0,
        currentCounter: 10,
        timestampOverride: DateTime(2026, 10, 25, 10, 30), // 10:30 AM
        persistToDb: false,
      );

      expect(assessment.riskLevel, RiskLevel.low);
      expect(assessment.recommendedAction, GuardianAction.allow);
      expect(assessment.flags, isEmpty);
    });

    test('Rapid velocity (< 15s) triggers FLAG_FOR_AUDIT with high frequency flag', () async {
      final card = createSampleCard();
      // First transaction
      await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-002-a',
        card: card,
        requestedQuantityKg: 5.0,
        currentCounter: 10,
        timestampOverride: DateTime(2026, 10, 25, 11, 0, 0),
        persistToDb: false,
      );

      // Second transaction 8 seconds later (< 15s)
      final assessment = await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-002-b',
        card: card,
        requestedQuantityKg: 5.0,
        currentCounter: 11,
        timestampOverride: DateTime(2026, 10, 25, 11, 0, 8),
        persistToDb: false,
      );

      expect(assessment.riskScore, greaterThanOrEqualTo(0.35));
      expect(assessment.flags.any((f) => f.contains('HIGH_FREQUENCY_SCAN')), isTrue);
      expect(assessment.recommendedAction, GuardianAction.flagForAudit);
    });

    test('Off-hours night transaction (23:00) triggers off-hours anomaly flag', () async {
      final card = createSampleCard();
      final assessment = await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-003',
        card: card,
        requestedQuantityKg: 5.0,
        currentCounter: 15,
        timestampOverride: DateTime(2026, 10, 25, 23, 15), // 11:15 PM
        persistToDb: false,
      );

      expect(assessment.riskScore, greaterThanOrEqualTo(0.35));
      expect(assessment.flags.any((f) => f.contains('OFF_HOURS_ACTIVITY')), isTrue);
      expect(assessment.recommendedAction, GuardianAction.flagForAudit);
    });

    test('Multiple collusion indicators trigger CRITICAL BLOCK action', () async {
      final card = createSampleCard(remainingQty: 5.0);
      // Prime previous scan
      await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-004-a',
        card: card,
        requestedQuantityKg: 5.0,
        currentCounter: 20,
        timestampOverride: DateTime(2026, 10, 25, 3, 0, 0),
        persistToDb: false,
      );

      // Off-hours (3 AM) + rapid velocity (5s) + quota overdraw (10kg > 5kg remaining)
      final assessment = await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-004-b',
        card: card,
        requestedQuantityKg: 10.0,
        currentCounter: 21,
        timestampOverride: DateTime(2026, 10, 25, 3, 0, 5),
        persistToDb: false,
      );

      expect(assessment.riskScore, greaterThanOrEqualTo(0.90));
      expect(assessment.riskLevel, RiskLevel.critical);
      expect(assessment.recommendedAction, GuardianAction.block);
      expect(assessment.flags.length, greaterThanOrEqualTo(3));
    });

    test('Counter sequence gap and volume spike elevate risk level', () async {
      final card = createSampleCard(remainingQty: 50.0);
      await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-005-a',
        card: card,
        requestedQuantityKg: 5.0,
        currentCounter: 100,
        timestampOverride: DateTime(2026, 10, 25, 12, 0, 0),
        persistToDb: false,
      );

      // 30 kg volumetric spike + counter gap of 10
      final assessment = await EdgeGuardianService.evaluateTransaction(
        tokenId: 'disp-005-b',
        card: card,
        requestedQuantityKg: 30.0,
        currentCounter: 110,
        timestampOverride: DateTime(2026, 10, 25, 12, 5, 0),
        persistToDb: false,
      );

      expect(assessment.flags.any((f) => f.contains('MONOTONIC_SEQUENCE_GAP')), isTrue);
      expect(assessment.flags.any((f) => f.contains('UNUSUAL_GRAIN_VOLUME')), isTrue);
      expect(assessment.riskScore, greaterThanOrEqualTo(0.50));
    });
  });

  group('Blueprint Statutory Policy & NFSA Compliance Tests', () {
    test('Calculates statutory entitlements strictly per NFSA 2013 rules', () {
      // Priority Household: 5 kg per member
      expect(BlueprintComplianceEngine.calculateStatutoryEntitlement(CardCategory.phh, 4), 20.0);
      expect(BlueprintComplianceEngine.calculateStatutoryEntitlement(CardCategory.phh, 6), 30.0);

      // Antyodaya Anna Yojana: Fixed 35 kg per household regardless of size
      expect(BlueprintComplianceEngine.calculateStatutoryEntitlement(CardCategory.aay, 1), 35.0);
      expect(BlueprintComplianceEngine.calculateStatutoryEntitlement(CardCategory.aay, 8), 35.0);

      // Annapurna: 10 kg fixed
      expect(BlueprintComplianceEngine.calculateStatutoryEntitlement(CardCategory.ay, 1), 10.0);
    });

    test('Validates legitimate dispense within entitlement', () async {
      final card = createSampleCard(familyCount: 4, allocatedQty: 20.0, remainingQty: 15.0);

      final result = await BlueprintComplianceEngine.validateDispense(
        card: card,
        category: CardCategory.phh,
        requestedQuantityKg: 10.0,
      );

      expect(result.isCompliant, isTrue);
      expect(result.maxStatutoryAllowanceKg, 20.0);
      expect(result.requestedQuantityKg, 10.0);
      expect(result.violations, isEmpty);
      expect(result.maskedCardId.isNotEmpty, isTrue);
    });

    test('Rejects dispense exceeding statutory or card balance ceiling', () async {
      final card = createSampleCard(familyCount: 3, allocatedQty: 15.0, remainingQty: 5.0);

      final result = await BlueprintComplianceEngine.validateDispense(
        card: card,
        category: CardCategory.phh,
        requestedQuantityKg: 10.0, // only 5.0 kg remaining
      );

      expect(result.isCompliant, isFalse);
      expect(result.violations.any((v) => v.contains('CARD_BALANCE_EXCEEDED')), isTrue);
    });

    test('Cryptographically masks citizen identifiers with SHA-256 and Aadhaar format', () async {
      final maskedCard = await BlueprintComplianceEngine.maskIdentifier('CARD-CONFIDENTIAL-999');
      expect(maskedCard.length, 64); // SHA-256 hex string
      expect(maskedCard, isNot(contains('CARD-CONFIDENTIAL-999')));

      final maskedAadhaar = BlueprintComplianceEngine.maskAadhaar('987654321098');
      expect(maskedAadhaar, 'XXXX-XXXX-1098');
    });
  });

  group('Vernacular Voice & Grievance Engine Tests', () {
    test('Parses Hindi quota inquiry and synthesizes regional response', () {
      final intent = VernacularEngine.parseUtterance('Mera kitna chawal bacha hai bhai', languageHint: 'hi');
      expect(intent.type, VernacularIntentType.queryBalance);
      expect(intent.confidence, greaterThan(0.9));

      final card = createSampleCard(remainingQty: 12.5);
      final response = VernacularEngine.synthesizeResponse(
        intent: intent,
        card: card,
      );
      expect(response, contains('12.5'));
    });

    test('Parses Bhojpuri dialect correctly', () {
      final intent = VernacularEngine.parseUtterance('रउआ कार्ड पर हमरा कतना चावल बा', languageHint: 'bho');
      expect(intent.type, VernacularIntentType.queryBalance);

      final card = createSampleCard(remainingQty: 15.0);
      final response = VernacularEngine.synthesizeResponse(
        intent: intent,
        card: card,
        languageOverride: 'bho',
      );
      expect(response, contains('रउआ कार्ड पर अभी 15.0 किलो अनाज बाकी बा'));
    });

    test('Parses schedule inquiry and synthesizes timing details', () {
      final intent = VernacularEngine.parseUtterance('Dukaan kab khulegi timing kya hai', languageHint: 'hi');
      expect(intent.type, VernacularIntentType.querySchedule);

      final response = VernacularEngine.synthesizeResponse(intent: intent);
      expect(response, contains('सुबह 8'));
    });

    test('Parses grievance and registers offline ticket with valid ticket ID', () async {
      final intent = VernacularEngine.parseUtterance('Dukaandar ne 2 kilo kam diya aur paisa manga', languageHint: 'hi');
      expect(intent.type, VernacularIntentType.fileGrievance);
      expect(intent.grievanceCategory, GrievanceCategory.underWeighing);

      final card = createSampleCard();
      final grievance = await VernacularEngine.registerOfflineGrievance(
        card: card,
        category: GrievanceCategory.underWeighing,
        rawTranscript: 'Dukaandar ne 2 kilo kam diya aur paisa manga',
        language: 'hi',
      );

      expect(grievance.id, startsWith('GRV-'));
      expect(grievance.category, GrievanceCategory.underWeighing);
      expect(grievance.status, 'REGISTERED');
    });
  });
}
