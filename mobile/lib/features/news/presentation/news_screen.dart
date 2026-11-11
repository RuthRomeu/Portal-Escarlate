import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/portal_theme.dart';
import '../../auth/data/auth_api_client.dart';
import '../data/news_api_client.dart';
import 'news_card.dart';

/// Tela principal do Portal Escarlate após o login.
///
/// Funcionalidades:
///   1. Campo de busca → POST /api/news/search
///   2. Lista paginada de artigos (20 por página)
///   3. Paginação "anterior / próxima"
///   4. Logout → POST /api/auth/logout → volta para o login
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, required this.apiClient});

  /// [AuthApiClient] já autenticado, passado pelo LoginScreen.
  /// Compartilhamos o mesmo CookieJarClient para reutilizar o cookie
  /// de sessão sem precisar fazer login duas vezes.
  final AuthApiClient apiClient;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final NewsApiClient _news;
  final _queryController = TextEditingController();

  List<NewsArticle> _articles = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = false;
  String? _error;
  String _lastQuery = '';
  int _totalResults = 0;

  // Estado da síntese de página com IA
  String _aiSummary = '';
  String? _aiSummaryMarked;
  bool _aiSummaryLoading = false;
  String? _aiSummaryError;
  int _summaryRequestId = 0;

  // Keys dos cards para scroll ao tocar em um trecho da síntese
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    // Cria o NewsApiClient reutilizando o CookieJarClient do AuthApiClient.
    // Internamente o AuthApiClient expõe o jar para que o NewsApiClient
    // possa enviar o cookie portal_session já salvo.
    _news = NewsApiClient(cookieJar: widget.apiClient.jar);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Busca
  // ---------------------------------------------------------------------------

  Future<void> _search({int page = 1}) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      if (page == 1) _articles = [];
    });

    final result = await _news.search(query, page: page);

    if (!mounted) return;

    if (result.ok) {
      final withIds = attachShortIds(result.articles);
      setState(() {
        _articles = withIds;
        _page = page;
        _lastQuery = query;
        _totalResults = result.totalResults;
        _hasMore = result.hasMore;
        _loading = false;
        _aiSummary = '';
        _aiSummaryMarked = null;
        _aiSummaryError = null;
      });
      _summarizePage();
    } else {
      setState(() {
        _error = result.message;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await widget.apiClient.logout();
    if (!mounted) return;
    // Volta para o login removendo toda a pilha de navegação.
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // ---------------------------------------------------------------------------
  // Síntese de página com IA
  // ---------------------------------------------------------------------------

  Future<void> _summarizePage() async {
    if (_articles.isEmpty || _lastQuery.isEmpty) return;

    final requestId = ++_summaryRequestId;

    setState(() {
      _aiSummaryLoading = true;
      _aiSummary = '';
      _aiSummaryMarked = null;
      _aiSummaryError = null;
    });

    // Chama POST /api/news-summary com a query e os artigos da página atual.
    final result = await _news.summarizePage(_lastQuery, _articles);

    // Ignora respostas de buscas antigas (race condition entre páginas).
    if (!mounted || requestId != _summaryRequestId) return;

    setState(() {
      _aiSummaryLoading = false;
      if (result.ok) {
        _aiSummary = result.summary;
        _aiSummaryMarked = result.markedSummary;
      } else {
        _aiSummaryError = result.message;
      }
    });
  }

  void _scrollToArticle(String shortId) {
    final key = _cardKeys[shortId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  GlobalKey _cardKeyFor(String? shortId) {
    final id = shortId ?? '';
    return _cardKeys.putIfAbsent(id, () => GlobalKey());
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalColors.background,
      appBar: AppBar(
        backgroundColor: PortalColors.darkWine,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 32, height: 32),
            const SizedBox(width: 10),
            const Text(
              'Portal Escarlate',
              style: TextStyle(
                color: PortalColors.goldLight,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: PortalColors.muted, size: 18),
            label: const Text(
              'Sair',
              style: TextStyle(color: PortalColors.muted),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
          if (_articles.isNotEmpty) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: PortalColors.darkWine,
        border: Border(bottom: BorderSide(color: PortalColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _search(),
              style: const TextStyle(color: PortalColors.text),
              decoration: InputDecoration(
                hintText: 'Buscar notícias…',
                hintStyle: const TextStyle(color: PortalColors.muted),
                filled: true,
                fillColor: PortalColors.field,
                prefixIcon: const Icon(
                  Icons.search,
                  color: PortalColors.muted,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: PortalColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: PortalColors.gold,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : () => _search(),
              style: ElevatedButton.styleFrom(
                backgroundColor: PortalColors.gold,
                foregroundColor: PortalColors.onGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PortalColors.onGold,
                      ),
                    )
                  : const Text('Buscar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Estado: carregando
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: PortalColors.gold),
      );
    }

    // Estado: erro
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: PortalColors.danger,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: PortalColors.danger,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _search(page: _page),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PortalColors.wine,
                  foregroundColor: PortalColors.gold,
                ),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    // Estado: sem busca ainda
    if (_articles.isEmpty && _lastQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.newspaper_outlined,
              color: PortalColors.muted,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Busque por um tema para ver notícias relevantes.',
              style: TextStyle(color: PortalColors.muted, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            if (_totalResults == 0 && _lastQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Nenhum resultado encontrado.',
                style: TextStyle(color: PortalColors.muted),
              ),
            ],
          ],
        ),
      );
    }

    // Estado: resultados
    return Column(
      children: [
        if (_lastQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '"$_lastQuery" — $_totalResults resultado${_totalResults != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: PortalColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'Página $_page',
                  style: const TextStyle(
                    color: PortalColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              // Síntese de página com IA
              if (_aiSummaryLoading ||
                  _aiSummary.isNotEmpty ||
                  _aiSummaryError != null)
                _buildAiSummary(),
              // Cards de notícias com GlobalKey para scroll
              for (final article in _articles)
                NewsCard(key: _cardKeyFor(article.shortId), article: article),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Síntese de página com IA — widget
  // ---------------------------------------------------------------------------

  Widget _buildAiSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PortalColors.darkWine,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PortalColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: PortalColors.gold,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Síntese da página',
                style: TextStyle(
                  color: PortalColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_aiSummaryLoading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PortalColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gerando síntese central das notícias…',
                    style: const TextStyle(
                      color: PortalColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            )
          else if (_aiSummaryError != null)
            Text(
              _aiSummaryError!,
              style: const TextStyle(color: PortalColors.danger, fontSize: 13),
            )
          else if (_aiSummary.isNotEmpty)
            _buildSummaryText(),
        ],
      ),
    );
  }

  Widget _buildSummaryText() {
    final source = _aiSummaryMarked ?? _aiSummary;
    if (source.isEmpty) return const SizedBox.shrink();

    final paragraphs = source
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildParagraphRichText(paragraph),
        );
      }).toList(),
    );
  }

  Widget _buildParagraphRichText(String paragraph) {
    final marked = _aiSummaryMarked;
    if (marked == null || marked.isEmpty) {
      return Text(
        paragraph.trim(),
        style: const TextStyle(
          color: PortalColors.text,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    // Parser do formato [[texto]]((shortId))
    final pattern = RegExp(r'\[\[([\s\S]+?)\]\]\(\(([^)]+)\)\)');
    final spans = <TextSpan>[];
    int cursor = 0;

    for (final match in pattern.allMatches(paragraph)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: paragraph.substring(cursor, match.start)));
      }

      final text = match.group(1)?.trim() ?? '';
      final shortId = match.group(2)?.trim() ?? '';

      if (text.isNotEmpty && shortId.isNotEmpty) {
        spans.add(
          TextSpan(
            text: text,
            style: const TextStyle(
              color: PortalColors.goldLight,
              decoration: TextDecoration.underline,
              decorationColor: PortalColors.goldDark,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _scrollToArticle(shortId),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(cursor)));
    }

    if (spans.isEmpty) {
      return Text(
        paragraph.trim(),
        style: const TextStyle(
          color: PortalColors.text,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: PortalColors.text,
          fontSize: 14,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: PortalColors.darkWine,
        border: Border(top: BorderSide(color: PortalColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão anterior
          TextButton.icon(
            onPressed: _page > 1 ? () => _search(page: _page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
            style: TextButton.styleFrom(
              foregroundColor: _page > 1
                  ? PortalColors.gold
                  : PortalColors.muted,
            ),
          ),
          Text(
            'Página $_page',
            style: const TextStyle(color: PortalColors.muted, fontSize: 13),
          ),
          // Botão próxima
          TextButton.icon(
            onPressed: _hasMore ? () => _search(page: _page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Próxima'),
            style: TextButton.styleFrom(
              foregroundColor: _hasMore
                  ? PortalColors.gold
                  : PortalColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
