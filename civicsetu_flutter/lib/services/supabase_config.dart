class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('CIVICSETU_SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'CIVICSETU_SUPABASE_PUBLISHABLE_KEY',
  );
  static const String anonKey = String.fromEnvironment(
    'CIVICSETU_SUPABASE_ANON_KEY',
  );
  static const String authScheme = String.fromEnvironment(
    'CIVICSETU_AUTH_SCHEME',
    defaultValue: 'com.civicsetu.mobile',
  );
  static const String authHost = String.fromEnvironment(
    'CIVICSETU_AUTH_HOST',
    defaultValue: 'login-callback',
  );

  static String get publicKey =>
      publishableKey.isNotEmpty ? publishableKey : anonKey;

  static bool get isConfigured =>
      url.trim().isNotEmpty && publicKey.trim().isNotEmpty;

  static String get redirectUrl => '$authScheme://$authHost/';
}
