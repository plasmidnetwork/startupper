import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Map<String, dynamic>? _profileCache;
  final Map<String, Map<String, dynamic>?> _roleDetailsCache = {};

  Future<Map<String, dynamic>?> fetchProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _profileCache != null) return _profileCache;

    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    final res = await _client
        .from('profiles')
        .select(
            'id, email, full_name, headline, location, role, available_for_freelancing, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    _profileCache = res;
    return _profileCache;
  }

  Future<Map<String, dynamic>?> fetchRoleDetails(String role) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    switch (role.toLowerCase()) {
      case 'founder':
        return _client
            .from('founder_details')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
      case 'investor':
        return _client
            .from('investor_details')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
      case 'end-user':
      case 'enduser':
        return _client
            .from('enduser_details')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRoleDetailsForUser(
      String userId, String role,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _roleDetailsCache['$userId:$role'];
      if (cached != null) return cached;
    }
    switch (role.toLowerCase()) {
      case 'founder':
        final res = await _client
            .from('founder_details')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        _roleDetailsCache['$userId:$role'] = res;
        return res;
      case 'investor':
        final res = await _client
            .from('investor_details')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        _roleDetailsCache['$userId:$role'] = res;
        return res;
      case 'end-user':
      case 'enduser':
        final res = await _client
            .from('enduser_details')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        _roleDetailsCache['$userId:$role'] = res;
        return res;
      default:
        return null;
    }
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

    _profileCache = {
      'id': user.id,
      'email': user.email,
      'full_name': fullName,
      'headline': headline,
      'location': location,
      'role': role,
      'available_for_freelancing': availableForFreelancing,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  Future<String> _uploadAvatar(String userId, File file) async {
    final ext = _fileExtension(file.path);
    final contentType = _contentTypeForExtension(ext);
    // Path is relative to the bucket, so no need for 'avatars/' prefix
    // since the bucket is already named 'avatars'
    final path = '$userId.$ext';
    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
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

  String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  void clearProfileCache() {
    _profileCache = null;
    _roleDetailsCache.clear();
  }
}
