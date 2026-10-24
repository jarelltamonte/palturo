import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palturo/onboarding/onboarding_flow.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/widgets/top_labeled_field.dart';

const kOtherId = 'other';
const kOtherPrefix = 'other:';
const kCustomSkillMaxLength = 30;
const kSkillNoteMaxLength = 150;
const kMaxSuggestions = 5;
const kSkillFieldHeight = 56.0;

const kSkillCategories = <({String id, String label, IconData icon})>[
  (id: 'arts_design', label: 'Arts and Design', icon: Icons.palette_outlined),
  (
    id: 'language_culture',
    label: 'Language and Cultural Knowledge',
    icon: Icons.translate,
  ),
  (
    id: 'everyday_skills',
    label: 'Everyday Practical Skills',
    icon: Icons.handyman_outlined,
  ),
  (
    id: 'agriculture_livelihood',
    label: 'Agriculture and Livelihood',
    icon: Icons.agriculture_outlined,
  ),
];

const _kSmallWords = <String>{
  'ng',
  'sa',
  'na',
  'at',
  'ang',
  'mga',
  'ay',
  'o',
  'kay',
  'ni',
  'of',
  'and',
  'the',
  'in',
};

const _kKeywordCategories = <String, String>{
  'cook': 'everyday_skills',
  'bake': 'everyday_skills',
  'repair': 'everyday_skills',
  'martial': 'everyday_skills',
  'sew': 'arts_design',
  'weav': 'arts_design',
  'embroid': 'arts_design',
  'paint': 'arts_design',
  'draw': 'arts_design',
  'craft': 'arts_design',
  'pottery': 'arts_design',
  'carv': 'arts_design',
  'dance': 'language_culture',
  'sing': 'language_culture',
  'music': 'language_culture',
  'drum': 'language_culture',
  'script': 'language_culture',
  'language': 'language_culture',
  'tagalog': 'language_culture',
  'farm': 'agriculture_livelihood',
  'plant': 'agriculture_livelihood',
  'garden': 'agriculture_livelihood',
  'harvest': 'agriculture_livelihood',
  'fish': 'agriculture_livelihood',
  'livestock': 'agriculture_livelihood',
};

String guessSkillCategory(String text) {
  final lower = text.toLowerCase();
  for (final entry in _kKeywordCategories.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return 'everyday_skills';
}

({String id, String label, IconData icon})? categoryById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final c in kSkillCategories) {
    if (c.id == id) return c;
  }
  return null;
}

class CustomSkill {
  final String categoryId;
  final String text;

  const CustomSkill({this.categoryId = '', this.text = ''});

  bool get isValid => categoryId.isNotEmpty && text.trim().isNotEmpty;

  String encode() => '$kOtherPrefix$categoryId:${text.trim()}';

  static CustomSkill? tryParse(String id) {
    if (!id.startsWith(kOtherPrefix)) {
      final lower = id.trim().toLowerCase();
      if (lower == 'other' || lower == 'others') {
        return const CustomSkill();
      }
      return null;
    }
    final rest = id.substring(kOtherPrefix.length);
    final i = rest.indexOf(':');
    if (i < 0) return CustomSkill(text: rest);
    return CustomSkill(
      categoryId: rest.substring(0, i),
      text: rest.substring(i + 1),
    );
  }
}

bool isOtherOption(OnboardingOption o) {
  final id = o.id.trim().toLowerCase();
  final label = o.label.trim().toLowerCase();
  return id == 'other' ||
      id == 'others' ||
      label == 'other' ||
      label == 'others';
}

String toTitleCase(String input) {
  final words = input.split(' ');
  var seenFirstWord = false;
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.isEmpty) continue;
    final lower = w.toLowerCase();
    if (seenFirstWord && _kSmallWords.contains(lower)) {
      words[i] = lower;
    } else {
      words[i] = w[0].toUpperCase() + w.substring(1);
    }
    seenFirstWord = true;
  }
  return words.join(' ');
}

class TitleCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: toTitleCase(newValue.text));
  }
}

bool isPendingSkillId(String id) {
  if (id.trim().isEmpty) return true;
  final custom = CustomSkill.tryParse(id);
  return custom != null && custom.text.trim().isEmpty;
}

