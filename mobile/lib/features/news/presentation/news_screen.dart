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
      setState(() {
        _articles = result.articles;
        _page = page;
        _lastQuery = query;
        _totalResults = result.totalResults;
        _hasMore = result.hasMore;
        _loading = false;
      });
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
                    horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: PortalColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: PortalColors.gold, width: 1.4),
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
              const Icon(Icons.error_outline,
                  color: PortalColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                    color: PortalColors.danger, fontSize: 15),
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
            const Icon(Icons.newspaper_outlined,
                color: PortalColors.muted, size: 64),
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
                        color: PortalColors.muted, fontSize: 12),
                  ),
                ),
                Text(
                  'Página $_page',
                  style: const TextStyle(
                      color: PortalColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _articles.length,
            itemBuilder: (context, index) =>
                NewsCard(article: _articles[index]),
          ),
        ),
      ],
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
