import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;
import '../app_theme.dart';

/// Bíblia (NVI): searchable list of the 66 books, then a chapter grid,
/// then a swipeable verse reader (Niconne for titles, Noto Serif for text).
class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class BibleVerse {
  final int number;
  final String text;

  const BibleVerse({required this.number, required this.text});
}

class BibleChapter {
  final int bookNumber;
  final String bookName;
  final String bookShortName;
  final int number;
  final List<BibleVerse> verses;

  const BibleChapter({
    required this.bookNumber,
    required this.bookName,
    required this.bookShortName,
    required this.number,
    required this.verses,
  });
}

class BibleBook {
  final int number;
  final String name;
  final String shortName;
  final List<BibleChapter> chapters;

  const BibleBook({
    required this.number,
    required this.name,
    required this.shortName,
    required this.chapters,
  });
}

/// Loads and caches the Bible from the bundled Zefania XML (NVI).
class _BibleRepository {
  static List<BibleBook>? _cache;
  static List<BibleChapter>? _flatCache;

  static Future<List<BibleBook>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/NVI.xml');
    final document = xml.XmlDocument.parse(raw);
    final books = <BibleBook>[];
    for (final bookEl in document.findAllElements('BIBLEBOOK')) {
      final bnumber = int.parse(bookEl.getAttribute('bnumber')!);
      final bname = bookEl.getAttribute('bname') ?? '';
      final bsname = bookEl.getAttribute('bsname') ?? '';
      final chapters = <BibleChapter>[];
      for (final chapterEl in bookEl.findElements('CHAPTER')) {
        final cnumber = int.parse(chapterEl.getAttribute('cnumber')!);
        final verses = <BibleVerse>[
          for (final versEl in chapterEl.findElements('VERS'))
            BibleVerse(
              number: int.parse(versEl.getAttribute('vnumber')!),
              text: versEl.innerText.trim(),
            ),
        ];
        chapters.add(BibleChapter(
          bookNumber: bnumber,
          bookName: bname,
          bookShortName: bsname,
          number: cnumber,
          verses: verses,
        ));
      }
      books.add(BibleBook(
        number: bnumber,
        name: bname,
        shortName: bsname,
        chapters: chapters,
      ));
    }
    _cache = books;
    return books;
  }

  /// All chapters of the whole Bible in canonical order, for continuous
  /// swiping from one book straight into the next.
  static List<BibleChapter> flatten(List<BibleBook> books) {
    return _flatCache ??= [
      for (final book in books) ...book.chapters,
    ];
  }
}

String _stripDiacritics(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final i = from.indexOf(char);
    buffer.write(i >= 0 ? to[i] : char);
  }
  return buffer.toString();
}

class _BibleScreenState extends State<BibleScreen> {
  List<BibleBook>? _books;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _BibleRepository.load().then((books) {
      if (mounted) setState(() => _books = books);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BibleBook> get _filtered {
    final books = _books ?? const <BibleBook>[];
    final query = _query.trim();
    if (query.isEmpty) return books;
    final asNumber = int.tryParse(query);
    if (asNumber != null) {
      return books
          .where((b) => b.number.toString().startsWith(query))
          .toList();
    }
    final normalized = _stripDiacritics(query);
    return books
        .where((b) =>
            _stripDiacritics(b.name).contains(normalized) ||
            _stripDiacritics(b.shortName).contains(normalized))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Bíblia')),
      body: SafeArea(
        child: _books == null
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primaryOrange),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: _buildSearchField(),
                  ),
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        style: AppTheme.bodyText,
        decoration: InputDecoration(
          hintText: 'Número ou nome do livro',
          hintStyle:
              AppTheme.bodyText.copyWith(color: AppTheme.borderBrown),
          prefixIcon:
              const Icon(Icons.search, color: AppTheme.mediumBrown),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear,
                      color: AppTheme.mediumBrown, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildList() {
    final books = _filtered;
    if (books.isEmpty) {
      return Center(
        child: Text(
          'Nenhum livro encontrado',
          style: AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: books.length,
      itemBuilder: (context, index) => _buildBookTile(books[index]),
    );
  }

  Widget _buildBookTile(BibleBook book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookChaptersScreen(books: _books!, book: book),
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Center(
                    child: Text(
                      '${book.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        style: const TextStyle(
                          fontFamily: 'Niconne',
                          fontSize: 22,
                          color: AppTheme.darkBrown,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${book.chapters.length} capítulos',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppTheme.mediumBrown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of chapter numbers for a single book.
class BookChaptersScreen extends StatelessWidget {
  final List<BibleBook> books;
  final BibleBook book;

  const BookChaptersScreen({
    super.key,
    required this.books,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final flat = _BibleRepository.flatten(books);
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: Text(book.name)),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: book.chapters.length,
          itemBuilder: (context, index) {
            final chapter = book.chapters[index];
            return Material(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BibleReaderScreen(
                      chapters: flat,
                      initialIndex: flat.indexOf(chapter),
                    ),
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Center(
                    child: Text(
                      '${chapter.number}',
                      style: AppTheme.valueBold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen chapter reader. Swipe horizontally (or use the bottom
/// arrows) to move between chapters, continuing seamlessly into the next
/// book; A-/A+ adjust and persist the verse font size.
class BibleReaderScreen extends StatefulWidget {
  final List<BibleChapter> chapters;
  final int initialIndex;

  const BibleReaderScreen({
    super.key,
    required this.chapters,
    required this.initialIndex,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  static const _fontSizeKey = 'biblia_font_size';
  static const _minFontSize = 14.0;
  static const _maxFontSize = 26.0;

  late final PageController _pageController;
  late int _index;
  double _fontSize = 17;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getDouble(_fontSizeKey);
      if (saved != null && mounted) setState(() => _fontSize = saved);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeFontSize(double delta) {
    setState(() {
      _fontSize = (_fontSize + delta).clamp(_minFontSize, _maxFontSize);
    });
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setDouble(_fontSizeKey, _fontSize));
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[_index];
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text('${chapter.bookShortName} ${chapter.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            tooltip: 'Diminuir letra',
            onPressed:
                _fontSize > _minFontSize ? () => _changeFontSize(-1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            tooltip: 'Aumentar letra',
            onPressed:
                _fontSize < _maxFontSize ? () => _changeFontSize(1) : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.chapters.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) =>
                    _buildChapterPage(widget.chapters[index]),
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterPage(BibleChapter chapter) {
    final textStyle = TextStyle(
      fontFamily: 'NotoSerif',
      fontSize: _fontSize,
      color: AppTheme.lightBrown,
      height: 1.7,
    );
    final numberStyle = TextStyle(
      fontFamily: 'NotoSerif',
      fontSize: _fontSize - 3,
      fontWeight: FontWeight.bold,
      color: AppTheme.primaryOrange,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${chapter.bookName} ${chapter.number}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Niconne',
              fontSize: 36,
              color: AppTheme.darkBrown,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                for (final verse in chapter.verses) ...[
                  TextSpan(text: '${verse.number} ', style: numberStyle),
                  TextSpan(text: '${verse.text}  ', style: textStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(color: AppTheme.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppTheme.primaryOrange),
            onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
          ),
          Text(
            '${_index + 1} de ${widget.chapters.length}',
            style: AppTheme.caption,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                color: AppTheme.primaryOrange),
            onPressed: _index < widget.chapters.length - 1
                ? () => _goTo(_index + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
