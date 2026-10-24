// ration_safe_mobile_app/lib/models/failure_diagnostic.dart

enum DiagnosticSeverity { error, warning, info }

class HumanDiagnostic {
  final String title;
  final String explanation;
  final String remediation;
  final DiagnosticSeverity severity;

  const HumanDiagnostic({
    required this.title,
    required this.explanation,
    required this.remediation,
    required this.severity,
  });
}

HumanDiagnostic getFailureDiagnostic(String? code, String? message) {
  switch (code) {
    case 'ERR_201':
      return HumanDiagnostic(
        title: 'Beneficiary Quota Limit Exceeded',
        explanation: message ??
            'This card has exhausted its allocated monthly grain ration. The requested quantity exceeds the remaining balance for this household.',
        remediation:
            'Reduce the requested quantity to match the available remaining quota, or enable "Supervisor Offline Fallback Override" if field authorization was granted.',
        severity: DiagnosticSeverity.error,
      );
    case 'ERR_202':
      return HumanDiagnostic(
        title: 'Emergency Grain Lot Depleted',
        explanation: message ??
            'The selected grain storage reserve has reached its signed distribution cap. No more grain can be dispensed from this specific lot.',
        remediation:
            'Select a different active grain lot with remaining capacity or request the depot manager to allocate a new lot grant.',
        severity: DiagnosticSeverity.error,
      );
    case 'ERR_301':
      return HumanDiagnostic(
        title: 'Cryptographic Signature Verification Failed',
        explanation:
            'The digital signature on this provisional token does not match the node’s Ed25519 public key. The token payload appears to have been altered or tampered with in transit.',
        remediation:
            'Do not dispense grain on this token. Verify terminal cryptographic key registration in the security console.',
        severity: DiagnosticSeverity.error,
      );
    case 'ERR_302':
      return HumanDiagnostic(
        title: 'Replay Attack Prevented (Duplicate Nonce)',
        explanation:
            'This token nonce or transaction ID has already been verified and permanently committed to the central ledger. Resubmission was rejected to prevent double-spending.',
        remediation:
            'No action needed. The central ledger safely acknowledged the duplicate token without double-deducting grain.',
        severity: DiagnosticSeverity.warning,
      );
    case 'ERR_402':
      return HumanDiagnostic(
        title: 'Provisional Token Window Expired',
        explanation:
            'This provisional offline issuance token was generated outside the acceptable validity time window (expired over 1 hour ago).',
        remediation:
            'Re-issue a fresh distribution attempt on the edge terminal to generate an active cryptographic timestamp.',
        severity: DiagnosticSeverity.error,
      );
    case 'ERR_403':
      return HumanDiagnostic(
        title: 'Terminal Quota Lease Depleted',
        explanation:
            'The local edge terminal has consumed its pre-allocated daily quota lease for offline operations.',
        remediation:
            'Connect the terminal to the central network to sync queued transactions and receive a new quota lease.',
        severity: DiagnosticSeverity.warning,
      );
    case 'ERR_409':
      return HumanDiagnostic(
        title: 'State Transition Violation',
        explanation: message ??
            'The requested lifecycle step violates the 5-state transition engine rules (e.g. attempting to restart a finalized RECONCILED transaction).',
        remediation: 'Begin a new distribution attempt with a fresh idempotency key.',
        severity: DiagnosticSeverity.error,
      );
    default:
      return HumanDiagnostic(
        title: 'Operation Rejected',
        explanation: message ??
            'The transaction could not be processed due to a validation or business policy constraint.',
        remediation:
            'Review the entered parameters, verify card connectivity, and retry the request.',
        severity: DiagnosticSeverity.error,
      );
  }
}
