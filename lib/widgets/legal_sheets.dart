import 'package:flutter/material.dart';

class LegalSheets {
  static void showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildLegalModal(
        context: context,
        title: 'Privacy Policy',
        lastUpdated: 'October 2026',
        sections: [
          _LegalSection(
            title: '1. Hybrid Data Storage & Privacy',
            content:
                'ExpenCircle gives you complete control over your data. When you select Local Storage mode, 100% of your financial transactions remain exclusively on your device in secure local storage. In Cloud Storage mode, your data is securely stored with encrypted cloud backup to enable cross-device sync and restore.',
          ),
          _LegalSection(
            title: '2. On-Device SMS Transaction Parsing',
            content:
                'SMS permissions are used strictly on-device to detect and parse financial debit/credit alerts from verified banks. Your raw SMS messages are NEVER transmitted to external servers, uploaded, sold, or shared with third parties.',
          ),
          _LegalSection(
            title: '3. Group Bill Sharing (Splitwise)',
            content:
                'Shared group bills, member names, and settlement balances are shared only with members who possess the specific group invite code or link. Personal expenses outside of groups remain completely confidential.',
          ),
          _LegalSection(
            title: '4. Zero Advertising & No Data Selling',
            content:
                'We do not sell, rent, monetize, or broker your personal or financial data to advertising networks, marketers, or data brokers. Your financial records belong solely to you.',
          ),
          _LegalSection(
            title: '5. Data Deletion & Export',
            content:
                'You may export your complete financial records as CSV or JSON at any time. You can also wipe your local records or delete your cloud account instantly from the app settings.',
          ),
        ],
      ),
    );
  }

  static void showTermsOfService(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildLegalModal(
        context: context,
        title: 'Terms of Service',
        lastUpdated: 'October 2026',
        sections: [
          _LegalSection(
            title: '1. Acceptance of Terms',
            content:
                'By accessing or using ExpenCircle, you agree to these Terms of Service. If you do not agree, you can discontinue use or utilize the app in guest offline mode.',
          ),
          _LegalSection(
            title: '2. Nature of the Application',
            content:
                'ExpenCircle is a personal bookkeeping and informal group split utility. It is not a bank, certified financial advisor, tax consultant, or debt-collection agency.',
          ),
          _LegalSection(
            title: '3. Group Splitting & Debt Settlements',
            content:
                'The application provides mathematical balance calculations and settlement logs for shared expenses. All monetary exchanges and debt settlements are private agreements between group members.',
          ),
          _LegalSection(
            title: '4. Account Security',
            content:
                'You are responsible for maintaining the confidentiality of your device and login credentials. You are responsible for all activity under your authenticated session.',
          ),
          _LegalSection(
            title: '5. Limitation of Liability',
            content:
                'ExpenCircle is provided "as is". While we strive for 100% precision in currency and calculations, we are not liable for any discrepancies resulting from device issues or third-party bank notification formats.',
          ),
        ],
      ),
    );
  }

  static Widget _buildLegalModal({
    required BuildContext context,
    required String title,
    required String lastUpdated,
    required List<_LegalSection> sections,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    Text(
                      'Effective: $lastUpdated',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22, color: Color(0xFF3D4A42)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F1F6)),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(22),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, idx) {
                final s = sections[idx];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF006948),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.content,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF3D4A42),
                        height: 1.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006948),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('I Understand & Agree', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String content;
  const _LegalSection({required this.title, required this.content});
}
