import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/split_provider.dart';

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
  bool _isLoading = false;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = context.read<SplitProvider>().currentMemberName;
      if (name != null) _creatorCtrl.text = name;
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
    setState(() => _isLoading = true);
    try {
      final sp = context.read<SplitProvider>();
      await sp.setCurrentMemberName(_creatorCtrl.text.trim());
      final memberNames = _memberCtrls
          .map((c) => c.text.trim())
          .where((n) => n.isNotEmpty)
          .toList();
      final group = await sp.createGroup(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        createdByName: _creatorCtrl.text.trim(),
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: entry.value,
                        label: 'Member ${entry.key + 1} Name',
                        hint: 'e.g. Priya',
                        icon: Icons.person_outline,
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
  const _InputField({required this.controller, required this.label,
    required this.hint, required this.icon, this.validator});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
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
