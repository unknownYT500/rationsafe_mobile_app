// ration_safe_mobile_app/lib/config/env.dart

/// Configuration for GrainTrust / RationSafe mobile terminal.
/// Values can be overridden at build time via `--dart-define`:
/// e.g. flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=your_key
class AppEnv {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54321', // default local Supabase or override
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'dummy_key',
    ),
  );

  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'http://localhost:3001',
  );

  static const String defaultNodeId = String.fromEnvironment(
    'NODE_ID',
    defaultValue: 'node-alpha-001',
  );

  static const String defaultNodeName = String.fromEnvironment(
    'NODE_NAME',
    defaultValue: 'Sector 4 Community Depot',
  );
}
