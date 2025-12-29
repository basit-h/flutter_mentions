part of flutter_mentions;

/// A custom implementation of [TextEditingController] to support @ mention or other
/// trigger based mentions.
class AnnotationEditingController extends TextEditingController {
  Map<String, Annotation> _mapping;
  String? _pattern;

  AnnotationEditingController(this._mapping) {
    _updatePattern();
  }

  void _updatePattern() {
    // Sort keys by length in descending order to match longer strings first
    final sortedKeys = _mapping.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

    _pattern = sortedKeys.isNotEmpty ? "(${sortedKeys.map((key) => RegExp.escape(key)).join('|')})" : null;
  }

  String get markupText {
    if (_mapping.isEmpty) return text;

    final buffer = StringBuffer();
    var currentPos = 0;

    for (final match in RegExp(_pattern!).allMatches(text)) {
      // Add text before the match
      if (match.start > currentPos) {
        buffer.write(text.substring(currentPos, match.start));
      }

      final matchedText = match.group(0)!;
      final mention = _findMention(matchedText);

      if (!mention.disableMarkup) {
        final cleanedDisplay = mention.display?.replaceAll(
          RegExp(r'[!@#$%^&*()_+\[\]{}\\|;:"\`,.<>?/~]'),
          '',
        );
        buffer.write(
          mention.markupBuilder != null
              ? mention.markupBuilder!(mention.trigger, mention.id!, mention.display!)
              : '[__${mention.trigger}${cleanedDisplay?.trim()}__](${mention.id})',
        );
      } else {
        buffer.write(matchedText);
      }

      currentPos = match.end;
    }

    // Add remaining text
    if (currentPos < text.length) {
      buffer.write(text.substring(currentPos));
    }

    return buffer.toString();
  }

  Annotation _findMention(String matchedText) {
    // Find exact match first
    if (_mapping.containsKey(matchedText)) {
      return _mapping[matchedText]!;
    }

    // Fallback to pattern matching (shouldn't normally happen due to our regex)
    final key = _mapping.keys.firstWhere(
      (element) => RegExp(element).hasMatch(matchedText),
      orElse: () => _mapping.keys.first,
    );
    return _mapping[key]!;
  }

  Map<String, Annotation> get mapping => _mapping;

  set mapping(Map<String, Annotation> mapping) {
    _mapping = mapping;
    _updatePattern();
  }

  @override
  TextSpan buildTextSpan({BuildContext? context, TextStyle? style, bool? withComposing}) {
    final children = <InlineSpan>[];

    if (_pattern == null || _pattern == '()') {
      children.add(TextSpan(text: text, style: style));
      return TextSpan(style: style, children: children);
    }

    var currentPos = 0;

    for (final match in RegExp(_pattern!).allMatches(text)) {
      // Add text before the match
      if (match.start > currentPos) {
        children.add(TextSpan(text: text.substring(currentPos, match.start), style: style));
      }

      final matchedText = match.group(0)!;
      final mention = _findMention(matchedText);

      children.add(TextSpan(text: matchedText, style: style?.merge(mention.style)));

      currentPos = match.end;
    }

    // Add remaining text
    if (currentPos < text.length) {
      children.add(TextSpan(text: text.substring(currentPos), style: style));
    }

    return TextSpan(style: style, children: children);
  }
}
