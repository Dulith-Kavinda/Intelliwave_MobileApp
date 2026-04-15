/// Supabase configuration options for IntelIWave app
/// 
/// Get your Supabase URL and API keys from:
/// https://app.supabase.com → Settings → API Keys
class SupabaseOptions {
  /// Replace with your Supabase project URL
  /// Format: https://your-project-id.supabase.co
  static const String url = 'https://hugupkmzvaojmlqzspde.supabase.co';

  /// Replace with your Supabase public (anon) API key
  /// This is the safe key for client-side usage
  static const String anonKey = 'sb_publishable_igZctlD0iSyJE-mC8DuWFA_WvfebSrx';

  /// Optional: Service role key (only for server-side operations)
  /// DO NOT expose this key in your client app
  static const String serviceRoleKey = 'sb_secret_zRCBPTZHsRXcQFRKKsRgpA_IV2dJih8';
}
