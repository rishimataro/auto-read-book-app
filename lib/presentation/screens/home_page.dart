import 'package:demo/logic/connection/connection_cubit.dart';
import 'package:demo/logic/connection/connection_state.dart';
import 'package:demo/logic/home/home_cubit.dart';
import 'package:demo/presentation/screens/connection_screen.dart';
import 'package:demo/presentation/screens/read_book_screen.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToLibrary;
  
  const HomePage({super.key, this.onNavigateToLibrary});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    final isConnected =
        context.read<ConnectionCubit>().state is ConnectionEstablished;
    context.read<HomeCubit>().loadHomeData(isConnected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          BlocBuilder<ConnectionCubit, ConnectionState>(
            builder: (context, state) {
              final isConnected = state is ConnectionEstablished;
              return Row(
                children: [
                  Text(isConnected ? 'Online' : 'Offline'),
                  Icon(
                    Icons.circle,
                    color: isConnected ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 16),
                ],
              );
            },
          )
        ],
      ),
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HomeLoaded) {
            return _buildHomeContent(context, state);
          }
          return const Center(child: Text('Chào mừng!'));
        },
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, HomeLoaded state) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng quan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (state.lastReadBook != null) ...[
            const Text(
              'Sách đang đọc gần nhất',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: state.lastReadBook!['imagePath'] != null
                    ? Image.file(File(state.lastReadBook!['imagePath']))
                    : const Icon(Icons.book),
                title: Text(state.lastReadBook!['title']),
                subtitle: Text(state.lastReadBook!['author']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReadBookScreen(
                        title: state.lastReadBook!['title'],
                        author: state.lastReadBook!['author'],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
          const Text(
            'Truy cập nhanh',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: state.lastReadBook != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReadBookScreen(
                              title: state.lastReadBook!['title'],
                              author: state.lastReadBook!['author'],
                            ),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu đọc'),
              ),
              ElevatedButton.icon(
                onPressed: widget.onNavigateToLibrary,
                icon: const Icon(Icons.library_books),
                label: const Text('Thư viện'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConnectionScreen()),
                  );
                },
                icon: const Icon(Icons.wifi),
                label: const Text('Kết nối Pi'),
              ),
            ],
          )
        ],
      ),
    );
  }
}

