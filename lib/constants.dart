// ration_safe_mobile_app/lib/constants.dart
import 'config/env.dart';

/// App-wide constants for GrainTrust Autonomous PDS Terminal.

/// Backend API host URL.
const String kBaseUrl = AppEnv.backendApiUrl;

/// Node/Terminal ID for this device.
const String kShopId = AppEnv.defaultNodeId;

/// Terminal display name.
const String kShopName = AppEnv.defaultNodeName;

class ReasonCodes {
  ReasonCodes._();

  static const err201 = 'ERR_201'; // Beneficiary Quota Limit Exceeded
  static const err202 = 'ERR_202'; // Emergency Grain Lot Depleted
  static const err301 = 'ERR_301'; // Invalid Signature
  static const err302 = 'ERR_302'; // Replay Attack / Duplicate Nonce
  static const err401 = 'ERR_401'; // Central Rejection / Conflict
  static const err402 = 'ERR_402'; // Expired Token Window
  static const err403 = 'ERR_403'; // Quota Lease Depleted
  static const err409 = 'ERR_409'; // Invalid State Transition
  static const err500 = 'ERR_500'; // Internal Server Error

  static const List<String> all = [
    err201,
    err202,
    err301,
    err302,
    err401,
    err402,
    err403,
    err409,
    err500,
  ];

  static bool isValid(String code) => all.contains(code);
}

class RecordStates {
  RecordStates._();

  static const attempt = 'ATTEMPT';
  static const failReason = 'FAIL_REASON';
  static const fallbackAuth = 'FALLBACK_AUTH';
  static const provisionalIssue = 'PROVISIONAL_ISSUE';
  static const reconciled = 'RECONCILED';

  static const List<String> all = [
    attempt,
    failReason,
    fallbackAuth,
    provisionalIssue,
    reconciled,
  ];

  static bool isValid(String state) => all.contains(state);
}