class SkillSuggestion {
  final String id;
  final String label;
  final String categoryId;
  final bool isCustom;

  const SkillSuggestion({
    required this.id,
    required this.label,
    required this.categoryId,
    this.isCustom = false,
  });
}

abstract class SkillSuggestionService {
  Future<List<SkillSuggestion>> suggest(
    String query, {
    required List<OnboardingOption> options,
    List<String> exclude = const [],
  });
}

class LocalSkillSuggestionService implements SkillSuggestionService {
  const LocalSkillSuggestionService();

  String _guessCategory(String text) => guessSkillCategory(text);

  @override
  Future<List<SkillSuggestion>> suggest(
    String query, {
    required List<OnboardingOption> options,
    List<String> exclude = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final q = query.trim().toLowerCase();
    final results = <SkillSuggestion>[];

    for (final o in options) {
      if (isOtherOption(o)) continue;
      if (exclude.contains(o.id) || exclude.contains(o.label)) continue;
      if (q.isNotEmpty && !o.label.toLowerCase().contains(q)) continue;
      results.add(
        SkillSuggestion(
          id: o.id,
          label: o.label,
          categoryId: kSkillToCategorySlug[o.id] ?? _guessCategory(o.label),
        ),
      );
      if (results.length >= kMaxSuggestions) break;
    }

    if (q.isNotEmpty && !results.any((s) => s.label.toLowerCase() == q)) {
      var label = toTitleCase(query.trim());
      if (label.length > kCustomSkillMaxLength) {
        label = label.substring(0, kCustomSkillMaxLength);
      }
      final categoryId = _guessCategory(label);
      final id = CustomSkill(categoryId: categoryId, text: label).encode();
      if (!exclude.contains(id)) {
        results.add(
          SkillSuggestion(
            id: id,
            label: label,
            categoryId: categoryId,
            isCustom: true,
          ),
        );
      }
    }

    return results;
  }
}

class SkillsCard extends StatefulWidget {
  final bool isEditing;
  final String labelSuffix;
  final List<OnboardingOption> options;
  final int maxSkills;
  final List<String> initialSkillIds;
  final bool showAttachFile;
  final Map<String, String>? attachments;
  final Map<String, String>? notes;
  final SkillSuggestionService suggestionService;
  final ValueChanged<List<String>>? onChanged;
  final void Function(String skillId, String note)? onNoteChanged;
  final void Function(String oldId, String newId)? onSkillReplaced;
  final ValueChanged<String>? onSkillRemoved;
  final ValueChanged<String>? onAttachFile;
  final ValueChanged<String>? onRemoveAttachment;

  const SkillsCard({
    super.key,
    required this.isEditing,
    required this.labelSuffix,
    required this.options,
    required this.maxSkills,
    this.initialSkillIds = const [],
    this.showAttachFile = false,
    this.attachments,
    this.notes,
    this.suggestionService = const LocalSkillSuggestionService(),
    this.onChanged,
    this.onNoteChanged,
    this.onSkillReplaced,
    this.onSkillRemoved,
    this.onAttachFile,
    this.onRemoveAttachment,
  });

  factory SkillsCard.toLearn({
    Key? key,
    required bool isEditing,
    List<String> initialSkillIds = const [],
    Map<String, String>? notes,
    SkillSuggestionService suggestionService =
        const LocalSkillSuggestionService(),
    ValueChanged<List<String>>? onChanged,
    void Function(String skillId, String note)? onNoteChanged,
  }) {
    return SkillsCard(
      key: key,
      isEditing: isEditing,
      labelSuffix: 'Learn',
      options: kLearningOptions,
      maxSkills: 3,
      initialSkillIds: initialSkillIds,
      showAttachFile: false,
      notes: notes,
      suggestionService: suggestionService,
      onChanged: onChanged,
      onNoteChanged: onNoteChanged,
    );
  }

