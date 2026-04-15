// Supabase integration point — configure with your project credentials
// import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    // await Supabase.initialize(
    //   url: supabaseUrl,
    //   anonKey: supabaseAnonKey,
    // );
  }
}
