import 'package:flutter/material.dart';
import 'settings_model.dart';

class PrivacyPolicyPage extends StatelessWidget {
  final SettingsModel settings;
  final String wallpaper;

  const PrivacyPolicyPage({
    super.key,
    required this.settings,
    required this.wallpaper,
  });

  @override
  Widget build(BuildContext context) {
    final isEnglish = settings.currentLanguage == 'en';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/wallpaper/$wallpaper'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEnglish ? 'Privacy Policy' : 'Gizlilik Politikası',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          title: isEnglish
                              ? 'What Data We Collect'
                              : 'Hangi Verileri Topluyoruz',
                          content: isEnglish
                              ? 'We collect only the following data to provide synchronization between your phone and watch:\n\n• Pomodoro session duration (minutes)\n• Session date and time\n• Device type (phone or watch)\n• Anonymous user ID (generated automatically)'
                              : 'Telefon ve saatiniz arasında senkronizasyon sağlamak için sadece şu verileri topluyoruz:\n\n• Pomodoro oturum süresi (dakika)\n• Oturum tarihi ve saati\n• Cihaz tipi (telefon veya saat)\n• Anonim kullanıcı kimliği (otomatik oluşturulur)',
                        ),
                        const SizedBox(height: 20),

                        _buildSection(
                          title: isEnglish
                              ? 'How We Use Your Data'
                              : 'Verilerinizi Nasıl Kullanıyoruz',
                          content: isEnglish
                              ? 'Your data is used ONLY for:\n\n• Synchronizing your Pomodoro statistics between devices\n• Displaying your work statistics\n• Nothing else!\n\nWe do NOT:\n• Sell your data\n• Share your data with third parties\n• Use your data for advertising\n• Track your personal information'
                              : 'Verileriniz SADECE şunlar için kullanılır:\n\n• Cihazlarınız arasında Pomodoro istatistiklerinizi senkronize etmek\n• Çalışma istatistiklerinizi görüntülemek\n• Başka hiçbir şey!\n\nAsla:\n• Verilerinizi satmayız\n• Üçüncü taraflarla paylaşmayız\n• Reklam için kullanmayız\n• Kişisel bilgilerinizi takip etmeyiz',
                        ),
                        const SizedBox(height: 20),

                        _buildSection(
                          title: isEnglish ? 'Data Security' : 'Veri Güvenliği',
                          content: isEnglish
                              ? 'Your data is:\n\n• Stored securely on our server\n• Encrypted during transmission\n• Anonymous (no personal information)\n• Only accessible by you through your unique user ID'
                              : 'Verileriniz:\n\n• Sunucumuzda güvenli şekilde saklanır\n• İletim sırasında şifrelenir\n• Anonimdir (kişisel bilgi içermez)\n• Sadece benzersiz kullanıcı kimliğiniz ile size erişilebilir',
                        ),
                        const SizedBox(height: 20),

                        _buildSection(
                          title: isEnglish ? 'Data Deletion' : 'Veri Silme',
                          content: isEnglish
                              ? 'Your data is stored for statistical purposes only. If you uninstall the app:\n\n• Local data on your device will be automatically deleted\n• Server data will remain for synchronization if you reinstall\n• To permanently delete all data, contact us at: nmustafa.ozkaya@gmail.com'
                              : 'Verileriniz sadece istatistik amaçlı saklanır. Uygulamayı kaldırırsanız:\n\n• Cihazdaki lokal veriler otomatik silinir\n• Sunucu verileri yeniden yükleme için kalır\n• Tüm verileri kalıcı olarak silmek için bize ulaşın: nmustafa.ozkaya@gmail.com',
                        ),
                        const SizedBox(height: 20),

                        _buildSection(
                          title: isEnglish ? '📧 Contact Us' : '📧 İletişim',
                          content: isEnglish
                              ? 'If you have any questions about this Privacy Policy, please contact us:\n\nEmail: nmustafa.ozkaya@gmail.com\nDeveloper: NMO Dev'
                              : 'Bu Gizlilik Politikası hakkında sorularınız varsa lütfen bize ulaşın:\n\nE-posta: nmustafa.ozkaya@gmail.com\nGeliştirici: NMO Dev',
                        ),
                        const SizedBox(height: 20),

                        Center(
                          child: Text(
                            isEnglish
                                ? 'Last Updated: January 2026'
                                : 'Son Güncelleme: Ocak 2026',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
