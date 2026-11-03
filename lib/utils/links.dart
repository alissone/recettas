import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Links inside a todo's text: tapping one opens it in the default
/// browser, long-pressing the card copies it.
class Links {
  Links._();

  /// `[label](target)` markdown links.
  static final _markdownLink = RegExp(r'\[[^\]]*\]\(\s*<?([^)\s>]+)>?[^)]*\)');

  /// Bare URLs, as GitHub-flavored markdown autolinks them.
  static final _bareUrl =
      RegExp(r'''(?:https?://|www\.)[^\s<>()\[\]"']+''', caseSensitive: false);

  /// Punctuation that ends a sentence rather than the URL.
  static final _trailing = RegExp(r'[.,;:!?*_~]+$');

  /// The URLs in [text], in order, without duplicates. Markdown link
  /// targets count; so do bare `https://…` / `www.…` addresses.
  static List<String> extract(String text) {
    final found = <String>[];
    void add(String url) {
      url = url.replaceFirst(_trailing, '');
      if (url.isNotEmpty && !found.contains(url)) found.add(url);
    }

    final rest = text.replaceAllMapped(_markdownLink, (m) {
      add(m.group(1)!);
      return ' ';
    });
    for (final m in _bareUrl.allMatches(rest)) {
      add(m.group(0)!);
    }
    return found.where((u) => toUri(u) != null).toList();
  }

  /// [url] as something the browser can open: `www.x` gets `https://`;
  /// only web and mail links are accepted.
  static Uri? toUri(String url) {
    var value = url.trim();
    if (value.toLowerCase().startsWith('www.')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final ok = ((uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty) ||
        uri.scheme == 'mailto';
    return ok ? uri : null;
  }

  /// Opens [url] in the default browser (outside the app).
  static Future<void> open(BuildContext context, String? url) async {
    final uri = url == null ? null : toUri(url);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Não foi possível abrir ${url ?? 'o link'}')));
    }
  }

  /// Copies the link in [text]; with several, asks which one first.
  /// Returns false when there's no link (the caller may do something
  /// else with the long-press).
  static Future<bool> copyFrom(BuildContext context, String text) async {
    final links = extract(text);
    if (links.isEmpty) return false;
    final link = links.length == 1
        ? links.first
        : await showModalBottomSheet<String>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                    title: Text('Copiar qual link?',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final l in links)
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(l,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(context, l),
                    ),
                ],
              ),
            ),
          );
    if (link == null) return true;
    await Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Link copiado')));
    }
    return true;
  }
}
