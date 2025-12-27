import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: const Color(0xFF9C7350), // Màu nâu khi chọn
      unselectedItemColor: Colors.black54, // Màu xám cho icon chưa chọn
      showSelectedLabels: true, // Hiển thị nhãn khi chọn
      showUnselectedLabels: true, // Vẫn hiển thị nhãn khi không chọn
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined),
          activeIcon: Icon(Icons.book),
          label: 'Thư viện',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined),
          activeIcon: Icon(Icons.add_box),
          label: 'Thêm mới',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.person),
          label: 'Cài đặt',
        ),
      ],
    );
  }
}