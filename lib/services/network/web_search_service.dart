import 'package:http/http.dart' as http;

/// 搜索结果
class SearchResult {
  const SearchResult({
    required this.title,
    required this.snippet,
    required this.url,
  });

  final String title;
  final String snippet;
  final String url;
}

/// 免费联网搜索服务（必应中国 / DuckDuckGo / 必应全球，无需 API Key）。
///
/// 国内网络优先走必应中国站（cn.bing.com），抓取结果页提取标题/摘要/链接。
class WebSearchService {
  WebSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// 联网搜索，返回前 [maxResults] 条结果；全部失败时返回空列表
  Future<List<SearchResult>> search(
    String query, {
    int maxResults = 5,
  }) async {
    // 国内优先：必应中国站
    try {
      final results = await _searchBing(query, maxResults, host: 'cn.bing.com');
      if (results.isNotEmpty) return results;
    } catch (_) {}
    // 海外：DuckDuckGo
    try {
      final results = await _searchDuckDuckGo(query, maxResults);
      if (results.isNotEmpty) return results;
    } catch (_) {}
    // 兜底：必应国际站
    try {
      return await _searchBing(query, maxResults, host: 'www.bing.com');
    } catch (_) {
      return [];
    }
  }

  Future<List<SearchResult>> _searchDuckDuckGo(
    String query,
    int maxResults,
  ) async {
    final uri = Uri.parse('https://html.duckduckgo.com/html/')
        .replace(queryParameters: {'q': query});
    final resp = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final html = resp.body;
    final linkRe = RegExp(
      r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final snippetRe = RegExp(
      r'class="result__snippet"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final titles = linkRe.allMatches(html).toList();
    final snippets = snippetRe.allMatches(html).toList();

    final results = <SearchResult>[];
    for (var i = 0; i < titles.length && results.length < maxResults; i++) {
      final m = titles[i];
      final title = _stripHtml(m.group(2) ?? '');
      if (title.isEmpty) continue;
      final url = _decodeDdgUrl(m.group(1) ?? '');
      final snippet =
          i < snippets.length ? _stripHtml(snippets[i].group(1) ?? '') : '';
      results.add(
        SearchResult(title: title, snippet: snippet, url: url),
      );
    }
    return results;
  }

  Future<List<SearchResult>> _searchBing(
    String query,
    int maxResults, {
    required String host,
  }) async {
    final uri = Uri.parse('https://$host/search')
        .replace(queryParameters: {'q': query});
    final resp = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return [];

    final html = resp.body;
    final results = <SearchResult>[];

    // 标准 b_algo 结构
    final algoRe = RegExp(
      r'<li class="b_algo".*?<h2[^>]*><a[^>]*href="([^"]+)"[^>]*>(.*?)</a></h2>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final m in algoRe.allMatches(html)) {
      if (results.length >= maxResults) break;
      final title = _stripHtml(m.group(2) ?? '');
      if (title.isEmpty) continue;
      final bodyHtml = m.group(3) ?? '';
      final pRe = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true);
      final pm = pRe.firstMatch(bodyHtml);
      results.add(
        SearchResult(
          title: title,
          snippet: _stripHtml(pm?.group(1) ?? ''),
          url: m.group(1) ?? '',
        ),
      );
    }
    if (results.isNotEmpty) return results;

    // 兜底：任意 h2 链接
    final h2Re = RegExp(
      r'<h2[^>]*><a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a></h2>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final m in h2Re.allMatches(html)) {
      if (results.length >= maxResults) break;
      final title = _stripHtml(m.group(2) ?? '');
      if (title.isEmpty) continue;
      results.add(
        SearchResult(title: title, snippet: '', url: m.group(1) ?? ''),
      );
    }
    return results;
  }

  String _decodeDdgUrl(String raw) {
    final href = raw.replaceAll('&amp;', '&');
    final uddg = Uri.tryParse(href)?.queryParameters['uddg'];
    if (uddg != null && uddg.isNotEmpty) return uddg;
    return href;
  }

  String _stripHtml(String input) {
    final text = input
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
