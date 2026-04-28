import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/widgets/error_screen.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../session/application/session_providers.dart';
import '../data/avatar_repository.dart';
import '../data/user_repository.dart';
import '../domain/app_user.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _displayNameController = TextEditingController();
  String? _avatarUrl;
  bool _initialized = false;
  bool _saving = false;
  String? _errorText;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _refreshAvatarUrl(String? path) async {
    if (path == null) {
      setState(() => _avatarUrl = null);
      return;
    }
    try {
      final url = await ref.read(avatarRepositoryProvider).resolveDownloadUrl(path);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (_) {
      if (!mounted) return;
      setState(() => _avatarUrl = null);
    }
  }

  Future<void> _pickAvatar(AppUser current) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final path = await ref.read(avatarRepositoryProvider).uploadFromFile(
            uid: uid,
            file: File(picked.path),
          );
      await ref.read(userRepositoryProvider).update(
            current.copyWith(avatarPath: path),
          );
      await _refreshAvatarUrl(path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile(AppUser current) async {
    final name = _displayNameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = 'Display name needs at least 2 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await ref.read(userRepositoryProvider).update(
            current.copyWith(displayName: name),
          );
      final user = ref.read(firebaseAuthProvider).currentUser;
      await user?.updateDisplayName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingScreen(),
          error: (e, _) => ErrorScreen(
            error: e,
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not available.'));
            }
            if (!_initialized) {
              _displayNameController.text = profile.displayName;
              _initialized = true;
              _refreshAvatarUrl(profile.avatarPath);
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor:
                            theme.colorScheme.primaryContainer,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl != null
                            ? null
                            : Text(
                                profile.displayName.isNotEmpty
                                    ? profile.displayName[0].toUpperCase()
                                    : '?',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: theme
                                      .colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: theme.colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap:
                                _saving ? null : () => _pickAvatar(profile),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.edit,
                                color: theme.colorScheme.onPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller:
                      TextEditingController(text: profile.email),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _saveProfile(profile),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Save profile'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Avatar uploads require the Firebase Storage default '
                  'bucket (Blaze plan). On the Spark plan, other profile '
                  'fields still save normally.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
