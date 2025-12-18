
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_book_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Map<String, dynamic>> _readBooks = [];
  List<Map<String, dynamic>> _favoriteBooks = [];
  bool _isSelectionMode = false;
  final Set<int> _selectedBooks = <int>{};

  @override
  void initState() {
    super.initState();
    _loadAllBooks();
  }

  Future<void> _loadAllBooks() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // --- Defensive Loading for Read Books ---
    final readBooksJson = prefs.getStringList('read_books') ?? [];
    final allReadBooks = readBooksJson.map((bookString) {
      try {
        final book = json.decode(bookString) as Map<String, dynamic>;
        // Ensure book has a valid title to prevent errors
        if (book['title'] != null && (book['title'] as String).isNotEmpty) {
          return book;
        }
      } catch (e) {
        // Ignore books with parsing errors
      }
      return null;
    }).where((book) => book != null).cast<Map<String, dynamic>>().toList();

    // --- Defensive Loading for Favorite Books ---
    final favoriteBookTitles = Set<String>.from(prefs.getStringList('favorite_books') ?? []);
    final favoriteBooksList = allReadBooks
        .where((book) => favoriteBookTitles.contains(book['title']))
        .toList();

    setState(() {
      _readBooks = allReadBooks.reversed.toList();
      _favoriteBooks = favoriteBooksList.reversed.toList();
    });
  }


  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedBooks.clear();
    });
  }

  void _onBookTap(int index, bool isFavoriteList) {
    if (_isSelectionMode && !isFavoriteList) {
      setState(() {
        if (_selectedBooks.contains(index)) {
          _selectedBooks.remove(index);
        } else {
          _selectedBooks.add(index);
        }
      });
    } else {
      final book = isFavoriteList ? _favoriteBooks[index] : _readBooks[index];
      _navigateToBookDetails(book);
    }
  }

  Future<void> _navigateToBookDetails(Map<String, dynamic> book) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('book_title', book['title'] ?? 'Không có tên');
    await prefs.setString('book_author', book['author'] ?? 'Không có tác giả');
    if (book['imagePath'] != null) {
      await prefs.setString('book_imagePath', book['imagePath']);
    } else {
      await prefs.remove('book_imagePath');
    }

    // Await the result of Navigator.push and then reload
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBookScreen()),
    );

    // After returning, reload ALL books to refresh both lists.
    await _loadAllBooks();
  }

  // --- MODIFIED DELETE FUNCTION ---
  Future<void> _deleteSelectedBooks() async {
    if (_selectedBooks.isEmpty) return;

    final bool? confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa ${_selectedBooks.length} cuốn sách?'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa vĩnh viễn các sách đã chọn không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final prefs = await SharedPreferences.getInstance();

      // Identify the titles of the books being deleted
      final titlesToDelete = _selectedBooks
          .map((index) => _readBooks[index]['title'] as String?)
          .where((title) => title != null)
          .toSet();

      // Remove these titles from the favorites list in SharedPreferences
      if (titlesToDelete.isNotEmpty) {
        final favoriteBookTitles = prefs.getStringList('favorite_books') ?? [];
        favoriteBookTitles.removeWhere((favTitle) => titlesToDelete.contains(favTitle));
        await prefs.setStringList('favorite_books', favoriteBookTitles);
      }

      // Proceed with deleting from the main "read_books" list
      final readBooksJson = prefs.getStringList('read_books') ?? [];
      final originalIndicesToDelete = _selectedBooks
          .map((reversedIndex) => (readBooksJson.length - 1) - reversedIndex)
          .toSet();

      final updatedBooksJson = <String>[];
      for (int i = 0; i < readBooksJson.length; i++) {
        if (!originalIndicesToDelete.contains(i)) {
          updatedBooksJson.add(readBooksJson[i]);
        }
      }

      await prefs.setStringList('read_books', updatedBooksJson);

      // Reload all data from scratch and exit selection mode
      await _loadAllBooks();
      _toggleSelectionMode();
    }
  }

  AppBar _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _toggleSelectionMode,
        ),
        title: Text(
          'Đã chọn: ${_selectedBooks.length}',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: _selectedBooks.isNotEmpty ? Colors.red : Colors.grey,
            ),
            onPressed: _deleteSelectedBooks,
          ),
        ],
      );
    } else {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Thư viện",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: _toggleSelectionMode,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadAllBooks,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm sách...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Sách đã đọc"),
              const SizedBox(height: 16),
              _buildBooksList(_readBooks, isFavoriteList: false),
              const SizedBox(height: 24),
              _buildSectionTitle("Sách yêu thích"),
              const SizedBox(height: 16),
              _buildBooksList(_favoriteBooks, isFavoriteList: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBooksList(List<Map<String, dynamic>> books, {required bool isFavoriteList}) {
    if (books.isEmpty) {
      return Container(
        height: isFavoriteList ? 120 : 180,
        decoration: isFavoriteList ? BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(color: Colors.grey[300]!),
        ) : null,
        child: Center(
          child: Text(
            isFavoriteList
                ? "Sách bạn yêu thích sẽ xuất hiện ở đây."
                : "Bạn chưa đọc cuốn sách nào.\nSách bạn đã đọc xong sẽ xuất hiện ở đây.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          final imagePath = book['imagePath'] as String?;
          final title = book['title'] as String? ?? 'Không có tên';
          final isSelected = !isFavoriteList && _selectedBooks.contains(index);

          return GestureDetector(
            onTap: () => _onBookTap(index, isFavoriteList),
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imagePath != null && imagePath.isNotEmpty
                            ? Image.file(
                          File(imagePath),
                          width: 130,
                          height: 170,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 130,
                          height: 170,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book, size: 50, color: Colors.grey),
                        ),
                      ),
                      if (isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}