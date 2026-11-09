import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_api_client.dart';

/// Representa um artigo de notícia retornado pelo News Service.
///
/// O backend devolve o formato da NewsAPI.org com alguns campos extras.
class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    this.source,
    this.author,
    this.publishedAt,
    this.urlToImage,
  });

  final String title;
  final String description;
  final String url;
  final String? source;
  final String? author;
  final String? publishedAt;
  final String? urlToImage;

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        title: (json['title'] as String?)?.trim() ?? 'Sem título',
        description: (json['description'] as String?)?.trim() ?? '',
        url: json['url'] as String? ?? '',
        source: (json['source'] as Map?)?['name'] as String?,
        author: json['author'] as String?,
        publishedAt: json['publishedAt'] as String?,
        urlToImage: json['urlToImage'] as String?,
      );
}

/// Resultado de uma busca de notícias.
class NewsResult {
  const NewsResult.success({
    required this.articles,
    required this.totalResults,
    required this.page,
  })  : ok = true,
        message = null;

  const NewsResult.failure(this.message)
      : ok = false,
        articles = const [],
        totalResults = 0,
        page = 1;

  final bool ok;
  final List<NewsArticle> articles;
  final int totalResults;
  final int page;
  final String? message;

  bool get hasMore => articles.length >= 20;
}

/// Cliente HTTP para o News Service, roteado pelo gateway (porta 3000).
///
/// Rota utilizada: POST /api/news/search
/// Requer autenticação (cookie portal_session).
///
/// Por que POST e não GET?
/// O News Service usa POST para a busca porque aceita um body JSON com
/// filtros adicionais (query, page, etc.). O gateway roteia o path
/// /api/news/* para o News Service na porta 3002.
class NewsApiClient {
  /// Recebe o [CookieJarClient] já autenticado do [AuthApiClient]
  /// para reutilizar o cookie de sessão — não abrimos uma nova conexão.
  NewsApiClient({required CookieJarClient cookieJar}) : _jar = cookieJar;

  final CookieJarClient _jar;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Busca notícias com paginação.
  ///
  /// [query] é o termo de busca.
  /// [page] começa em 1. O backend retorna 20 artigos por página.
  Future<NewsResult> search(String query, {int page = 1}) async {
    try {
      final response = await _jar.post(
        _uri('/api/news/search'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'query': query.trim(), 'page': page}),
      );

      if (response.statusCode == 401) {
        return const NewsResult.failure(
            'Sessão expirada. Faça login novamente.');
      }

      if (response.statusCode != 200) {
        final body = _parseBody(response);
        final msg = body['message'];
        return NewsResult.failure(msg is String && msg.isNotEmpty
            ? msg
            : 'Erro ao buscar notícias (HTTP ${response.statusCode}).');
      }

      final body = _parseBody(response);
      final rawArticles = body['articles'];
      final total = body['totalResults'];

      final articles = rawArticles is List
          ? rawArticles
              .whereType<Map<String, dynamic>>()
              .map(NewsArticle.fromJson)
              .toList()
          : <NewsArticle>[];

      return NewsResult.success(
        articles: articles,
        totalResults: total is int ? total : articles.length,
        page: page,
      );
    } on Exception {
      return const NewsResult.failure(
          'Não foi possível conectar ao servidor. Verifique sua conexão.');
    }
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Exception {
      // body inválido
    }
    return {};
  }
}
