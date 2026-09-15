import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'home_page.dart';
import 'explore_page.dart';
import 'chats_page.dart';
import 'profile_page.dart';

class NavigationBarWidget extends StatefulWidget {
  const NavigationBarWidget({super.key});

  @override
  State<NavigationBarWidget> createState() => _NavigationBarWidgetState();
}

class _NavigationBarWidgetState extends State<NavigationBarWidget> {
  int _selectedIndex = 0;

  // 1. Keep this list as your outlined/unselected icons
  final List<IconData> _navigationIcons = [
    CupertinoIcons.home,
    CupertinoIcons.compass,
    CupertinoIcons.chat_bubble,
    CupertinoIcons.person,
  ];

  final List<IconData> _selectedIcons = [
    CupertinoIcons.house_fill,   
    CupertinoIcons.compass_fill,     
    CupertinoIcons.chat_bubble_fill, 
    CupertinoIcons.person_fill,     
  ];

  final List<String> _navigationLabels = [
    'Home',
    'Explore',
    'Chats',
    'Profile',
  ];

  final List<Widget> _pages = [
    const HomePage(),
    const ExplorePage(),
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
      margin: const EdgeInsets.only(right: 16, left: 16, bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).scaffoldBackgroundColor,
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
          final activeColor = Theme.of(context).primaryColor;
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
                // 3. Conditionally swap out the IconData depending on selection state
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