  factory SkillsCard.toTeach({
    Key? key,
    required bool isEditing,
    List<String> initialSkillIds = const [],
    Map<String, String>? attachments,
    Map<String, String>? notes,
    SkillSuggestionService suggestionService =
        const LocalSkillSuggestionService(),
    ValueChanged<List<String>>? onChanged,
    void Function(String skillId, String note)? onNoteChanged,
    void Function(String oldId, String newId)? onSkillReplaced,
    ValueChanged<String>? onSkillRemoved,
    ValueChanged<String>? onAttachFile,
    ValueChanged<String>? onRemoveAttachment,
  }) {
    return SkillsCard(
      key: key,
      isEditing: isEditing,
      labelSuffix: 'Teach',
      options: kTeachingOptions,
      maxSkills: 2,
      initialSkillIds: initialSkillIds,
      showAttachFile: true,
      attachments: attachments,
      notes: notes,
      suggestionService: suggestionService,
      onChanged: onChanged,
      onNoteChanged: onNoteChanged,
      onSkillReplaced: onSkillReplaced,
      onSkillRemoved: onSkillRemoved,
      onAttachFile: onAttachFile,
      onRemoveAttachment: onRemoveAttachment,
    );
  }

  @override
  State<SkillsCard> createState() => _SkillsCardState();
}

class _SkillsCardState extends State<SkillsCard> {
  late List<String> _skillIds;
  late List<String> _notes;
  late List<int> _rowUids;
  int _nextUid = 0;
  int? _activeUid;

  String? _resolveAttachmentPath(String skillId) {
    if (widget.attachments == null || widget.attachments!.isEmpty) return null;

    if (widget.attachments!.containsKey(skillId)) {
      return widget.attachments![skillId];
    }

    final matchOpt = widget.options.cast<OnboardingOption?>().firstWhere(
      (o) => o?.id == skillId,
      orElse: () => null,
    );
    if (matchOpt != null && widget.attachments!.containsKey(matchOpt.label)) {
      return widget.attachments![matchOpt.label];
    }

    final custom = CustomSkill.tryParse(skillId);
    if (custom != null && widget.attachments!.containsKey(custom.text)) {
      return widget.attachments![custom.text];
    }

    final normalized = skillId.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    for (final entry in widget.attachments!.entries) {
      if (entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '_') ==
          normalized) {
        return entry.value;
      }
    }

    return null;
  }

  String _resolveNote(String skillId) {
    if (skillId.isEmpty) return '';
    return widget.notes?[skillId] ?? '';
  }

  List<String> _committed(Iterable<String> ids) =>
      ids.where((id) => !isPendingSkillId(id)).toList();

  void _load() {
    _skillIds =
        widget.initialSkillIds
            .map((id) => isPendingSkillId(id) ? '' : id)
            .toList();
    _notes = _skillIds.map(_resolveNote).toList();
    _rowUids = List.generate(_skillIds.length, (_) => _nextUid++);
    _activeUid = null;
  }

