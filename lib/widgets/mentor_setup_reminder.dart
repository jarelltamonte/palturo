import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/services/app_navigation.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/widgets/mentor_setup_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads the owner's profile and shows the mentor readiness reminder on the
/// Activity page. Collapses to zero height when the mentor side is ready, and
/// reloads after a profile save so the layout shifts with the content.
class MentorSetupReminder extends StatefulWidget {
  const MentorSetupReminder({
    super.key,
    this.profileLoader,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
    this.onTap,
  });

  /// Test hook: replaces the profile read.
  final Future<ProfileData?> Function()? profileLoader;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  State<MentorSetupReminder> createState() => _MentorSetupReminderState();
}

class _MentorSetupReminderState extends State<MentorSetupReminder>
    with WidgetsBindingObserver {
  static Future<ProfileData?>? _sharedLoad;
  static int _sharedRevision = -1;
  static String? _sharedUserId;
  static DateTime? _sharedAt;
  static int _activeReminders = 0;

  ProfileData? _profile;
  int _loadedRevision = -1;
  bool _loading = false;
  bool _pendingReload = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _activeReminders++;
    WidgetsBinding.instance.addObserver(this);
    ProfileService.profileRevision.addListener(_onProfileChanged);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _load(force: true);
    });
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ProfileService.profileRevision.removeListener(_onProfileChanged);
    _activeReminders = _activeReminders > 0 ? _activeReminders - 1 : 0;
    if (_activeReminders == 0) {
      // Sign-out unmounts the shell. Drop the previous account's profile
      // rather than keeping it in memory for the next session.
      _sharedLoad = null;
      _sharedRevision = -1;
      _sharedUserId = null;
      _sharedAt = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(force: true);
  }

  void _onProfileChanged() {
    if (_loading) {
      _pendingReload = true;
      return;
    }
    _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    if (_loading) {
      _pendingReload = true;
      return;
    }
    if (!force &&
        _profile != null &&
        _loadedRevision == ProfileService.profileRevision.value) {
      return;
    }
    _loading = true;
    var succeeded = false;
    try {
      final revisionAtStart = ProfileService.profileRevision.value;
      final loader = widget.profileLoader;
      final ProfileData? profile;
      if (loader != null) {
        profile = await loader();
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final now = DateTime.now();
        final stale =
            _sharedAt == null ||
            now.difference(_sharedAt!) > const Duration(seconds: 30);
        if (_sharedRevision != revisionAtStart ||
            _sharedLoad == null ||
            _sharedUserId != userId ||
            (force && stale)) {
          _sharedRevision = revisionAtStart;
          _sharedUserId = userId;
          _sharedAt = now;
          _sharedLoad = ProfileService().getCurrentUserProfile();
        }
        profile = await _sharedLoad;
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadedRevision = revisionAtStart;
      });
      succeeded = true;
    } catch (_) {
      // A failed read simply leaves the reminder hidden.
      if (widget.profileLoader == null) {
        _sharedRevision = -1;
        _sharedUserId = null;
        _sharedAt = null;
        _sharedLoad = null;
      }
    } finally {
      _loading = false;
    }

    if (!mounted) return;
    if (succeeded &&
        (_pendingReload ||
            ProfileService.profileRevision.value != _loadedRevision)) {
      _pendingReload = false;
      await _load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final needsSetup = profile?.needsMentorSetup ?? false;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child:
          !needsSetup
              ? const SizedBox(width: double.infinity, height: 0)
              : Padding(
                padding: widget.padding,
                child: MentorSetupBanner(
                  needsShowcase: !profile!.hasAnyShowcase,
                  needsNotes: !profile.hasAllApprovedTeachingNotes,
                  notesPendingReview: profile.hasTeachingNotesPendingReview,
                  notesRejected: profile.rejectedTeachingNoteNames.isNotEmpty,
                  skillPendingReview: !profile.hasApprovedTeachingSkill,
                  progress: profile.mentorProgress,
                  onTap:
                      widget.onTap ??
                      () {
                        AppRouter.openProfile();
                      },
                ),
              ),
    );
  }
}
