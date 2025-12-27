import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_book_screen.dart';
import 'read_book_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
  
  static _LibraryScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<_LibraryScreenState>();
  }
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Map<String, dynamic>> _allBooks = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  List<Map<String, dynamic>> _favoriteBooks = [];
  bool _isSelectionMode = false;
  final Set<int> _selectedBooks = <int>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllBooks();
    _searchController.addListener(_filterBooks);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh khi tab được hiển thị lại
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllBooks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBooks = _allBooks.where((book) {
        final title = book['title']?.toLowerCase() ?? '';
        final author = book['author']?.toLowerCase() ?? '';
        return title.contains(query) || author.contains(query);
      }).toList();
    });
  }

  Future<void> _loadAllBooks() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final readBooksJson = prefs.getStringList('read_books') ?? [];
    final allReadBooks = readBooksJson.map((bookString) {
      try {
        final book = json.decode(bookString) as Map<String, dynamic>;
        if (book['title'] != null && (book['title'] as String).isNotEmpty) {
          return book;
        }
      } catch (e) {
        // Ignore errors
      }
      return null;
    }).where((book) => book != null).cast<Map<String, dynamic>>().toList();

    final favoriteBookTitles = Set<String>.from(prefs.getStringList('favorite_books') ?? []);
    final favoriteBooksList = allReadBooks
        .where((book) => favoriteBookTitles.contains(book['title']))
        .toList();

    if (mounted) {
    setState(() {
      _allBooks = allReadBooks.reversed.toList();
      _filteredBooks = _allBooks;
      _favoriteBooks = favoriteBooksList.reversed.toList();
    });
    }
  }

  // Public method để refresh từ bên ngoài
  void refreshBooks() {
    _loadAllBooks();
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
      final book = isFavoriteList ? _favoriteBooks[index] : _filteredBooks[index];
      _navigateToBookDetails(book);
    }
  }

  Future<void> _navigateToBookDetails(Map<String, dynamic> book) async {
    // Navigate to read book screen or edit screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReadBookScreen(
          title: book['title'] ?? 'Không có tên',
          author: book['author'] ?? 'Không có tác giả',
        ),
      ),
    );

    if (result == true) {
      await _loadAllBooks();
    }
  }

  Future<void> _editBook(Map<String, dynamic> book) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddBookScreen(bookToEdit: book)),
    );

    if (result == true) {
      await _loadAllBooks();
    }
  }

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

      // Get the actual book objects that are selected from the filtered list
      final booksToDelete = _selectedBooks.map((index) => _filteredBooks[index]).toSet();
      final titlesToDelete = booksToDelete.map((book) => book['title'] as String?).where((title) => title != null).toSet();

      // Remove from favorites
      if (titlesToDelete.isNotEmpty) {
        final favoriteBookTitles = prefs.getStringList('favorite_books') ?? [];
        favoriteBookTitles.removeWhere((favTitle) => titlesToDelete.contains(favTitle));
        await prefs.setStringList('favorite_books', favoriteBookTitles);
      }

      // Remove from the master list in SharedPreferences
      final allBooksJson = prefs.getStringList('read_books') ?? [];
      allBooksJson.removeWhere((bookJson) {
        try {
          final book = json.decode(bookJson);
          return titlesToDelete.contains(book['title']);
        } catch (e) {
          return false;
        }
      });
      await prefs.setStringList('read_books', allBooksJson);

      // Reload all data and exit selection mode
      await _loadAllBooks();
      setState(() {
        _isSelectionMode = false;
        _selectedBooks.clear();
      });
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
            onPressed: _selectedBooks.isNotEmpty ? _deleteSelectedBooks : null,
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
              if (!_isSelectionMode)
              TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm sách...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
              const SizedBox(height: 16),
              if (_favoriteBooks.isNotEmpty) ...[
                _buildSectionTitle('Sách yêu thích'),
                const SizedBox(height: 10),
                _buildBooksList(_favoriteBooks, isFavoriteList: true),
              const SizedBox(height: 24),
              ],
              _buildSectionTitle('Tất cả sách'),
              const SizedBox(height: 10),
              _buildBooksList(_filteredBooks, isFavoriteList: false),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
          border: Border.all(color: Colors.grey[300]!),
        ),
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
      height: isFavoriteList ? 200 : null,
      child: isFavoriteList
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                return _buildBookCard(books[index], index, isFavoriteList);
              },
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6, // Giảm từ 0.65 xuống 0.6 để có thêm không gian
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                return _buildBookCard(books[index], index, isFavoriteList);
              },
            ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, int index, bool isFavoriteList) {
    final imagePath = book['imagePath'] as String?;
    final title = book['title'] ?? 'Không có tên';
    final author = book['author'] ?? 'Không có tác giả';
    final isSelected = _isSelectionMode && _selectedBooks.contains(index);

    return GestureDetector(
      onTap: () => _onBookTap(index, isFavoriteList),
      onLongPress: () {
        if (!isFavoriteList) {
          _editBook(book);
        }
      },
      child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
          mainAxisSize: MainAxisSize.min, // Giảm kích thước tối thiểu
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: imagePath != null && imagePath.isNotEmpty
                            ? Image.file(
                          File(imagePath),
                          width: isFavoriteList ? 130 : double.infinity,
                          height: isFavoriteList ? 170 : 180, // Giảm từ 200 xuống 180
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: isFavoriteList ? 130 : double.infinity,
                          height: isFavoriteList ? 170 : 180, // Giảm từ 200 xuống 180
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
            const SizedBox(height: 6), // Giảm từ 8 xuống 6
            Flexible(
              child: Text(
                    title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
            if (author.isNotEmpty)
              Flexible(
                child: Text(
                  author,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
