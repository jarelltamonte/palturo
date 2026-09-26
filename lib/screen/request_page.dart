import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_text_styles.dart';

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  String _selectedSort = 'Newest first';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Text(
              'Requests',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  _selectedSort = value;
                });
              },
              offset: const Offset(0, 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              itemBuilder:
                  (context) => [
                    PopupMenuItem<String>(
                      value: 'Newest first',
                      child: _buildSortOption(
                        'Newest first',
                        textTheme,
                        primaryColor,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'Oldest first',
                      child: _buildSortOption(
                        'Oldest first',
                        textTheme,
                        primaryColor,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'Alphabetically (A–Z)',
                      child: _buildSortOption(
                        'Alphabetically (A–Z)',
                        textTheme,
                        primaryColor,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'Alphabetically (Z–A)',
                      child: _buildSortOption(
                        'Alphabetically (Z–A)',
                        textTheme,
                        primaryColor,
                      ),
                    ),
                  ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 20, color: textTheme),
                  const SizedBox(width: 6),
                  Text(
                    'Sort by',
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          children: [
            Text(
              'They want to connect with you. Like back to start exchanging skills right away!',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _buildRequestCard(context, textTheme, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String option, Color textTheme, Color primaryColor) {
    final isSelected = _selectedSort == option;

    return Row(
      children: [
        SizedBox(
          width: 20,
          child:
              isSelected
                  ? Icon(Icons.check, size: 18, color: primaryColor)
                  : null,
        ),
        const SizedBox(width: 8),
        Text(
          option,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    Color textTheme,
    Color primaryColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/rlearner.svg',
                width: 22,
                height: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Seeking a learner in',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Parol Making',
            style: AppTextStyles.boldText.copyWith(
              color: primaryColor,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8E8E8),
                ),
                child: const Icon(Icons.person, size: 28, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RJ',
                      style: AppTextStyles.boldText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: textTheme,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mon/Wed/Sat',
                          style: AppTextStyles.regularText.copyWith(
                            color: textTheme,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.translate, size: 13, color: textTheme),
                        const SizedBox(width: 4),
                        Text(
                          'English',
                          style: AppTextStyles.regularText.copyWith(
                            color: textTheme,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Accept',
                    style: AppTextStyles.regularText.copyWith(
                      color: primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Container(width: 2, height: 40, color: Colors.black),
              Expanded(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Decline',
                    style: AppTextStyles.regularText.copyWith(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
