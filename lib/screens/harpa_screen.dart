import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

/// Harpa Cristã: searchable list of the 640 hymns; tapping one opens a
/// swipeable viewer (Cookie for titles, Noto Serif for the lyrics).
class HarpaScreen extends StatefulWidget {
  const HarpaScreen({super.key});

  @override
  State<HarpaScreen> createState() => _HarpaScreenState();
}

class Hymn {
  final int number;
  final String name;
  final String? chorus;
  final List<String> verses;

  const Hymn({
    required this.number,
    required this.name,
    required this.chorus,
    required this.verses,
  });
}

/// Loads and caches the hymns from the bundled JSON.
class _HarpaRepository {
  static List<Hymn>? _cache;

  static Future<List<Hymn>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/harpa_crista.json');
    final map = json.decode(raw) as Map<String, dynamic>;
    final hymns = <Hymn>[];
    map.forEach((key, value) {
      final number = int.tryParse(key);
      // The "-1" entry is metadata about the JSON's author, not a hymn.
      if (number == null || number < 1) return;
      final entry = value as Map<String, dynamic>;
      final title = (entry['hino'] as String? ?? '').trim();
      final chorus = _cleanText(entry['coro'] as String?);
      final versesMap = entry['verses'] as Map<String, dynamic>? ?? {};
      final verseKeys = versesMap.keys.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      hymns.add(Hymn(
        number: number,
        name: title.replaceFirst(RegExp(r'^\d+\s*-\s*'), ''),
        chorus: chorus,
        verses: [
          for (final k in verseKeys)
            if (_cleanText(versesMap[k] as String?) case final v?) v,
        ],
      ));
    });
    hymns.sort((a, b) => a.number.compareTo(b.number));
    _cache = hymns;
    return hymns;
  }

  /// Turns "<br>"-separated markup into plain lines.
  static String? _cleanText(String? text) {
    if (text == null) return null;
    final cleaned = text
        .split(RegExp(r'\s*<br\s*/?>\s*'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    return cleaned.isEmpty ? null : cleaned;
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

class _HarpaScreenState extends State<HarpaScreen> {
  List<Hymn>? _hymns;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _HarpaRepository.load().then((hymns) {
      if (mounted) setState(() => _hymns = hymns);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Hymn> get _filtered {
    final hymns = _hymns ?? const <Hymn>[];
    final query = _query.trim();
    if (query.isEmpty) return hymns;
    final asNumber = int.tryParse(query);
    if (asNumber != null) {
      return hymns
          .where((h) => h.number.toString().startsWith(query))
          .toList();
    }
    final normalized = _stripDiacritics(query);
    return hymns
        .where((h) => _stripDiacritics(h.name).contains(normalized))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(title: const Text('Harpa Cristã')),
      body: SafeArea(
        child: _hymns == null
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
          hintText: 'Número ou nome do hino',
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
    final hymns = _filtered;
    if (hymns.isEmpty) {
      return Center(
        child: Text(
          'Nenhum hino encontrado',
          style: AppTheme.bodyText.copyWith(color: AppTheme.mediumBrown),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: hymns.length,
      itemBuilder: (context, index) => _buildHymnTile(hymns[index]),
    );
  }

  Widget _buildHymnTile(Hymn hymn) {
    final firstLine = hymn.verses.isNotEmpty
        ? hymn.verses.first.split('\n').first
        : '';
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
          onTap: () {
            final all = _hymns!;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HymnViewerScreen(
                  hymns: all,
                  initialIndex: all.indexOf(hymn),
                ),
              ),
            );
          },
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
                      '${hymn.number}',
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
                        hymn.name,
                        style: const TextStyle(
                          fontFamily: 'NotoSerif',
                          fontWeight: FontWeight.w500,
                          fontSize: 17,
                          color: AppTheme.darkBrown,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (firstLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          firstLine,
                          style: AppTheme.caption.copyWith(
                            fontFamily: 'NotoSerif',
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

/// Full-screen hymn reader. Swipe horizontally (or use the bottom arrows)
/// to move between hymns; A-/A+ adjust and persist the lyrics font size.
class HymnViewerScreen extends StatefulWidget {
  final List<Hymn> hymns;
  final int initialIndex;

  const HymnViewerScreen({
    super.key,
    required this.hymns,
    required this.initialIndex,
  });

  @override
  State<HymnViewerScreen> createState() => _HymnViewerScreenState();
}

class _HymnViewerScreenState extends State<HymnViewerScreen> {
  static const _fontSizeKey = 'harpa_font_size';
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
    final hymn = widget.hymns[_index];
    return Scaffold(
      backgroundColor: AppTheme.creamBackground,
      appBar: AppBar(
        title: Text('Hino ${hymn.number}'),
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
                itemCount: widget.hymns.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) =>
                    _buildHymnPage(widget.hymns[index]),
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHymnPage(Hymn hymn) {
    final lyricsStyle = TextStyle(
      fontFamily: 'NotoSerif',
      fontSize: _fontSize,
      color: AppTheme.lightBrown,
      height: 1.7,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hymn.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplaySC',
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
          for (var i = 0; i < hymn.verses.length; i++) ...[
            _buildVerse(i + 1, hymn.verses[i], lyricsStyle),
            // Traditional hymnal layout: the chorus is printed once,
            // right after the first verse.
            if (i == 0 && hymn.chorus != null)
              _buildChorus(hymn.chorus!, lyricsStyle),
          ],
        ],
      ),
    );
  }

  Widget _buildVerse(int number, String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number',
            style: TextStyle(
              fontFamily: 'NotoSerif',
              fontSize: _fontSize - 2,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(height: 2),
          Text(text, style: style),
        ],
      ),
    );
  }

  Widget _buildChorus(String text, TextStyle style) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightPeach,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coro',
            style: TextStyle(
              fontFamily: 'Cookie',
              fontSize: 24,
              color: AppTheme.mediumBrown,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: style.copyWith(fontStyle: FontStyle.italic)),
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
            '${_index + 1} de ${widget.hymns.length}',
            style: AppTheme.caption,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                color: AppTheme.primaryOrange),
            onPressed: _index < widget.hymns.length - 1
                ? () => _goTo(_index + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
