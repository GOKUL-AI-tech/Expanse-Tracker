import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/profile_model.dart';
import '../../auth/providers/auth_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs)
      : super(_themeModeFromString(_prefs.getString('theme_mode') ?? 'system'));

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _prefs.setString('theme_mode', mode.name);
  }

  static ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileModel?>> {
  final SupabaseClient _supabase;
  final String? _userId;

  ProfileNotifier(this._supabase, this._userId)
      : super(const AsyncValue.loading()) {
    if (_userId != null) fetchProfile();
  }

  Future<void> fetchProfile() async {
    if (_userId == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _userId!)
          .single();
      state = AsyncValue.data(ProfileModel.fromMap(data));
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateProfile(ProfileModel profile) async {
    try {
      await _supabase
          .from('profiles')
          .update(profile.toMap())
          .eq('id', _userId!);
      state = AsyncValue.data(profile);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<String?> uploadAvatar(File file) async {
    try {
      final ext = file.path.split('.').last;
      final path = '$_userId/avatar.$ext';
      await _supabase.storage.from('avatars').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return _supabase.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<ProfileModel?>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = ref.watch(currentUserProvider);
  return ProfileNotifier(supabase, user?.id);
});

final currencyProvider = Provider<String>((ref) {
  return ref.watch(profileProvider).value?.currency ?? 'INR';
});
