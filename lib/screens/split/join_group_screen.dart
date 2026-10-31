import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/split_provider.dart';
import '../../services/auth_service.dart';
import 'split_group_detail_screen.dart';

class JoinGroupScreen extends StatefulWidget {
  final String? prefilledCode;
  const JoinGroupScreen({super.key, this.prefilledCode});
  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  late final TextEditingController _codeCtrl;
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  static const _secondaryColor = Color(0xFF4B41E1);

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.prefilledCode ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = context.read<SplitProvider>().currentMemberName;
      if (name != null && name.trim().isNotEmpty) {
        _nameCtrl.text = name;
      } else {
        final authName = AuthService.instance.userDisplayName;
        if (authName.trim().isNotEmpty) {
          _nameCtrl.text = authName.trim();
        }
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter invite code and your name')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final sp = context.read<SplitProvider>();
      await sp.setCurrentMemberName(name);
      final group = await sp.joinGroupByInviteCode(code, name);
      if (mounted) {
        if (group == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group not found. Check the invite code.'), backgroundColor: Colors.red),
          );
        } else {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => SplitGroupDetailScreen(group: group)));
        }
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
        title: const Text('Join Split Group', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF131B2E),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0x0D000000)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B41E1), Color(0xFF645EFB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Got an invite code?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Enter the 8-character code shared by your group creator.',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Invite Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF131B2E))),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 20),
              decoration: InputDecoration(
                hintText: 'e.g. A1B2C3D4',
                hintStyle: const TextStyle(fontWeight: FontWeight.normal, letterSpacing: 2, fontSize: 16),
                prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF4B41E1)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4B41E1), width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Your Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF131B2E))),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'How should the group see you?',
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4B41E1)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4B41E1), width: 1.5)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Join Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
