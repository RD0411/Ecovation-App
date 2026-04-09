class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yzspgiyegrbmrqsxkliz.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl6c3BnaXllZ3JibXJxc3hrbGl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MzAxMjksImV4cCI6MjA5MDEwNjEyOX0.gWVTGVfzEW7MRzrSI9FFIJ8Nl_fkM9WQO2vwgTB_xP0',
  );
}
