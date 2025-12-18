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
      type: BottomNavigationBarType.fixed, // Đảm bảo 3 mục luôn cố định
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.book_outlined), // Icon viền
          activeIcon: Icon(Icons.book), // Icon đậm khi được chọn
          label: 'Thư viện',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined), // Icon viền
          activeIcon: Icon(Icons.add_box), // Icon đậm khi được chọn
          label: 'Thêm mới',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline), // Icon viền
          activeIcon: Icon(Icons.person), // Icon đậm khi được chọn
          label: 'Cá nhân',
        ),
      ],
    );
  }
}