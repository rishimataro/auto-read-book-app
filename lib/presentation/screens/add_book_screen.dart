import 'dart:io';
import 'package:demo/logic/add_book/add_book_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddBookScreen extends StatelessWidget {
  final Map<String, dynamic>? bookToEdit;
  final VoidCallback? onSaveSuccess;

  const AddBookScreen({super.key, this.bookToEdit, this.onSaveSuccess});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddBookCubit()
        .._init(bookToEdit),
      child: AddBookView(onSaveSuccess: onSaveSuccess),
    );
  }
}

extension on AddBookCubit {
  void _init(Map<String, dynamic>? book) {
    if (book != null) {
      loadBookForEditing(book);
    } else {
      createNewBook();
    }
  }
}

class AddBookView extends StatelessWidget {
  final VoidCallback? onSaveSuccess;
  
  const AddBookView({super.key, this.onSaveSuccess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.read<AddBookCubit>().isEditing ? 'Chỉnh sửa sách' : 'Thêm sách mới'),
        backgroundColor: const Color(0xFF426A80),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<AddBookCubit, AddBookState>(
        listener: (context, state) {
          if (state is AddBookSuccess) {
            // Hiển thị thông báo thành công
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Lưu sách thành công!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            
            // Gọi callback nếu có (để chuyển tab trong HomeScreen)
            if (onSaveSuccess != null) {
              // Chuyển sang tab Library ngay lập tức
              Future.delayed(const Duration(milliseconds: 500), () {
                onSaveSuccess!();
              });
            } else {
              // Nếu không có callback, pop về màn hình trước (khi mở từ LibraryScreen)
              Future.delayed(const Duration(milliseconds: 800), () {
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              });
            }
          }
          if (state is AddBookFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
          }
        },
        builder: (context, state) {
          return _buildForm(context, state);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, AddBookState state) {
    final cubit = context.read<AddBookCubit>();
    final isSaving = state is AddBookSaving;
    String? imagePath;
    if (state is AddBookForm) {
      imagePath = state.imagePath;
    } else if (state is AddBookFailure) {
      imagePath = state.imagePath;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image picker section
          Center(
            child: GestureDetector(
              onTap: isSaving ? null : () => cubit.pickImage(),
              child: Container(
                height: 220,
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(
                    color: Colors.grey[400]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imagePath != null
                      ? Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                          },
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Thêm ảnh bìa',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Title field
          TextField(
            controller: cubit.titleController,
            enabled: !isSaving,
            decoration: InputDecoration(
              labelText: 'Tên sách *',
              hintText: 'Nhập tên sách',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 20),
          
          // Author field
          TextField(
            controller: cubit.authorController,
            enabled: !isSaving,
            decoration: InputDecoration(
              labelText: 'Tác giả',
              hintText: 'Nhập tên tác giả',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 20),
          
          // Description field
          TextField(
            controller: cubit.descriptionController,
            enabled: !isSaving,
            decoration: InputDecoration(
              labelText: 'Mô tả (tùy chọn)',
              hintText: 'Nhập mô tả về cuốn sách',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(Icons.description),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 40),
          
          // Save button
          ElevatedButton(
            onPressed: isSaving
                ? null
                : () {
                    // Validate before saving
                    if (cubit.titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.white),
                              SizedBox(width: 10),
                              Text('Vui lòng nhập tên sách'),
                            ],
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    cubit.saveBook();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF426A80),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSaving) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  isSaving ? 'Đang lưu...' : 'Lưu sách',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

}
