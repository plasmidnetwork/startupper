import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    final res = await _client
        .from('profiles')
        .select('id, email, full_name, headline, location, role')
        .eq('id', user.id)
        .maybeSingle();
    return res;
  }

  Future<void> upsertProfile({
    required String fullName,
    required String headline,
    required String location,
    required String role,
    required bool availableForFreelancing,
    File? avatarFile,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    String? avatarUrl;
    if (avatarFile != null) {
      avatarUrl = await _uploadAvatar(user.id, avatarFile);
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'full_name': fullName,
      'headline': headline,
      'location': location,
      'role': role,
      'available_for_freelancing': availableForFreelancing,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  Future<String> _uploadAvatar(String userId, File file) async {
    final ext = _fileExtension(file.path);
    // Path is relative to the bucket, so no need for 'avatars/' prefix
    // since the bucket is already named 'avatars'
    final path = '$userId.$ext';
    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> upsertFounderDetails({
    required String startupName,
    required String pitch,
    required String stage,
    required List<String> lookingFor,
    String? website,
    String? demoVideo,
    String? appStoreId,
    String? playStoreId,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('founder_details').upsert({
      'user_id': user.id,
      'startup_name': startupName,
      'pitch': pitch,
      'stage': stage,
      'looking_for': lookingFor,
      'website': website,
      'demo_video': demoVideo,
      'app_store_id': appStoreId,
      'play_store_id': playStoreId,
    });
  }

  Future<void> upsertInvestorDetails({
    required String investorType,
    required String ticketSize,
    required List<String> stages,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('investor_details').upsert({
      'user_id': user.id,
      'investor_type': investorType,
      'ticket_size': ticketSize,
      'stages': stages,
    });
  }

  Future<void> upsertEndUserDetails({
    required String mainRole,
    required String experienceLevel,
    required List<String> interests,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    await _client.from('enduser_details').upsert({
      'user_id': user.id,
      'main_role': mainRole,
      'experience_level': experienceLevel,
      'interests': interests,
    });
  }

  String _fileExtension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx == -1 || idx == path.length - 1) return 'jpg';
    return path.substring(idx + 1);
  }
}
