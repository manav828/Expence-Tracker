import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/split_provider.dart';
import '../../services/auth_service.dart';
import 'group_banner_picker_sheet.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _creatorCtrl = TextEditingController();
  final List<TextEditingController> _memberCtrls = [TextEditingController()];
  String? _customBannerUrl;
  bool _isLoading = false;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = context.read<SplitProvider>().currentMemberName ?? AuthService.instance.userDisplayName;
      if (name.trim().isNotEmpty) {
        _creatorCtrl.text = name;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _creatorCtrl.dispose();
    for (final c in _memberCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final creatorName = _creatorCtrl.text.trim();
    final memberNames = _memberCtrls
        .map((c) => c.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    // Prevent member having the exact same name as creator
    if (memberNames.any((m) => m.toLowerCase() == creatorName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member name cannot be the same as your name (you are already in the group).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prevent duplicate member names
    final lowerSet = <String>{};
    for (final m in memberNames) {
      if (!lowerSet.add(m.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicate member name "$m". Each member must have a distinct name.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final sp = context.read<SplitProvider>();
      await sp.setCurrentMemberName(creatorName);
      final group = await sp.createGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        imageUrl: _customBannerUrl,
        createdByName: creatorName,
        memberNames: memberNames,
      );
      if (mounted) {
        Navigator.pop(context, group);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "${group.name}" created! Invite code: ${group.inviteCode}'),
            backgroundColor: _primaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _buildCoverSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cover Photo / Banner',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF131B2E)),
            ),
            if (_customBannerUrl != null)
              TextButton(
                onPressed: () => setState(() => _customBannerUrl = null),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reset to Auto', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final chosen = await showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => GroupBannerPickerSheet(
                initialUrl: _customBannerUrl,
                suggestedKeyword: _nameCtrl.text.trim(),
              ),
            );
            if (chosen != null && chosen.isNotEmpty) {
              setState(() => _customBannerUrl = chosen);
            }
          },
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _customBannerUrl != null ? _primaryColor.withValues(alpha: 0.5) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              color: Colors.white,
            ),
            child: _customBannerUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          _customBannerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text('Change Banner', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_photo_alternate_outlined, color: _primaryColor, size: 24),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add Cover / Banner Photo',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryColor),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Presets, Pixabay search, or Cloudflare storage',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Create Split Group',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF131B2E),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0x0D000000)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(title: 'Group Info', icon: Icons.group),
            const SizedBox(height: 12),
            _InputField(
              controller: _nameCtrl,
              label: 'Group Name',
              hint: 'e.g. Goa Trip 2024',
              icon: Icons.groups_outlined,
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter group name' : null,
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: _descCtrl,
              label: 'Description (optional)',
              hint: 'e.g. Beach trip expenses',
              icon: Icons.notes_outlined,
            ),
            const SizedBox(height: 14),
            _buildCoverSelector(),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Your Name', icon: Icons.person),
            const SizedBox(height: 4),
            const Text('This is how you appear in the group.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6D7A72))),
            const SizedBox(height: 12),
            _InputField(
              controller: _creatorCtrl,
              label: 'Your Name',
              hint: 'e.g. Manav',
              icon: Icons.person_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader(title: 'Members', icon: Icons.people_outline),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _memberCtrls.add(TextEditingController()));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Member'),
                  style: TextButton.styleFrom(foregroundColor: _primaryColor),
                ),
              ],
            ),
            const Text('Add other people. They can also join later via invite code.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6D7A72))),
            const SizedBox(height: 12),
            ..._memberCtrls.asMap().entries.map((entry) {
              return Padding(
                key: ObjectKey(entry.value),
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        key: ValueKey('member_field_${entry.value.hashCode}'),
                        controller: entry.value,
                        label: 'Member ${entry.key + 1} Name',
                        hint: entry.key == 0 ? 'e.g. Rahul' : 'e.g. Priya',
                        icon: Icons.person_outline,
                        enableAutofill: false,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (v.trim().toLowerCase() == _creatorCtrl.text.trim().toLowerCase()) {
                              return 'Cannot be same as your name';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_memberCtrls.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          entry.value.dispose();
                          setState(() => _memberCtrls.removeAt(entry.key));
                        },
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFF006948)),
    const SizedBox(width: 6),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
  ]);
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool enableAutofill;

  const _InputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.enableAutofill = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    autofillHints: enableAutofill ? const [AutofillHints.name] : null,
    enableSuggestions: enableAutofill,
    autocorrect: false,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6D7A72)),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF006948), width: 1.5)),
    ),
  );
}
