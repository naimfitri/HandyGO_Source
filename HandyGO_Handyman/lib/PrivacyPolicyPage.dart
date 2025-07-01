import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: const Text('', style: TextStyle(color: Colors.white)), // Removed title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPolicyHeader(),
            _buildPolicySection(
              title: 'Introduction',
              content: 'This Privacy Policy outlines how we collect, use, store, and protect your personal information when you use our handyman service app. We respect your privacy and are committed to protecting your personal data. Please read this policy carefully to understand our practices regarding your personal information.',
            ),
            _buildPolicySection(
              title: 'Information We Collect',
              content: 'We collect several types of information from and about users of our app, including:',
              bulletPoints: [
                'Personal information such as name, email address, phone number, and address',
                'Professional information such as job category, skills, and work experience',
                'Banking details for payment processing',
                'Profile images and other uploaded content',
                'Location data when you are online and available for jobs',
                'Device information and app usage statistics'
              ],
            ),
            _buildPolicySection(
              title: 'How We Use Your Information',
              content: 'We use the information we collect to:',
              bulletPoints: [
                'Create and manage your handyman account',
                'Connect you with customers seeking your services',
                'Process payments and manage your earnings',
                'Improve our app features and user experience',
                'Provide customer support and respond to your inquiries',
                'Send you important notifications about bookings and account updates',
                'Ensure the security of our platform and prevent fraud'
              ],
            ),
            _buildPolicySection(
              title: 'Location Services',
              content: 'Our app uses location services to:',
              bulletPoints: [
                'Show your real-time location to customers when you are online',
                'Calculate travel distances and estimated arrival times',
                'Match you with nearby job opportunities',
                'Location tracking is only active when you set your status to online'
              ],
              isHighlighted: true,
            ),
            _buildPolicySection(
              title: 'Data Storage and Security',
              content: 'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, disclosure, or destruction. Your data is stored on secure servers and we use encryption technologies for sensitive data transmission. We retain your personal data only for as long as necessary to fulfill the purposes for which we collected it.',
            ),
            _buildPolicySection(
              title: 'Third-Party Services',
              content: 'Our app integrates with third-party services for certain functionalities:',
              bulletPoints: [
                'Payment processing services to handle transactions',
                'Cloud storage providers for storing your profile information and images',
                'Location and mapping services for navigation assistance',
                'Authentication services for account security'
              ],
            ),
            _buildPolicySection(
              title: 'Your Rights and Choices',
              content: 'You have several rights regarding your personal data:',
              bulletPoints: [
                'Access and update your personal information through your profile',
                'Request deletion of your account and associated data',
                'Opt out of marketing communications',
                'Turn location tracking on or off by changing your online status',
                'Request information about what data we hold about you'
              ],
            ),
            _buildPolicySection(
              title: 'Contact Us',
              content: 'If you have questions or concerns about this Privacy Policy or our data practices, please contact us:',
              contactInfo: true,
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Last Updated: May 6, 2024',
                style: TextStyle(
                  color: AppTheme.textBodyColor,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center( // Added Center widget here to center all elements
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.blueTintBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppTheme.primaryColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Privacy Policy',
              textAlign: TextAlign.center, // Ensure text is centered
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textHeadingColor,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Protecting your privacy is important to us',
              textAlign: TextAlign.center, // Ensure text is centered
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textBodyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({
    required String title,
    required String content,
    List<String>? bulletPoints,
    bool contactInfo = false,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.blueTintBackground : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: isHighlighted ? 0 : -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_outlined, color: AppTheme.primaryColor, size: 20),
                ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? AppTheme.primaryColor : AppTheme.textHeadingColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textBodyColor,
              height: 1.6,
            ),
          ),
          if (bulletPoints != null) ...[
            const SizedBox(height: 16),
            ...bulletPoints.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 4),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      color: isHighlighted ? AppTheme.primaryColor : AppTheme.secondaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textBodyColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (contactInfo) ...[
            const SizedBox(height: 20),
            _buildContactInfo(
              icon: Icons.email_outlined,
              title: 'Email',
              value: 'privacy@handymanapp.com',
            ),
            const SizedBox(height: 16),
            _buildContactInfo(
              icon: Icons.phone_outlined,
              title: 'Phone',
              value: '+60 3 1234 5678',
            ),
            const SizedBox(height: 16),
            _buildContactInfo(
              icon: Icons.location_on_outlined,
              title: 'Address',
              value: 'Tower A, ABC Business Center, Kuala Lumpur, Malaysia',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.blueTintBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textHeadingColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textBodyColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Theme colors class
class AppTheme {
  static const Color primaryColor = Color(0xFF3F51B5); // Royal Blue
  static const Color secondaryColor = Color(0xFF9C27B0); // Vibrant Violet
  static const Color backgroundColor = Color(0xFFFAFAFF); // Ghost White
  static const Color textHeadingColor = Color(0xFF2E2E2E); // Dark Slate Gray
  static const Color textBodyColor = Color(0xFF6E6E6E); // Slate Grey
  static const Color successColor = Color(0xFF4CAF50); // Spring Green
  static const Color warningColor = Color(0xFFFF7043); // Coral
  static const Color blueTintBackground = Color(0xFFE3F2FD); // Blue-tint background
  static const Color purpleTintBackground = Color(0xFFF3E5F5); // Purple-tint background
}