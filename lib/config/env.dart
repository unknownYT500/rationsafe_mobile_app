// ration_safe_mobile_app/lib/config/env.dart

/// Configuration for GrainTrust / RationSafe mobile terminal.
/// Values can be overridden at build time via `--dart-define`:
/// e.g. flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=your_key
class AppEnv {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://byxvxvsvhiyeryavgafx.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ5eHZ4dnN2aGl5ZXJ5YXZnYWZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwNzU3MjksImV4cCI6MjEwNzY1MTcyOX0.UU-Qs8cO4bcDZ-5qZA9xgEDRjLY1IDr65ZMaoyK3AsA',
    ),
  );

  static const String backendApiUrl = String.fromEnvironment(
    'BACKEND_API_URL',
    defaultValue: 'https://byxvxvsvhiyeryavgafx.supabase.co',
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
