
import 'package:demo/logic/personal/personal_cubit.dart';
import 'package:demo/presentation/screens/reading_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonalScreen extends StatelessWidget {
  const PersonalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PersonalCubit()..loadSettings(),
      child: const PersonalView(),
    );
  }
}

class PersonalView extends StatelessWidget {
  const PersonalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Cá nhân & Cài đặt",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: BlocBuilder<PersonalCubit, PersonalState>(
        builder: (context, state) {
          if (state is PersonalLoading || state is PersonalInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PersonalLoaded) {
            return _buildSettingsList(context, state);
          }
          return const Center(child: Text('Không thể tải cài đặt.'));
        },
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, PersonalLoaded state) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      children: [
        // User Info Section (static for now)
        const Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
            ),
            SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Người dùng",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Cài đặt và tùy chọn",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Divider(),
        const Text(
          'Cài đặt đọc',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        SwitchListTile(
          title: const Text('Tự động đọc'),
          subtitle: const Text('Tự động đọc văn bản mới nhận được'),
          value: state.autoRead,
          onChanged: (bool value) {
            context.read<PersonalCubit>().setAutoRead(value);
          },
        ),
        ListTile(
          title: const Text('Ngôn ngữ đọc'),
          subtitle: Text(state.readLanguage == 'vi-VN' ? 'Tiếng Việt' : 'Tiếng Anh'),
          onTap: () {
            // Show a dialog to change language
            _showLanguageDialog(context, state.readLanguage);
          },
        ),
        const Divider(),
        const Text(
          'Lịch sử',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        ListTile(
          leading: const Icon(Icons.history, color: Colors.black54),
          title: const Text(
            'Lịch sử đọc sách',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReadingHistoryScreen(),
              ),
            );
          },
        ),
        const Divider(),
        const Text(
          'Tài khoản',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        _buildMenuItem(Icons.logout, "Đăng xuất", isLogout: true),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context, String currentLanguage) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Chọn ngôn ngữ đọc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Tiếng Việt'),
                value: 'vi-VN',
                groupValue: currentLanguage,
                onChanged: (String? value) {
                  if (value != null) {
                    context.read<PersonalCubit>().setReadLanguage(value);
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Tiếng Anh'),
                value: 'en-US',
                groupValue: currentLanguage,
                onChanged: (String? value) {
                  if (value != null) {
                    context.read<PersonalCubit>().setReadLanguage(value);
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: isLogout ? Colors.red : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Handle tap
      },
    );
  }
}
