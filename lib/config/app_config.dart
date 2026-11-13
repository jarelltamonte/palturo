/// Compile-time Supabase configuration.
///
/// Pass these with `--dart-define`; they are never bundled as assets.
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
