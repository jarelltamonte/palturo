import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';

import 'home_page.dart';
import 'explore_page.dart';
import 'chats_page.dart';
import 'profile_page.dart';
import 'request_page.dart';

class NavigationBarWidget extends StatefulWidget {
  const NavigationBarWidget({super.key});

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget> {
  int _selectedIndex = 0;

  final List<IconData> _navigationIcons = [
    CupertinoIcons.home,
    CupertinoIcons.compass,
    CupertinoIcons.heart,
    CupertinoIcons.chat_bubble,
    CupertinoIcons.person,
  ];

  final List<IconData> _selectedIcons = [
    CupertinoIcons.house_fill,   
    CupertinoIcons.compass_fill,  
    CupertinoIcons.heart_fill,   
    CupertinoIcons.chat_bubble_fill, 
    CupertinoIcons.person_fill,     
  ];

  final List<String> _navigationLabels = [
    'Home',
    'Explore',
    'Requests',
    'Chats',
    'Profile',
  ];

  final List<Widget> _pages = [
    const HomePage(),
    const ExplorePage(),
    const RequestPage(),
    const ChatsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(right: 16, left: 16, bottom: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navigationIcons.length, (index) {
          final isSelected = _selectedIndex == index;
          final activeColor = AppColors.primary;
          final inactiveColor = Colors.grey;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? _selectedIcons[index] : _navigationIcons[index],
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  _navigationLabels[index],
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