  void _emit() {
    widget.onChanged?.call(_committed(_skillIds));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SkillsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEditing && !mapEquals(oldWidget.notes, widget.notes)) {
      _load();
      return;
    }
    if (oldWidget.initialSkillIds != widget.initialSkillIds) {
      final incoming = _committed(widget.initialSkillIds);
      final current = _committed(_skillIds);
      final same =
          incoming.length == current.length &&
          Iterable<int>.generate(
            incoming.length,
          ).every((i) => incoming[i] == current[i]);
      if (!same) _load();
    }
  }

  void _activate(int uid) {
    if (_activeUid == uid) return;
    setState(() => _activeUid = uid);
  }

  void _addSkill() {
    if (_skillIds.length >= widget.maxSkills) return;
    if (_skillIds.contains('')) return;
    setState(() {
      _skillIds.add('');
      _notes.add('');
      _activeUid = _nextUid;
      _rowUids.add(_nextUid++);
    });
  }

  void _removeSkill(int index) {
    final old = _skillIds[index];
    final uid = _rowUids[index];
    setState(() {
      _skillIds.removeAt(index);
      _notes.removeAt(index);
      _rowUids.removeAt(index);
      if (_activeUid == uid) _activeUid = null;
    });
    if (old.isNotEmpty) {
      widget.onSkillRemoved?.call(old);
      widget.onNoteChanged?.call(old, '');
    }
    _emit();
  }

  void _updateSkill(int index, String newId) {
    final old = _skillIds[index];
    final note = _notes[index];
    setState(() {
      _skillIds[index] = newId;
    });
    if (note.isNotEmpty) {
      if (old.isNotEmpty) widget.onNoteChanged?.call(old, '');
      if (newId.isNotEmpty) widget.onNoteChanged?.call(newId, note);
    }
    _emit();
  }

  void _updateNote(int index, String note) {
    _notes[index] = note;
    final id = _skillIds[index];
    if (id.isNotEmpty) widget.onNoteChanged?.call(id, note);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppColors.accentText(context);
    final themeColor = AppColors.elevatedSurface(context);
    final textColor = Theme.of(context).colorScheme.secondary;
    final canAddMore =
        _skillIds.length < widget.maxSkills && !_skillIds.contains('');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 16, color: textColor),
                  children: [
                    const TextSpan(text: 'Skills to '),
                    TextSpan(
                      text: widget.labelSuffix,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isEditing && canAddMore)
                Semantics(
                  container: true,
                  button: true,
                  label: 'Add skill',
                  child: GestureDetector(
                    onTap: _addSkill,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, color: themeColor, size: 16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < _skillIds.length; i++) ...[
            _SkillRow(
              key: ValueKey('skill_row_${_rowUids[i]}'),
              selectedId: _skillIds[i],
              alreadyUsedIds: _skillIds,
              isEditing: widget.isEditing,
              isActive: _activeUid == _rowUids[i],
              accentColor: accentColor,
              options: widget.options,
              labelSuffix: widget.labelSuffix,
              rowLabel: _skillIds.length > 1 ? 'Skill ${i + 1}' : null,
              initialNote: _notes[i],
              suggestionService: widget.suggestionService,
              showAttachFile: widget.showAttachFile,
              attachmentPath: _resolveAttachmentPath(_skillIds[i]),
              onActivate: () => _activate(_rowUids[i]),
              onChanged: (newId) => _updateSkill(i, newId),
              onNoteChanged: (note) => _updateNote(i, note),
              onReplaced: widget.onSkillReplaced,
              onRemove: () => _removeSkill(i),
              onAttachFile:
                  widget.onAttachFile == null
                      ? null
                      : () => widget.onAttachFile!(_skillIds[i]),
              onRemoveAttachment:
                  widget.onRemoveAttachment == null
                      ? null
                      : () => widget.onRemoveAttachment!(_skillIds[i]),
            ),
            if (i != _skillIds.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: textColor.withValues(alpha: 0.12),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SkillRow extends StatefulWidget {
  final String selectedId;
  final List<String> alreadyUsedIds;
  final bool isEditing;
  final bool isActive;
  final Color accentColor;
  final List<OnboardingOption> options;
  final String labelSuffix;
  final String? rowLabel;
  final String initialNote;
  final SkillSuggestionService suggestionService;
  final bool showAttachFile;
  final String? attachmentPath;
  final VoidCallback onActivate;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onNoteChanged;
  final void Function(String oldId, String newId)? onReplaced;
  final VoidCallback onRemove;
  final VoidCallback? onAttachFile;
  final VoidCallback? onRemoveAttachment;

  const _SkillRow({
    super.key,
    required this.selectedId,
    required this.alreadyUsedIds,
    required this.isEditing,
    required this.isActive,
    required this.accentColor,
    required this.options,
    required this.labelSuffix,
    this.rowLabel,
    required this.initialNote,
    required this.suggestionService,
    required this.showAttachFile,
    this.attachmentPath,
    required this.onActivate,
    required this.onChanged,
    required this.onNoteChanged,
    this.onReplaced,
    required this.onRemove,
    this.onAttachFile,
    this.onRemoveAttachment,
  });

  @override
  State<_SkillRow> createState() => _SkillRowState();
}

class _SkillRowState extends State<_SkillRow> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final _focusNode = FocusNode();
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();

  Timer? _debounce;
  int _requestId = 0;
  bool _loading = false;
  List<SkillSuggestion> _suggestions = const [];
  String? _pickedCategoryId;
  String? _pendingOldId;
  String _lastNote = '';
  double _fieldWidth = 0;

  bool get _isLearn => widget.labelSuffix.toLowerCase() == 'learn';

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.initialNote;
    _lastNote = widget.initialNote;
    _noteController.addListener(_onNoteControllerChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlayController.show();
    });
  }

  @override
  void didUpdateWidget(covariant _SkillRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _debounce?.cancel();
      _requestId++;
      _suggestions = const [];
      _loading = false;
    }

    // The cleared row's old skill may have been re-added through another row.
    // Drop the stale pending link so selecting a new skill here cannot take
    // that live skill's proof.
    final pendingOldId = _pendingOldId;
    if (pendingOldId != null &&
        widget.selectedId.isEmpty &&
        widget.alreadyUsedIds.contains(pendingOldId)) {
      _pendingOldId = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _noteController.removeListener(_onNoteControllerChanged);
    _focusNode.dispose();
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteControllerChanged() {
    final text = _noteController.text;
    if (text == _lastNote) return;
    _lastNote = text;
    widget.onNoteChanged(text);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) return;
    widget.onActivate();
    if (_suggestions.isEmpty) {
      _search(_searchController.text);
    }
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _search('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  void _clearQuery() {
    _searchController.clear();
    _focusNode.requestFocus();
    _onQueryChanged('');
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    if (mounted) setState(() => _loading = true);

    List<SkillSuggestion> results;
    try {
      results = await widget.suggestionService.suggest(
        query,
        options: widget.options,
        exclude: widget.alreadyUsedIds,
      );
    } catch (_) {
      results = const [];
    }

    if (!mounted || requestId != _requestId) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  void _select(SkillSuggestion suggestion) {
    _debounce?.cancel();
    _requestId++;
    _focusNode.unfocus();
    _searchController.clear();
    final oldId = _pendingOldId ?? widget.selectedId;
    _pendingOldId = null;
    final newId = suggestion.isCustom ? suggestion.id : suggestion.label;
    setState(() {
      _pickedCategoryId = suggestion.categoryId;
      _suggestions = const [];
      _loading = false;
    });
    widget.onReplaced?.call(oldId, newId);
    widget.onChanged(newId);
  }

  void _changeSelection() {
    final oldId = widget.selectedId;
    _pendingOldId = oldId;
    widget.onActivate();
    setState(() => _pickedCategoryId = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    widget.onReplaced?.call(oldId, '');
    widget.onChanged('');
  }

  String _labelFor(String id) {
    final custom = CustomSkill.tryParse(id);
    if (custom != null) return custom.text;
    for (final o in widget.options) {
      if (o.id == id || o.label == id) return o.label;
    }
    return id;
  }

  String? _categoryIdFor(String id) {
    final custom = CustomSkill.tryParse(id);
    if (custom != null && custom.categoryId.isNotEmpty) {
      return custom.categoryId;
    }
    final mapped = kSkillToCategorySlug[id];
    if (mapped != null) return mapped;
    if (_pickedCategoryId != null) return _pickedCategoryId;
    for (final o in widget.options) {
      if (o.id == id || o.label == id) {
        return kSkillToCategorySlug[o.id] ?? guessSkillCategory(o.label);
      }
    }
    return guessSkillCategory(_labelFor(id));
  }

  String _getDisplayName(String path) {
    final cleanPath = path.split('?').first;
    String rawName = cleanPath.split('/').last;
    if (rawName.startsWith('scaled_')) {
      rawName = rawName.substring('scaled_'.length);
    }
    if (rawName.startsWith('image_picker_')) {
      rawName = rawName.substring('image_picker_'.length);
    }
    rawName = rawName.replaceAll(RegExp(r'_\d{10,}\.'), '.');
    return rawName;
  }

  OutlineInputBorder _border(Color color, double width, double radius) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _buildSuffix(Color dim) {
    final hasText = _searchController.text.isNotEmpty;
    if (!_loading && !hasText) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentText(context),
                ),
              ),
            ),
          if (hasText)
            Semantics(
              container: true,
              button: true,
              label: 'Clear search',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _clearQuery,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.close, size: 18, color: dim),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(Color textColor, Color dim) {
    return SizedBox(
      height: kSkillFieldHeight,
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: widget.isActive,
        enabled: widget.isEditing,
        expands: true,
        minLines: null,
        maxLines: null,
        textAlignVertical: TextAlignVertical.center,
        maxLength: kCustomSkillMaxLength,
        textInputAction: TextInputAction.search,
        onChanged: _onQueryChanged,
        cursorColor: textColor,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search a skill to ${widget.labelSuffix.toLowerCase()}',
          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
          counterText: '',
          prefixIcon: Icon(Icons.search, size: 20, color: dim),
          suffixIcon: _buildSuffix(dim),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          border: _border(dim, 1.5, 28),
          enabledBorder: _border(dim, 1.5, 28),
          disabledBorder: _border(dim, 1.5, 28),
          focusedBorder: _border(widget.accentColor, 1.5, 28),
        ),
      ),
    );
  }

  Widget _buildSelectedPill(Color dim) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        onTap: widget.isEditing ? _changeSelection : null,
        child: Container(
          height: kSkillFieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: dim, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _labelFor(widget.selectedId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dim, fontSize: 16),
                ),
              ),
              if (widget.isEditing)
                Icon(Icons.edit_outlined, size: 18, color: dim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsOverlay(Color textColor) {
    final surface = AppColors.mutedSurface(context);
    final ordered = _suggestions.reversed.toList();
    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.topLeft,
      followerAnchor: Alignment.bottomLeft,
      offset: const Offset(0, -8),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: _fieldWidth,
          child: Material(
            color: surface,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in ordered)
                  InkWell(
                    onTap: () => _select(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.isCustom
                                ? Icons.add_circle_outline
                                : (categoryById(s.categoryId)?.icon ??
                                    Icons.label_outline),
                            size: 20,
                            color: s.isCustom ? widget.accentColor : textColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.isCustom ? 'Add "${s.label}"' : s.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (categoryById(s.categoryId) != null)
                                  Text(
                                    categoryById(s.categoryId)!.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTag(
    ({String id, String label, IconData icon}) category,
    Color textColor,
    Color dim,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: dim),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField(Color textColor) {
    final prompt =
        _isLearn
            ? 'Tell us more about what you want to learn'
            : 'Tell us more about what you can teach';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              prompt,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !widget.isEditing,
            child: TopLabeledField(
              label: 'Add note',
              controller: _noteController,
              maxLines: 3,
              maxLength: kSkillNoteMaxLength,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, left: 4.0),
      child:
          widget.attachmentPath != null && widget.attachmentPath!.isNotEmpty
              ? Container(
                decoration: BoxDecoration(
                  color: AppColors.mutedSurface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.accentColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: widget.onAttachFile,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: widget.accentColor,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                _getDisplayName(widget.attachmentPath!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.accentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onRemoveAttachment,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : GestureDetector(
                onTap: widget.onAttachFile,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: widget.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Attach a file',
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final dim =
        widget.isEditing
            ? textColor.withValues(alpha: 0.7)
            : textColor.withValues(alpha: 0.5);
    final hasSelection = widget.selectedId.isNotEmpty;
    final category =
        hasSelection ? categoryById(_categoryIdFor(widget.selectedId)) : null;
    final showNote =
        hasSelection &&
        (widget.isEditing || _noteController.text.trim().isNotEmpty);
    final showSuggestions =
        !hasSelection &&
        widget.isEditing &&
        widget.isActive &&
        _suggestions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.rowLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              widget.rowLabel!,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OverlayPortal(
                controller: _overlayController,
                overlayChildBuilder:
                    (_) =>
                        showSuggestions
                            ? _buildSuggestionsOverlay(textColor)
                            : const SizedBox.shrink(),
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _fieldWidth = constraints.maxWidth;
                      return hasSelection
                          ? _buildSelectedPill(dim)
                          : _buildSearchField(textColor, dim);
                    },
                  ),
                ),
              ),
            ),
            if (widget.isEditing) ...[
              const SizedBox(width: 12),
              Semantics(
                container: true,
                button: true,
                label: 'Remove skill',
                child: Material(
                  color: Colors.transparent,
                  shape: CircleBorder(
                    side: BorderSide(color: textColor, width: 1.5),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onRemove,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.close, color: textColor, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (category != null) _buildCategoryTag(category, textColor, dim),
        if (showNote) _buildNoteField(textColor),
        if (widget.showAttachFile && widget.isEditing && hasSelection)
          _buildAttachment(),
      ],
    );
  }
}
